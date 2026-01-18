import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import { api } from '@/services/apiService';

interface Cursor {
  prev: string | null;
  next: string | null;
}

interface NearByUsersState {
  users: any[];
  loading: boolean;
  error: string | null;
  cursor: Cursor | null;
}

const initialState: NearByUsersState = {
  users: [],
  loading: false,
  error: null,
  cursor: null,
};

export const fetchNearbyUsers = createAsyncThunk<
  { users: any[]; cursor: Cursor | null },
  { latitude: number | null; longitude: number | null; cursor?: string | null; limit?: number | null },
  { rejectValue: string }
>(
  'nearbyUsers/fetchNearbyUsers',
  async ({ latitude, longitude, cursor = null, limit = null }, thunkAPI) => {
    try {
      const state: any = thunkAPI.getState();
      const currentCursor = cursor ?? state.nearbyUsers.cursor;
      const nextCursor = currentCursor ? currentCursor.next : null;

      const response = await api.fetchNearbyUsers(
        latitude,
        longitude,
        nextCursor,
        limit
      );

      if (!response.success) {
        return thunkAPI.rejectWithValue(response.error || 'Failed to fetch users');
      }

      return {
        users: response.users,
        cursor: response.cursor,
      };
    } catch (error: any) {
      return thunkAPI.rejectWithValue(error.message);
    }
  }
);

const nearbyUsersSlice = createSlice({
  name: 'nearbyUsers',
  initialState,
  reducers: {
    resetUsers(state) {
      state.users = [];
      state.cursor = null;
      state.error = null;
      state.loading = false;
    },
  },
  extraReducers: (builder) => {
    builder
      .addCase(fetchNearbyUsers.pending, (state) => {
        state.loading = true;
        state.error = null;
      })
      .addCase(fetchNearbyUsers.fulfilled, (state, action: PayloadAction<{ users: any[]; cursor: Cursor | null }>) => {
        state.loading = false;
        // Filter out duplicates before adding
        const existingIds = new Set(state.users.map(u => u.id));
        const newUsers = action.payload.users.filter(u => !existingIds.has(u.id));
        state.users = [...state.users, ...newUsers];
        state.cursor = action.payload.cursor;
      })
      .addCase(fetchNearbyUsers.rejected, (state, action) => {
        state.loading = false;
        state.error = action.payload ?? 'Error fetching nearby users';
      });
  },
});

export const { resetUsers } = nearbyUsersSlice.actions;
export default nearbyUsersSlice.reducer;
