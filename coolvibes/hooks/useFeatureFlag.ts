import { FeatureFlagKey } from '@/config/featureFlags';
import { useAppSelector } from '@/store/hooks';

export const useFeatureFlag = (key: FeatureFlagKey) =>
  useAppSelector(state => state.featureFlags.flags[key]);

export const useFeatureFlagsSnapshot = () =>
  useAppSelector(state => state.featureFlags.flags);

