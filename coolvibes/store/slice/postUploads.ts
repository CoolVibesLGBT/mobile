import { createSlice, PayloadAction } from '@reduxjs/toolkit';

type PostUploadNoticeKind = 'uploading' | 'success' | 'error';
export type BackgroundTaskStatus = 'uploading' | 'success' | 'error';
export type BackgroundTaskKind = 'post.create' | 'classified.create';

type PostUploadNotice = {
  kind: PostUploadNoticeKind;
  text: string;
  updatedAt: number;
};

export type BackgroundTask = {
  id: string;
  kind: BackgroundTaskKind;
  title: string;
  description?: string;
  status: BackgroundTaskStatus;
  message?: string;
  createdAt: number;
  updatedAt: number;
};

interface PostUploadsState {
  pendingIds: string[];
  tasks: BackgroundTask[];
  notice: PostUploadNotice | null;
  completedVersion: number;
}

const buildUploadingText = (count: number) => (
  count > 1 ? `${count} gonderim devam ediyor` : 'Gonderiniz isleniyor'
);

const buildSuccessText = (kind: BackgroundTaskKind) => (
  kind === 'classified.create' ? 'Ilaniniz gonderildi' : 'Postunuz gonderildi'
);

const buildFailureText = (kind: BackgroundTaskKind) => (
  kind === 'classified.create' ? 'Ilan gonderilemedi' : 'Post gonderilemedi'
);

function upsertTask(
  state: PostUploadsState,
  payload: { id: string; kind: BackgroundTaskKind; title?: string; description?: string },
  status: BackgroundTaskStatus,
  message?: string
) {
  const now = Date.now();
  const existingIndex = state.tasks.findIndex((task) => task.id === payload.id);
  const previousTask = existingIndex >= 0 ? state.tasks[existingIndex] : null;

  const nextTask: BackgroundTask = {
    id: payload.id,
    kind: payload.kind,
    title: payload.title || previousTask?.title || (payload.kind === 'classified.create' ? 'Ilan gonderiliyor' : 'Cool post gonderiliyor'),
    description: payload.description ?? previousTask?.description,
    status,
    message,
    createdAt: previousTask?.createdAt || now,
    updatedAt: now,
  };

  if (existingIndex >= 0) {
    state.tasks[existingIndex] = nextTask;
  } else {
    state.tasks.unshift(nextTask);
  }

  state.tasks = state.tasks.slice(0, MAX_TASKS);
}

const initialState: PostUploadsState = {
  pendingIds: [],
  tasks: [],
  notice: null,
  completedVersion: 0,
};

const MAX_TASKS = 20;

const postUploadsSlice = createSlice({
  name: 'postUploads',
  initialState,
  reducers: {
    enqueuePostUpload(state, action: PayloadAction<{ id: string; title?: string; description?: string }>) {
      if (!state.pendingIds.includes(action.payload.id)) {
        state.pendingIds.push(action.payload.id);
      }
      upsertTask(state, { ...action.payload, kind: 'post.create' }, 'uploading');
      state.notice = {
        kind: 'uploading',
        text: buildUploadingText(state.pendingIds.length),
        updatedAt: Date.now(),
      };
    },
    completePostUpload(state, action: PayloadAction<{ id: string }>) {
      state.pendingIds = state.pendingIds.filter((id) => id !== action.payload.id);
      const existingIndex = state.tasks.findIndex((task) => task.id === action.payload.id);
      const kind = existingIndex >= 0 ? state.tasks[existingIndex].kind : 'post.create';
      if (existingIndex >= 0) {
        state.tasks[existingIndex] = {
          ...state.tasks[existingIndex],
          status: 'success',
          message: buildSuccessText(kind),
          updatedAt: Date.now(),
        };
      }
      state.completedVersion += 1;
      state.notice = state.pendingIds.length > 0
        ? {
            kind: 'uploading',
            text: buildUploadingText(state.pendingIds.length),
            updatedAt: Date.now(),
          }
        : {
            kind: 'success',
            text: buildSuccessText(kind),
            updatedAt: Date.now(),
          };
    },
    failPostUpload(state, action: PayloadAction<{ id: string; message?: string }>) {
      state.pendingIds = state.pendingIds.filter((id) => id !== action.payload.id);
      const existingIndex = state.tasks.findIndex((task) => task.id === action.payload.id);
      const kind = existingIndex >= 0 ? state.tasks[existingIndex].kind : 'post.create';
      if (existingIndex >= 0) {
        state.tasks[existingIndex] = {
          ...state.tasks[existingIndex],
          status: 'error',
          message: action.payload.message || buildFailureText(kind),
          updatedAt: Date.now(),
        };
      } else {
        upsertTask(
          state,
          { id: action.payload.id, kind: 'post.create', title: 'Cool post gonderimi' },
          'error',
          action.payload.message || buildFailureText('post.create')
        );
      }
      state.notice = state.pendingIds.length > 0
        ? {
            kind: 'uploading',
            text: buildUploadingText(state.pendingIds.length),
            updatedAt: Date.now(),
          }
        : {
            kind: 'error',
            text: action.payload.message || buildFailureText(kind),
            updatedAt: Date.now(),
          };
    },
    enqueueBackgroundTask(
      state,
      action: PayloadAction<{ id: string; kind: BackgroundTaskKind; title?: string; description?: string }>
    ) {
      if (!state.pendingIds.includes(action.payload.id)) {
        state.pendingIds.push(action.payload.id);
      }
      upsertTask(state, action.payload, 'uploading');
      state.notice = {
        kind: 'uploading',
        text: buildUploadingText(state.pendingIds.length),
        updatedAt: Date.now(),
      };
    },
    completeBackgroundTask(
      state,
      action: PayloadAction<{ id: string; kind?: BackgroundTaskKind; message?: string }>
    ) {
      state.pendingIds = state.pendingIds.filter((id) => id !== action.payload.id);
      const existingIndex = state.tasks.findIndex((task) => task.id === action.payload.id);
      const kind = action.payload.kind || (existingIndex >= 0 ? state.tasks[existingIndex].kind : 'post.create');
      upsertTask(
        state,
        { id: action.payload.id, kind },
        'success',
        action.payload.message || buildSuccessText(kind)
      );
      state.completedVersion += 1;
      state.notice = state.pendingIds.length > 0
        ? {
            kind: 'uploading',
            text: buildUploadingText(state.pendingIds.length),
            updatedAt: Date.now(),
          }
        : {
            kind: 'success',
            text: action.payload.message || buildSuccessText(kind),
            updatedAt: Date.now(),
          };
    },
    failBackgroundTask(
      state,
      action: PayloadAction<{ id: string; kind: BackgroundTaskKind; title?: string; message?: string }>
    ) {
      state.pendingIds = state.pendingIds.filter((id) => id !== action.payload.id);
      upsertTask(
        state,
        { id: action.payload.id, kind: action.payload.kind, title: action.payload.title },
        'error',
        action.payload.message || buildFailureText(action.payload.kind)
      );
      state.notice = state.pendingIds.length > 0
        ? {
            kind: 'uploading',
            text: buildUploadingText(state.pendingIds.length),
            updatedAt: Date.now(),
          }
        : {
            kind: 'error',
            text: action.payload.message || buildFailureText(action.payload.kind),
            updatedAt: Date.now(),
          };
    },
    clearPostUploadNotice(state) {
      state.notice = state.pendingIds.length > 0
        ? {
            kind: 'uploading',
            text: buildUploadingText(state.pendingIds.length),
            updatedAt: Date.now(),
          }
        : null;
    },
    clearFinishedPostTasks(state) {
      state.tasks = state.tasks.filter((task) => task.status === 'uploading');
    },
  },
});

export const {
  enqueuePostUpload,
  completePostUpload,
  failPostUpload,
  enqueueBackgroundTask,
  completeBackgroundTask,
  failBackgroundTask,
  clearPostUploadNotice,
  clearFinishedPostTasks,
} = postUploadsSlice.actions;

export default postUploadsSlice.reducer;
