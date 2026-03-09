import { useColorScheme as useNativeColorScheme } from 'react-native';
import { useAppSelector } from '@/store/hooks';

export function useColorScheme() {
  const systemTheme = useAppSelector(state => state.system.theme);
  const nativeFallback = useNativeColorScheme();
  
  if (systemTheme === 'system') {
    return nativeFallback;
  }
  
  return systemTheme;
}
