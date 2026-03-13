import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import { api } from '@/services/apiService';


interface ChatState {
  chats: any[];
  loading: boolean;
  error: string | null;
  cursor: string | null;
}

const initialState: ChatState = {
  chats: [],
  loading: false,
  error: null,
  cursor: null,
};

const getChatId = (chat: any) =>
  String(chat?.id ?? chat?.chat_id ?? chat?.public_id ?? chat?.uuid ?? '');

const mergeUniqueChats = (existing: any[], incoming: any[]) => {
  if (!incoming.length) return existing;
  const map = new Map<string, any>();
  existing.forEach((chat) => {
    const id = getChatId(chat);
    map.set(id || `__idx_${map.size}`, chat);
  });
  incoming.forEach((chat) => {
    const id = getChatId(chat);
    if (!id) return;
    map.set(id, chat);
  });
  return Array.from(map.values());
};

export const fetchChats = createAsyncThunk<
  { chats: any[]; cursor: string | null },
  { limit?: number; cursor?: string },
  { rejectValue: string }
>(
  'chat/fetchChats',
  async ({ limit = 20, cursor }, thunkAPI) => {
    try {
      const response = await api.fetchChats({ limit, cursor });
      const payload = response?.data ?? response;
      const chats: any[] =
        (Array.isArray(payload?.chats) && payload.chats) ||
        (Array.isArray(payload?.data?.chats) && payload.data.chats) ||
        (Array.isArray(response?.chats) && response.chats) ||
        (Array.isArray(response?.data?.chats) && response.data.chats) ||
        [];
      let nextCursor: string | null =
        payload?.cursor ??
        payload?.data?.cursor ??
        response?.cursor ??
        response?.data?.cursor ??
        (chats.length > 0 ? chats[chats.length - 1].last_message_timestamp : null);
      return { chats, cursor: nextCursor };
    } catch (error: any) {
      return thunkAPI.rejectWithValue(error.message || 'Fetch chats failed');
    }
  }
);

const chatSlice = createSlice({
  name: 'chat',
  initialState,
  reducers: {
    resetChats(state) {
      state.chats = [];
      state.cursor = null;
      state.error = null;
      state.loading = false;
    },
  },
  extraReducers: (builder) => {
    builder
      .addCase(fetchChats.pending, (state) => {
        state.loading = true;
        state.error = null;
      })
      .addCase(fetchChats.fulfilled, (state, action: PayloadAction<{ chats: any[]; cursor: string | null }>) => {
        state.loading = false;
        const incoming = Array.isArray(action.payload.chats) ? action.payload.chats : [];
        if (incoming.length > 0) {
          state.chats = mergeUniqueChats(state.chats, incoming);
        }
        state.cursor = action.payload.cursor;
      })
      .addCase(fetchChats.rejected, (state, action) => {
        state.loading = false;
        state.error = action.payload ?? 'Error fetching chats';
      });
  },
});

export const { resetChats } = chatSlice.actions;
export default chatSlice.reducer;
