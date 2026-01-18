import { DarkTheme, DefaultTheme, ThemeProvider } from '@react-navigation/native';
import { SplashScreen, Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import 'react-native-reanimated';

import { useColorScheme } from '@/hooks/use-color-scheme';
import { Icon, NativeTabs } from 'expo-router/unstable-native-tabs';
import { store } from "../store"
import { Provider } from 'react-redux';
import { fetchInitialSync } from '@/store/slice/system';
import { autoLoginThunk } from '@/store/slice/auth';
import * as SecureStore from 'expo-secure-store';
import { useAppDispatch, useAppSelector } from '@/store/hooks';
import { Platform } from 'react-native';
import { TEST_ACCESS_TOKEN } from '@/config';
import { useEffect } from 'react';
import { SocketProvider } from '@/contexts/SocketContext';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { BottomSheetModalProvider } from '@gorhom/bottom-sheet';

export const unstable_settings = {
  anchor: '(tabs)',
};

export default function RootLayout() {
  const colorScheme = useColorScheme();


  function Initializer() {
    const dispatch = useAppDispatch();
    const { loading } = useAppSelector(state => state.system);

    const setTestToken = async () => {
      if (Platform.OS === 'web') {
        localStorage.setItem('authToken', TEST_ACCESS_TOKEN);
        return;
      }
      await SecureStore.setItemAsync('authToken', TEST_ACCESS_TOKEN);
    };


    useEffect(() => {
      setTestToken()
      dispatch(fetchInitialSync());
      dispatch(autoLoginThunk());

    }, []);

    useEffect(() => {
      if (!loading) SplashScreen.hideAsync();
    }, [loading]);

    return null;
  }

  return (
    <Provider store={store}>
      <Initializer />
      <SocketProvider>
        <GestureHandlerRootView style={{ flex: 1 }}>
          <BottomSheetModalProvider>

            <ThemeProvider value={colorScheme === 'dark' ? DarkTheme : DefaultTheme}>
              <Stack>
                <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
                <Stack.Screen name="modal" options={{ presentation: 'modal', title: 'Modal' }} />
              </Stack>
              <StatusBar style="auto" />
            </ThemeProvider>

          </BottomSheetModalProvider>
        </GestureHandlerRootView>
      </SocketProvider>
    </Provider>
  );
}
