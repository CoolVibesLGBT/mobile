import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import { api } from '@/services/apiService';
import { Actions } from '@/services/actions';

export interface InitialData {
  vapid_public_key: string;
  preferences: any;
  event_kinds: any[];
  report_kinds: any[];
  countries: Record<string, any>;
  languages: Record<string, any>;
  checkin_tag_types: any[];
  status: string;
}

interface SystemState {
  data: InitialData | null;
  loading: boolean;
  error: string | null;
  theme: 'system' | 'light' | 'dark';
  blurPhotos: boolean;
  language: string;
  fontSize: 'small' | 'medium' | 'large';
}

const initialState: SystemState = {
  data: null,
  loading: true,
  error: null,
  theme: 'system',
  blurPhotos: false,
  language: 'en',
  fontSize: 'medium',
};

export const fetchInitialSync = createAsyncThunk<
  InitialData,
  void,
  { rejectValue: string }
>(
  'app/fetchInitialSync',
  async (_, thunkAPI) => {
    try {
      const res = await api.call<InitialData>(Actions.SYSTEM_INITIAL_SYNC);
      return res;
    } catch (err: any) {
      return thunkAPI.rejectWithValue(err.message ?? 'Initial sync failed');
    }
  }
);

const systemSlice = createSlice({
  name: 'system',
  initialState,
  reducers: {
    setTheme(state, action: PayloadAction<'system' | 'light' | 'dark'>) {
      state.theme = action.payload;
    },
    toggleBlur(state) {
      state.blurPhotos = !state.blurPhotos;
    },
    setBlur(state, action: PayloadAction<boolean>) {
      state.blurPhotos = action.payload;
    },
    setLanguage(state, action: PayloadAction<string>) {
      state.language = action.payload;
    },
    setFontSize(state, action: PayloadAction<'small' | 'medium' | 'large'>) {
      state.fontSize = action.payload;
    },
    clearSystemState(state) {
      state.data = null;
      state.error = null;
      state.loading = false;
    },
  },
  extraReducers: builder => {
    builder
      .addCase(fetchInitialSync.pending, state => {
        state.loading = true;
        state.error = null;
      })
      .addCase(fetchInitialSync.fulfilled, (state, action: PayloadAction<InitialData>) => {
        state.loading = false;
        state.data = action.payload;
      })
      .addCase(fetchInitialSync.rejected, (state, action) => {
        state.loading = false;
        state.error = action.payload ?? 'Initial sync error';
      });
  },
});

export const { clearSystemState, setTheme, toggleBlur, setBlur, setLanguage, setFontSize } = systemSlice.actions;
export default systemSlice.reducer;
