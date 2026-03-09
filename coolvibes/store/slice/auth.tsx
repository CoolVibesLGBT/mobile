import { createSlice, createAsyncThunk } from '@reduxjs/toolkit';
import * as SecureStore from 'expo-secure-store';
import { Platform } from 'react-native';

import { api } from '@/services/apiService';

const TOKEN_KEY = 'authToken';

//
// Helper functions (tek noktadan yönetim)
//
async function saveToken(token: string) {
  let formattedToken = token;
  if (!token.startsWith('Bearer ')) {
    formattedToken = `Bearer ${token}`;
  }
  if (Platform.OS === 'web') {
    localStorage.setItem(TOKEN_KEY, formattedToken);
  } else {
    await SecureStore.setItemAsync(TOKEN_KEY, formattedToken);
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
      
      // Server response structure: { data: { token, user }, success: true }
      const authData = res.data;
      const token = authData?.token;
      const user = authData?.user;

      if (token) {
        const formattedToken = token.startsWith('Bearer ') ? token : `Bearer ${token}`;
        await saveToken(formattedToken);
        return { token: formattedToken, user: user || null };
      }

      return thunkAPI.rejectWithValue('Invalid response from server');
    } catch (err) {
      return thunkAPI.rejectWithValue('Login failed');
    }
  }
);

//
// REGISTER
//
export const registerThunk = createAsyncThunk(
  'auth/register',
  async (data: { name: string; nickname: string; password: string; referralCode?: string, domain: string }, thunkAPI) => {
    try {
      const res = await api.register(data);
      const authData = res.data;
      const token = authData?.token;
      const user = authData?.user;

      if (token) {
        const formattedToken = token.startsWith('Bearer ') ? token : `Bearer ${token}`;
        await saveToken(formattedToken);
        return { token: formattedToken, user: user || null };
      }

      return thunkAPI.rejectWithValue('Registration failed');
    } catch (err) {
      return thunkAPI.rejectWithValue('Registration failed');
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
      const user = res.data?.user || res.user;

      return {
        token,
        user: user,
      };
    } catch (err: any) {
      console.log('AUTO LOGIN FETCH USER INFO FAILED', err);
      // If it's a 401 Unauthenticated, we MUST clear the token
      if (err?.response?.status === 401) {
        return null; 
      }
      
      // For general network errors, keep the token but no user data
      return {
        token,
        user: null,
      };
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

    builder.addCase(loadStoredTokenThunk.rejected, (state) => {
      state.initialized = true;
    });

    builder.addCase(autoLoginThunk.fulfilled, (state, action) => {
      state.initialized = true;

      if (!action.payload) {
        // ONLY clear token if we don't have one already (prevents race with manual login)
        if (!state.token) {
          state.token = null;
          state.user = null;
        }
        return;
      }

      state.token = action.payload.token;
      state.user = action.payload.user;
    });

    builder.addCase(autoLoginThunk.rejected, (state) => {
      state.initialized = true;
    });

    builder.addCase(loginThunk.pending, state => {
      state.loading = true;
      state.error = null;
    });

    builder.addCase(loginThunk.fulfilled, (state, action) => {
      state.loading = false;
      state.token = action.payload.token;
      state.user = action.payload.user;
      state.initialized = true;
    });

    builder.addCase(loginThunk.rejected, (state, action) => {
      state.loading = false;
      state.error = String(action.payload);
    });

    builder.addCase(registerThunk.pending, state => {
      state.loading = true;
      state.error = null;
    });

    builder.addCase(registerThunk.fulfilled, (state, action) => {
      state.loading = false;
      state.token = action.payload.token;
      state.user = action.payload.user;
      state.initialized = true;
    });

    builder.addCase(registerThunk.rejected, (state, action) => {
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