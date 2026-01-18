import { createSlice, createAsyncThunk } from '@reduxjs/toolkit';
import * as SecureStore from 'expo-secure-store';
import { Platform } from 'react-native';

import { api } from '@/services/apiService';

const TOKEN_KEY = 'authToken';

//
// Helper functions (tek noktadan yönetim)
//
async function saveToken(token: string) {
  if (Platform.OS === 'web') {
    localStorage.setItem(TOKEN_KEY, token);
  } else {
    await SecureStore.setItemAsync(TOKEN_KEY, token);
  }
}

async function getToken(): Promise<string | null> {
  if (Platform.OS === 'web') {
    return localStorage.getItem(TOKEN_KEY);
  } else {
    return await SecureStore.getItemAsync(TOKEN_KEY);
  }
}

async function deleteToken() {
  if (Platform.OS === 'web') {
    localStorage.removeItem(TOKEN_KEY);
  } else {
    await SecureStore.deleteItemAsync(TOKEN_KEY);
  }
}

//
// LOGIN
//
export const loginThunk = createAsyncThunk(
  'auth/login',
  async (credentials: { nickname: string; password: string }, thunkAPI) => {
    try {
      const res = await api.login(credentials);

      const token = res.token;

      if (token) {
        await saveToken(token);
      }

      return token;
    } catch (err) {
      return thunkAPI.rejectWithValue('Login failed');
    }
  }
);

//
// CURRENT USER
//
export const getAuthUserThunk = createAsyncThunk(
  'auth/getAuthUser',
  async (_, thunkAPI) => {
    try {
      const res = await api.getAuthUserInfo();
      return res.user;
    } catch (err) {
      return thunkAPI.rejectWithValue('Auth failed');
    }
  }
);

//
// AUTO LOGIN
//
export const autoLoginThunk = createAsyncThunk(
  'auth/autoLogin',
  async (_, thunkAPI) => {
    const token = await getToken();
  console.log('TOKEN KAYDEDİLİYOR MU?', token);

    if (!token) return null;

    try {
      const res = await api.getAuthUserInfo();

      return {
        token,
        user: res.user,
      };
    } catch {
      return null;
    }
  }
);

//
// LOAD TOKEN ONLY
//
export const loadStoredTokenThunk = createAsyncThunk(
  'auth/loadStoredToken',
  async () => {
    return await getToken();
  }
);

//
// SLICE
//
const authSlice = createSlice({
  name: 'auth',
  initialState: {
    token: null as string | null,
    user: null as any,
    loading: false,
    error: null as string | null,
    initialized: false,
  },
  reducers: {
    logout(state) {
      state.token = null;
      state.user = null;
      deleteToken();
    },
  },
  extraReducers: builder => {
    builder.addCase(loadStoredTokenThunk.fulfilled, (state, action) => {
      state.token = action.payload;
      state.initialized = true;
    });

    builder.addCase(autoLoginThunk.fulfilled, (state, action) => {
      state.initialized = true;

      if (!action.payload) {
        state.token = null;
        state.user = null;
        return;
      }

      state.token = action.payload.token;
      state.user = action.payload.user;
    });

    builder.addCase(loginThunk.pending, state => {
      state.loading = true;
      state.error = null;
    });

    builder.addCase(loginThunk.fulfilled, (state, action) => {
      state.loading = false;
      state.token = action.payload;
    });

    builder.addCase(loginThunk.rejected, (state, action) => {
      state.loading = false;
      state.error = String(action.payload);
    });

    builder.addCase(getAuthUserThunk.pending, state => {
      state.loading = true;
    });

    builder.addCase(getAuthUserThunk.fulfilled, (state, action) => {
      state.loading = false;
      state.user = action.payload;
    });

    builder.addCase(getAuthUserThunk.rejected, (state, action) => {
      state.loading = false;
      state.error = String(action.payload);
    });
  },
});

export const { logout } = authSlice.actions;

export default authSlice.reducer;