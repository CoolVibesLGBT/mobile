import React from 'react';
import { View, TouchableOpacity, Text, StyleSheet, Platform } from 'react-native';
import { Tabs, useRouter } from 'expo-router';
import { BlurView } from 'expo-blur';
import * as Haptics from 'expo-haptics';
import Animated, { useAnimatedStyle, withTiming, useSharedValue } from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Flame, Radar, MessageSquare, MapPin, Plus } from 'lucide-react-native';
import { useColorScheme } from '@/hooks/use-color-scheme';
import { Colors } from '@/constants/Colors';

// --- Tab Configuration ---
const TAB_ICONS: Record<string, React.ElementType> = {
  'index': Flame,
  'nearby': MapPin,
  'Match': Radar,
  'chat': MessageSquare,
};

const TAB_LABELS: Record<string, string> = {
  'index': 'Cool',
  'nearby': 'Nearby',
  'Match': 'Radar',
  'chat': 'Chat',
};

// --- TabBar Components ---

function TabItem({ route, isFocused, navigation, isDark }: any) {
  const scale = useSharedValue(1);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  const onPress = () => {
    const event = navigation.emit({
      type: 'tabPress',
      target: route.key,
      canPreventDefault: true,
    });

    if (!event.defaultPrevented) {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
      
      // Tap feedback animation
      scale.value = withTiming(0.92, { duration: 90 }, () => {
        scale.value = withTiming(1, { duration: 150 });
      });

      if (!isFocused) {
        navigation.navigate(route.name, route.params);
      }
    }
  };

  const Icon = TAB_ICONS[route.name];
  const label = TAB_LABELS[route.name];
  // Spec: default black icons/labels; active tab shows a black/white circular marker.
  const inactiveFg = isDark ? '#FFFFFF' : '#000000';
  const activeBg = isDark ? '#FFFFFF' : '#000000';
  const activeFg = isDark ? '#000000' : '#FFFFFF';

  return (
    <TouchableOpacity
      accessibilityRole="button"
      onPress={onPress}
      style={styles.tabItem}
      activeOpacity={1}
    >
      <Animated.View
        style={[
          styles.iconCircle,
          { backgroundColor: isFocused ? activeBg : 'transparent' },
          animatedStyle,
        ]}
      >
        <Icon size={24} color={isFocused ? activeFg : inactiveFg} strokeWidth={isFocused ? 2.75 : 2.25} />
      </Animated.View>
      <Text style={[
        styles.tabLabel, 
        { color: inactiveFg },
        isFocused && { fontFamily: 'Inter-Bold' }
      ]}>
        {label}
      </Text>
    </TouchableOpacity>
  );
}

function CheckInButton({ palette, isDark }: any) {
  const router = useRouter();

  const onPress = () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    palette.navigation?.navigate('CheckIn');
  };

  return (
    <View style={styles.checkInButtonWrapper}>
      <TouchableOpacity 
        onPress={onPress} 
        style={[
          styles.checkInButton,
          {
            backgroundColor: palette.accent,
            borderColor: palette.surface,
            shadowColor: isDark ? '#000000' : '#0F172A',
            shadowOpacity: isDark ? 0.4 : 0.16,
          },
        ]}
        activeOpacity={0.9}
      >
        <Plus size={24} color={isDark ? Colors.dark.background : Colors.light.surface} strokeWidth={3.25} />
      </TouchableOpacity>
    </View>
  );
}

function CustomTabBar({ state, navigation }: any) {
  const colorScheme = useColorScheme() ?? 'light';
  const palette = Colors[colorScheme];
  const isDark = colorScheme === 'dark';
  const insets = useSafeAreaInsets();
  const orderedRoutes = ['index', 'nearby', 'Match', 'chat'];
  const tabBarHeight = (Platform.OS === 'ios' ? 62 : 66) + Math.max(insets.bottom, 8);
  const hairline = isDark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.08)';

  const visibleRoutes = state.routes
    .filter((route: any) => orderedRoutes.includes(route.name))
    .sort((a: any, b: any) => orderedRoutes.indexOf(a.name) - orderedRoutes.indexOf(b.name));

  const firstHalf = visibleRoutes.slice(0, 2);
  const secondHalf = visibleRoutes.slice(2);

  const renderTab = (route: any) => {
    const isFocused = state.index === state.routes.findIndex((r: any) => r.key === route.key);
    return (
      <TabItem
        key={route.key}
        route={route}
        isFocused={isFocused}
        navigation={navigation}
        isDark={isDark}
      />
    );
  };

  return (
    <View style={[styles.tabBarContainer, { height: tabBarHeight }]}>
      <BlurView
        // Match GlobalHeader blur 1:1 (user prefers header blur)
        intensity={isDark ? 45 : 90}
        style={StyleSheet.absoluteFill}
        tint={isDark ? 'dark' : 'light'}
        pointerEvents="none"
        blurReductionFactor={Platform.OS === 'android' ? 2 : 4}
        experimentalBlurMethod={Platform.OS === 'android' ? 'dimezisBlurView' : 'none'}
      />
      <View
        style={[
          styles.tabBarContent,
          {
            borderTopColor: hairline,
            paddingBottom: Math.max(insets.bottom, 8),
          },
        ]}
      >
        {firstHalf.map(renderTab)}
        <CheckInButton palette={{ ...palette, navigation }} isDark={isDark} />
        {secondHalf.map(renderTab)}
      </View>
    </View>
  );
}

// --- Layout Definition ---

export default function TabLayout() {
  return (
    <Tabs
      tabBar={props => <CustomTabBar {...props} />}
      screenOptions={{
        headerShown: false,
        tabBarHideOnKeyboard: true,
      }}
    >
      <Tabs.Screen name="index" />
      <Tabs.Screen name="nearby" />
      <Tabs.Screen name="Match" />
      <Tabs.Screen name="CheckIn" options={{ href: null }} />
      <Tabs.Screen name="Activity" options={{ href: null }} />
      <Tabs.Screen name="chat" />
      <Tabs.Screen name="Profile" options={{ href: null }} />
      <Tabs.Screen name="search" options={{ href: null }} /> 
    </Tabs>
  );
}

// --- Styles ---

const styles = StyleSheet.create({
  tabBarContainer: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    backgroundColor: 'transparent',
    borderTopWidth: 0,
    elevation: 0,
  },
  tabBarContent: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 10,
    borderTopWidth: StyleSheet.hairlineWidth,
  },
  tabItem: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    height: '100%',
    paddingTop: 6,
  },
  iconCircle: {
    width: 44,
    height: 44,
    borderRadius: 22,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 2,
  },
  tabLabel: {
    fontSize: 10,
    fontFamily: 'Inter-SemiBold',
    letterSpacing: 0.6,
    textTransform: 'uppercase',
    marginTop: 2,
  },
  checkInButtonWrapper: {
    width: 72,
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 10,
    height: '100%',
  },
  checkInButton: {
    width: 56,
    height: 56,
    borderRadius: 28,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: Platform.OS === 'ios' ? -32 : -28,
    borderWidth: 3,
    shadowOffset: { width: 0, height: 6 },
    shadowRadius: 10,
    elevation: 10,
  },
});
