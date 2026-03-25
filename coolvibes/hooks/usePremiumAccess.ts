import { useMemo } from 'react';
import { Platform } from 'react-native';

import { useAppSelector } from '@/store/hooks';

const ACTIVE_SUBSCRIPTION_STATUSES = ['active', 'trialing', 'premium', 'pro'];

const includesPremiumKeyword = (value: unknown): boolean => {
  if (typeof value !== 'string') return false;
  const normalized = value.trim().toLowerCase();
  if (!normalized) return false;
  return (
    normalized.includes('premium') ||
    normalized.includes('pro') ||
    normalized.includes('vip')
  );
};

const hasActivePremiumSubscription = (user: Record<string, unknown>): boolean => {
  const subscription = user.subscription as Record<string, unknown> | undefined;
  const status = String(
    subscription?.status ??
      user.subscription_status ??
      user.plan_status ??
      ''
  )
    .trim()
    .toLowerCase();

  return ACTIVE_SUBSCRIPTION_STATUSES.includes(status);
};

export const usePremiumAccess = () => {
  const authState = useAppSelector(state => state.auth);
  const featureFlags = useAppSelector(state => state.featureFlags.flags);
  const premiumEntitlement = useAppSelector(state => state.featureFlags.premiumEntitlement);

  const premiumFeatureEnabled = featureFlags.premium_membership;
  const premiumPaywallEnabled = featureFlags.premium_paywall;

  const billingEnabled = useMemo(() => {
    if (Platform.OS === 'ios') return featureFlags.iap_apple_enabled;
    if (Platform.OS === 'android') return featureFlags.iap_google_enabled;
    return false;
  }, [featureFlags.iap_apple_enabled, featureFlags.iap_google_enabled]);

  const billingProvider = useMemo(() => {
    if (Platform.OS === 'ios') return 'app_store';
    if (Platform.OS === 'android') return 'play_store';
    return null;
  }, []);

  const isPremiumUser = useMemo(() => {
    const user = authState.user as Record<string, unknown> | null;
    if (premiumEntitlement.isPremium) return true;
    if (!user || !authState.token) return false;

    return (
      user.is_premium === true ||
      user.premium === true ||
      user.premium_active === true ||
      hasActivePremiumSubscription(user) ||
      includesPremiumKeyword(user.user_role) ||
      includesPremiumKeyword(user.plan) ||
      includesPremiumKeyword(user.membership_tier)
    );
  }, [authState.token, authState.user, premiumEntitlement.isPremium]);

  const canAccessPremiumFeature = !premiumFeatureEnabled || isPremiumUser;

  return {
    premiumFeatureEnabled,
    premiumPaywallEnabled,
    billingEnabled,
    billingProvider,
    premiumEntitlement,
    isPremiumUser,
    canAccessPremiumFeature,
    isPremiumRequired: premiumFeatureEnabled && !canAccessPremiumFeature,
  };
};

