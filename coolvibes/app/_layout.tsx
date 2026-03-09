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
import { Platform, View } from 'react-native';
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
import { useEffect } from 'react';
import { SocketProvider } from '@/contexts/SocketContext';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { BottomSheetModalProvider } from '@gorhom/bottom-sheet';
import { useRouter, useSegments } from 'expo-router';
import { Colors } from '@/constants/Colors';

import GlobalHeader from '@/components/GlobalHeader';

export const unstable_settings = {
  anchor: '(tabs)',
};

function AuthGuard() {
  const { token, initialized } = useAppSelector(state => state.auth);
  const segments = useSegments();
  const router = useRouter();

  useEffect(() => {
    if (!initialized) return;

    const inAuthGroup = segments[0] === '(auth)';
    const isLoginPage = segments[segments.length - 1] === 'login';

    if (!token && !inAuthGroup) {
      // User is NOT logged in and NOT in the auth group -> Redirect to login
      router.replace('/(auth)/login');
    } else if (token && inAuthGroup) {
      // User IS logged in but tried to go to auth screens -> Redirect to main app
      // Use replace to avoid history stack buildup
      router.replace('/(tabs)');
    }
  }, [token, initialized, segments[0]]);

  return null;
}

export default function RootLayout() {
  const colorScheme = useColorScheme();
  
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


  function Initializer() {
    const dispatch = useAppDispatch();
    const { loading } = useAppSelector(state => state.system);
    const { initialized } = useAppSelector(state => state.auth);

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
        dispatch(fetchInitialSync());
        dispatch(autoLoginThunk());
      };
      init();
    }, []);

    useEffect(() => {
      if (!loading && initialized && fontsLoaded) {
        SplashScreen.hideAsync().catch(() => {
          // Ignore splash screen errors if it's already hidden
        });
      }
    }, [loading, initialized, fontsLoaded]);

    return null;
  }

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



  if (!fontsLoaded) return null;

  return (
    <Provider store={store}>
      <SocketProvider>
        <GestureHandlerRootView style={{ flex: 1 }}>
          <BottomSheetModalProvider>
            <ThemeProvider value={colorScheme === 'dark' ? CustomDarkTheme : CustomLightTheme}>
              <Initializer />
              <AuthGuard />
              <View style={{ flex: 1 }}>
                <GlobalHeader />
                <Stack screenOptions={{ 
                    headerShown: false, 
                    contentStyle: { 
                        backgroundColor: colorScheme === 'dark' ? Colors.dark.background : Colors.light.background,
                    } 
                }}>
                  <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
                  <Stack.Screen name="(auth)" options={{ presentation: 'fullScreenModal', headerShown: false }} />
                  <Stack.Screen name="modal" options={{ presentation: 'modal', title: 'Modal' }} />
                  <Stack.Screen name="ChatDetail" options={{ headerShown: false }} />
                  <Stack.Screen name="CheckIn" options={{ headerShown: false }} />
                </Stack>
              </View>
              <StatusBar style={colorScheme === 'dark' ? 'light' : 'dark'} />
            </ThemeProvider>
          </BottomSheetModalProvider>
        </GestureHandlerRootView>
      </SocketProvider>
    </Provider>
  );
}
