import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import { api } from '@/services/apiService';

interface Cursor {
  prev: string | null;
  next: string | null;
}

interface NearByPlacesState {
  places: any[];
  loading: boolean;
  error: string | null;
  cursor: Cursor | null;
}

const initialState: NearByPlacesState = {
  places: [],
  loading: false,
  error: null,
  cursor: null,
};

export const fetchNearbyPlaces = createAsyncThunk<
  { places: any[]; cursor: Cursor | null },
  { latitude: number | null; longitude: number | null; cursor?: Cursor | null; limit?: number | null },
  { rejectValue: string }
>(
  'nearbyPlaces/fetchNearbyPlaces',
  async ({ latitude, longitude, cursor = null, limit = null }, thunkAPI) => {
    try {
      const state: any = thunkAPI.getState();
      const currentCursor = cursor ?? state.nearbyPlaces.cursor;
      const nextCursor = currentCursor ? currentCursor.next : null;

      const response = await api.fetchNearbyPlaces(
        latitude,
        longitude,
        nextCursor,
        limit
      );

      console.log("Cursor sent to API:", nextCursor);
      console.log("Cursor returned by API:", response.cursor);

      if (!response.success) {
        return thunkAPI.rejectWithValue(response.error || 'Failed to fetch places');
      }

      return {
        places: response.places,
        cursor: response.cursor,
      };
    } catch (error: any) {
      return thunkAPI.rejectWithValue(error.message);
    }
  }
);

const nearbyPlacesSlice = createSlice({
  name: 'nearbyPlaces',
  initialState,
  reducers: {
    resetPlaces(state) {
      state.places = [];
      state.cursor = null;
      state.error = null;
      state.loading = false;
    },
  },
  extraReducers: (builder) => {
    builder
      .addCase(fetchNearbyPlaces.pending, (state) => {
        state.loading = true;
        state.error = null;
      })
      .addCase(fetchNearbyPlaces.fulfilled, (state, action: PayloadAction<{ places: any[]; cursor: Cursor | null }>) => {
        state.loading = false;
        state.places = [...state.places, ...action.payload.places];
        state.cursor = action.payload.cursor;
      })
      .addCase(fetchNearbyPlaces.rejected, (state, action) => {
        state.loading = false;
        state.error = action.payload ?? 'Error fetching nearby places';
      });
  },
});

export const { resetPlaces } = nearbyPlacesSlice.actions;
export default nearbyPlacesSlice.reducer;