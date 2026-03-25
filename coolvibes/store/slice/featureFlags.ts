import { createAsyncThunk, createSlice, PayloadAction } from '@reduxjs/toolkit';
import * as SecureStore from 'expo-secure-store';
import { Platform } from 'react-native';

import {
  FeatureFlagKey,
  FeatureFlagMap,
  getFeatureFlagsSnapshot,
} from '@/config/featureFlags';

const FEATURE_FLAG_OVERRIDES_KEY = 'featureFlagOverrides';
const PREMIUM_ENTITLEMENT_KEY = 'premiumEntitlement';

export type PremiumEntitlementStatus =
  | 'inactive'
  | 'active'
  | 'trialing'
  | 'grace_period'
  | 'expired'
  | 'revoked';

export type BillingProvider = 'app_store' | 'play_store' | 'stripe' | null;

export interface PremiumEntitlement {
  isPremium: boolean;
  status: PremiumEntitlementStatus;
  provider: BillingProvider;
  productId: string | null;
  expiresAt: string | null;
  lastSyncedAt: string | null;
}

interface FeatureFlagsState {
  flags: FeatureFlagMap;
  overrides: Partial<Record<FeatureFlagKey, boolean>>;
  premiumEntitlement: PremiumEntitlement;
  hydrated: boolean;
}

const defaultPremiumEntitlement: PremiumEntitlement = {
  isPremium: false,
  status: 'inactive',
  provider: null,
  productId: null,
  expiresAt: null,
  lastSyncedAt: null,
};

const initialState: FeatureFlagsState = {
  flags: getFeatureFlagsSnapshot(),
  overrides: {},
  premiumEntitlement: defaultPremiumEntitlement,
  hydrated: false,
};

const readStoredJson = async <T>(key: string): Promise<T | null> => {
  try {
    const raw = Platform.OS === 'web'
      ? globalThis.localStorage?.getItem(key)
      : await SecureStore.getItemAsync(key);
    if (!raw) return null;
    return JSON.parse(raw) as T;
  } catch {
    return null;
  }
};

const writeStoredJson = async (key: string, value: unknown) => {
  const serialized = JSON.stringify(value);
  if (Platform.OS === 'web') {
    globalThis.localStorage?.setItem(key, serialized);
    return;
  }
  await SecureStore.setItemAsync(key, serialized);
};

const deleteStoredJson = async (key: string) => {
  if (Platform.OS === 'web') {
    globalThis.localStorage?.removeItem(key);
    return;
  }
  await SecureStore.deleteItemAsync(key);
};

const sanitizeOverrides = (
  input: Partial<Record<FeatureFlagKey, boolean>> | null | undefined
): Partial<Record<FeatureFlagKey, boolean>> => {
  if (!input || typeof input !== 'object') return {};

  const output: Partial<Record<FeatureFlagKey, boolean>> = {};
  for (const [key, value] of Object.entries(input)) {
    if (typeof value !== 'boolean') continue;
    output[key as FeatureFlagKey] = value;
  }
  return output;
};

export const hydrateFeatureFlagsThunk = createAsyncThunk(
  'featureFlags/hydrate',
  async () => {
    const [overrides, entitlement] = await Promise.all([
      readStoredJson<Partial<Record<FeatureFlagKey, boolean>>>(FEATURE_FLAG_OVERRIDES_KEY),
      readStoredJson<PremiumEntitlement>(PREMIUM_ENTITLEMENT_KEY),
    ]);

    const sanitizedOverrides = sanitizeOverrides(overrides);
    return {
      overrides: sanitizedOverrides,
      flags: getFeatureFlagsSnapshot(sanitizedOverrides),
      premiumEntitlement: entitlement
        ? { ...defaultPremiumEntitlement, ...entitlement }
        : defaultPremiumEntitlement,
    };
  }
);

export const setFeatureFlagOverrideThunk = createAsyncThunk(
  'featureFlags/setOverride',
  async (
    payload: { key: FeatureFlagKey; value: boolean },
    thunkAPI
  ) => {
    const state = thunkAPI.getState() as { featureFlags: FeatureFlagsState };
    const overrides = {
      ...state.featureFlags.overrides,
      [payload.key]: payload.value,
    };
    await writeStoredJson(FEATURE_FLAG_OVERRIDES_KEY, overrides);
    return {
      overrides,
      flags: getFeatureFlagsSnapshot(overrides),
    };
  }
);

export const clearFeatureFlagOverrideThunk = createAsyncThunk(
  'featureFlags/clearOverride',
  async (key: FeatureFlagKey, thunkAPI) => {
    const state = thunkAPI.getState() as { featureFlags: FeatureFlagsState };
    const overrides = { ...state.featureFlags.overrides };
    delete overrides[key];

    if (Object.keys(overrides).length === 0) {
      await deleteStoredJson(FEATURE_FLAG_OVERRIDES_KEY);
    } else {
      await writeStoredJson(FEATURE_FLAG_OVERRIDES_KEY, overrides);
    }

    return {
      overrides,
      flags: getFeatureFlagsSnapshot(overrides),
    };
  }
);

export const setPremiumEntitlementThunk = createAsyncThunk(
  'featureFlags/setPremiumEntitlement',
  async (
    payload: Partial<PremiumEntitlement> & Pick<PremiumEntitlement, 'isPremium' | 'status'>,
    thunkAPI
  ) => {
    const state = thunkAPI.getState() as { featureFlags: FeatureFlagsState };
    const nextEntitlement: PremiumEntitlement = {
      ...state.featureFlags.premiumEntitlement,
      ...payload,
      lastSyncedAt: new Date().toISOString(),
    };
    await writeStoredJson(PREMIUM_ENTITLEMENT_KEY, nextEntitlement);
    return nextEntitlement;
  }
);

export const clearPremiumEntitlementThunk = createAsyncThunk(
  'featureFlags/clearPremiumEntitlement',
  async () => {
    await deleteStoredJson(PREMIUM_ENTITLEMENT_KEY);
    return defaultPremiumEntitlement;
  }
);

const featureFlagsSlice = createSlice({
  name: 'featureFlags',
  initialState,
  reducers: {
    setPremiumEntitlement(state, action: PayloadAction<PremiumEntitlement>) {
      state.premiumEntitlement = action.payload;
    },
  },
  extraReducers: builder => {
    builder
      .addCase(hydrateFeatureFlagsThunk.fulfilled, (state, action) => {
        state.overrides = action.payload.overrides;
        state.flags = action.payload.flags;
        state.premiumEntitlement = action.payload.premiumEntitlement;
        state.hydrated = true;
      })
      .addCase(hydrateFeatureFlagsThunk.rejected, state => {
        state.hydrated = true;
      })
      .addCase(setFeatureFlagOverrideThunk.fulfilled, (state, action) => {
        state.overrides = action.payload.overrides;
        state.flags = action.payload.flags;
      })
      .addCase(clearFeatureFlagOverrideThunk.fulfilled, (state, action) => {
        state.overrides = action.payload.overrides;
        state.flags = action.payload.flags;
      })
      .addCase(setPremiumEntitlementThunk.fulfilled, (state, action) => {
        state.premiumEntitlement = action.payload;
      })
      .addCase(clearPremiumEntitlementThunk.fulfilled, state => {
        state.premiumEntitlement = defaultPremiumEntitlement;
      });
  },
});

export const { setPremiumEntitlement } = featureFlagsSlice.actions;
export default featureFlagsSlice.reducer;

