import { DarkTheme, DefaultTheme, ThemeProvider } from '@react-navigation/native';
import { Stack, useRouter, useSegments } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import 'react-native-reanimated';

import { useColorScheme } from '@/hooks/use-color-scheme';
import { store } from "../store"
import { Provider } from 'react-redux';
import { fetchInitialSync } from '@/store/slice/system';
import { autoLoginThunk } from '@/store/slice/auth';
import * as SecureStore from 'expo-secure-store';
import { useAppDispatch, useAppSelector } from '@/store/hooks';
import { Image, Platform, StyleSheet, View } from 'react-native';
import { 
  useFonts, 
  Inter_400Regular, 
  Inter_600SemiBold,
  Inter_700Bold, 
  Inter_900Black 
} from '@expo-google-fonts/inter';
import { 
  Outfit_400Regular,
  Outfit_600SemiBold,
  Outfit_700Bold, 
  Outfit_900Black 
} from '@expo-google-fonts/outfit';
import { TEST_ACCESS_TOKEN } from '@/config';
import { useEffect, useRef } from 'react';
import { SocketProvider } from '@/contexts/SocketContext';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { BottomSheetModalProvider } from '@gorhom/bottom-sheet';
import { Colors } from '@/constants/Colors';

import GlobalHeader from '@/components/GlobalHeader';
import AppErrorBoundary from '@/components/AppErrorBoundary';
import AppErrorOverlay from '@/components/AppErrorOverlay';
import { installGlobalErrorHandler } from '@/helpers/errorReporter';

installGlobalErrorHandler();

export const unstable_settings = {
  anchor: '(tabs)',
};

function AppBootScreen({ dark }: { dark: boolean }) {
  return (
    <View style={[styles.bootScreen, { backgroundColor: dark ? '#000000' : '#ffffff' }]}>
      <Image
        source={require('@/assets/images/splash-icon.png')}
        style={styles.bootLogo}
        resizeMode="contain"
      />
    </View>
  );
}

function AuthGuard() {
  const { token, initialized } = useAppSelector(state => state.auth);
  const segments = useSegments();
  const router = useRouter();
  // Ref-based lock: prevents double-navigate when token + segments both change
  const navigatingRef = useRef(false);

  useEffect(() => {
    // Only act after auth is initialized
    if (!initialized) return;

    const inAuthGroup = segments[0] === '(auth)';

    if (!token && !inAuthGroup) {
      if (!navigatingRef.current) {
        navigatingRef.current = true;
        router.replace('/(auth)/login');
        setTimeout(() => { navigatingRef.current = false; }, 500);
      }
    } else if (token && inAuthGroup) {
      if (!navigatingRef.current) {
        navigatingRef.current = true;
        router.replace('/(tabs)');
        setTimeout(() => { navigatingRef.current = false; }, 500);
      }
    }
  }, [token, initialized, segments, router]);

  return null;
}

function ThemedApp() {
  const colorScheme = useColorScheme();
  const isDark = colorScheme === 'dark';
  const dispatch = useAppDispatch();
  const { loading } = useAppSelector(state => state.system);
  const { initialized, token } = useAppSelector(state => state.auth);
  const segments = useSegments();

  const [fontsLoaded] = useFonts({
    'Inter-Regular': Inter_400Regular,
    'Inter-SemiBold': Inter_600SemiBold,
    'Inter-Bold': Inter_700Bold,
    'Inter-Black': Inter_900Black,
    'Outfit-Regular': Outfit_400Regular,
    'Outfit-SemiBold': Outfit_600SemiBold,
    'Outfit-Bold': Outfit_700Bold,
    'Outfit-Black': Outfit_900Black,
  });

  const setTestToken = async () => {
    const existingToken = await (Platform.OS === 'web' ? localStorage.getItem('authToken') : SecureStore.getItemAsync('authToken'));
    if (existingToken) return;

    if (Platform.OS === 'web') {
      localStorage.setItem('authToken', TEST_ACCESS_TOKEN);
      return;
    }
    await SecureStore.setItemAsync('authToken', TEST_ACCESS_TOKEN);
  };

  useEffect(() => {
    const init = async () => {
      await setTestToken();
      // Initial sync and auto login
      dispatch(fetchInitialSync());
      dispatch(autoLoginThunk());
    };
    init();
  }, [dispatch]);

  const isReady = initialized && fontsLoaded && !loading;
  const inAuthGroup = segments[0] === '(auth)';
  const needsRedirect = initialized && ((!token && !inAuthGroup) || (token && inAuthGroup));

  const CustomDarkTheme = {
    ...DarkTheme,
    colors: {
      ...DarkTheme.colors,
      primary: Colors.dark.text,
      background: Colors.dark.background,
      card: Colors.dark.card,
      text: Colors.dark.text,
      border: Colors.dark.border,
      notification: Colors.dark.notification,
    },
  };

  const CustomLightTheme = {
    ...DefaultTheme,
    colors: {
      ...DefaultTheme.colors,
      primary: Colors.light.text,
      background: Colors.light.background,
      card: Colors.light.card,
      text: Colors.light.text,
      border: Colors.light.border,
      notification: Colors.light.notification,
    },
  };

  if (!isReady || needsRedirect) {
    return (
      <ThemeProvider value={isDark ? CustomDarkTheme : CustomLightTheme}>
        <AuthGuard />
        <AppBootScreen dark={isDark} />
        <StatusBar style={isDark ? 'light' : 'dark'} />
      </ThemeProvider>
    );
  }

  return (
    <ThemeProvider value={isDark ? CustomDarkTheme : CustomLightTheme}>
      <AuthGuard />
      <View style={{ flex: 1 }}>
        <GlobalHeader />
        <AppErrorOverlay />
        <Stack screenOptions={{ 
            headerShown: false, 
            contentStyle: { 
                backgroundColor: colorScheme === 'dark' ? Colors.dark.background : Colors.light.background,
            } 
        }}>
          <Stack.Screen name="(tabs)" options={{ animation: 'fade' }} />
          <Stack.Screen name="(auth)" options={{ presentation: 'fullScreenModal', headerShown: false }} />
          <Stack.Screen name="modal" options={{ presentation: 'modal', title: 'Modal' }} />
          <Stack.Screen name="ChatDetail" options={{ headerShown: false }} />
          <Stack.Screen name="CheckIn" options={{ headerShown: false }} />
          <Stack.Screen name="CheckInCreate" options={{ headerShown: false }} />
          <Stack.Screen name="CreatePost" options={{ headerShown: false }} />
          <Stack.Screen name="PostDetail" options={{ headerShown: false }} />
          <Stack.Screen name="PendingTasks" options={{ headerShown: false }} />
          <Stack.Screen name="Classifieds" options={{ headerShown: false }} />
          <Stack.Screen name="ClassifiedCreate" options={{ headerShown: false }} />
          <Stack.Screen name="ClassifiedDetail" options={{ headerShown: false }} />
          <Stack.Screen name="PlaceDetail" options={{ headerShown: false }} />
          <Stack.Screen name="places" options={{ headerShown: false }} />
          <Stack.Screen name="place-detail" options={{ headerShown: false }} />
          <Stack.Screen name="legal/index" options={{ headerShown: false }} />
          <Stack.Screen name="legal/[page]" options={{ headerShown: false }} />
          <Stack.Screen name="Settings" options={{ headerShown: false }} />
          <Stack.Screen name="ProfileEdit" options={{ headerShown: false }} />
          <Stack.Screen name="ProfileMetricDetail" options={{ headerShown: false }} />
        </Stack>
      </View>
      <StatusBar style={isDark ? 'light' : 'dark'} />
    </ThemeProvider>
  );
}

export default function RootLayout() {
  return (
    <Provider store={store}>
      <SocketProvider>
        <GestureHandlerRootView style={{ flex: 1 }}>
          <BottomSheetModalProvider>
            <AppErrorBoundary>
              <ThemedApp />
            </AppErrorBoundary>
          </BottomSheetModalProvider>
        </GestureHandlerRootView>
      </SocketProvider>
    </Provider>
  );
}

const styles = StyleSheet.create({
  bootScreen: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  bootLogo: {
    width: 200,
    height: 200,
  },
});
