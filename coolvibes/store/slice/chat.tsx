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

export const fetchChats = createAsyncThunk<
  { chats: any[]; cursor: string | null },
  { limit?: number; cursor?: string },
  { rejectValue: string }
>(
  'chat/fetchChats',
  async ({ limit = 20, cursor }, thunkAPI) => {
    try {
      const response = await api.fetchChats({ limit, cursor });
      const chats: any[] = response.chats;
      let nextCursor: string | null = null;
      if (chats.length > 0) {
        nextCursor = chats[chats.length - 1].last_message_timestamp;
      }
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
        state.chats = [...state.chats, ...action.payload.chats];
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