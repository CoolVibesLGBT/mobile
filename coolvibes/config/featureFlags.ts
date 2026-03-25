export type FeatureFlagKey =
  | 'premium_membership'
  | 'premium_paywall'
  | 'iap_apple_enabled'
  | 'iap_google_enabled';

export type FeatureFlagMap = Record<FeatureFlagKey, boolean>;

const DEFAULT_FEATURE_FLAGS: FeatureFlagMap = {
  premium_membership: true,
  premium_paywall: true,
  iap_apple_enabled: true,
  iap_google_enabled: true,
};

const FEATURE_FLAG_ENV_KEYS: Record<FeatureFlagKey, string> = {
  premium_membership: 'EXPO_PUBLIC_FF_PREMIUM_MEMBERSHIP',
  premium_paywall: 'EXPO_PUBLIC_FF_PREMIUM_PAYWALL',
  iap_apple_enabled: 'EXPO_PUBLIC_FF_IAP_APPLE_ENABLED',
  iap_google_enabled: 'EXPO_PUBLIC_FF_IAP_GOOGLE_ENABLED',
};

export const parseBooleanFlag = (value: unknown): boolean | null => {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'number') {
    if (value === 1) return true;
    if (value === 0) return false;
    return null;
  }
  if (typeof value !== 'string') return null;

  const normalized = value.trim().toLowerCase();
  if (!normalized) return null;
  if (['1', 'true', 'yes', 'on'].includes(normalized)) return true;
  if (['0', 'false', 'no', 'off'].includes(normalized)) return false;
  return null;
};

const env = (process.env ?? {}) as Record<string, string | undefined>;

export const getEnvFeatureFlag = (key: FeatureFlagKey): boolean | null => {
  const envKey = FEATURE_FLAG_ENV_KEYS[key];
  return parseBooleanFlag(env[envKey]);
};

export const resolveFeatureFlagValue = (
  key: FeatureFlagKey,
  overrides?: Partial<Record<FeatureFlagKey, boolean>>
): boolean => {
  if (overrides && typeof overrides[key] === 'boolean') {
    return Boolean(overrides[key]);
  }

  const envValue = getEnvFeatureFlag(key);
  if (envValue !== null) return envValue;

  return DEFAULT_FEATURE_FLAGS[key];
};

export const getFeatureFlagsSnapshot = (
  overrides?: Partial<Record<FeatureFlagKey, boolean>>
): FeatureFlagMap => ({
  premium_membership: resolveFeatureFlagValue('premium_membership', overrides),
  premium_paywall: resolveFeatureFlagValue('premium_paywall', overrides),
  iap_apple_enabled: resolveFeatureFlagValue('iap_apple_enabled', overrides),
  iap_google_enabled: resolveFeatureFlagValue('iap_google_enabled', overrides),
});

