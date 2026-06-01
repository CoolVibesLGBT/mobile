import React from 'react';
import { View, TouchableOpacity, StyleSheet, Text } from 'react-native';
import { Tabs } from 'expo-router';
import { LinearGradient } from 'expo-linear-gradient';
import * as Haptics from 'expo-haptics';
import Animated, { useAnimatedStyle, withTiming, useSharedValue } from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Flame, MapPin } from 'lucide-react-native';
import MaterialCommunityIcons from '@expo/vector-icons/MaterialCommunityIcons';
import { useColorScheme } from '@/hooks/use-color-scheme';
import { Colors } from '@/constants/Colors';

// --- Tab Configuration ---
const TAB_ICONS: Record<string, { type: 'lucide' | 'mdi'; icon: any }> = {
  'index': { type: 'lucide', icon: Flame },
  'nearby': { type: 'lucide', icon: MapPin },
  'CheckIn': { type: 'mdi', icon: 'map-marker-plus-outline' },
  'Match': { type: 'mdi', icon: 'chart-bubble' },
  'chat': { type: 'mdi', icon: 'chat-processing-outline' },
};

const TAB_LABELS: Record<string, string> = {
  'index': 'Cool',
  'nearby': 'Nearby',
  'CheckIn': 'Check-in',
  'Match': 'Radar',
  'chat': 'Chat',
};

const MAIN_ROUTES = ['index', 'nearby', 'Match', 'chat'];
const PRIMARY_ROUTE = 'CheckIn';

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

  const iconConfig = TAB_ICONS[route.name];
  const label = TAB_LABELS[route.name];
  const palette = isDark ? Colors.dark : Colors.light;
  const inactiveFg = palette.textSoft;
  const activeFg = Colors.light.text;
  const buttonBackground = isFocused
    ? isDark
      ? 'rgba(250,250,255,0.94)'
      : 'rgba(255,255,255,0.94)'
    : isDark
      ? 'rgba(250,250,255,0.88)'
      : 'rgba(255,255,255,0.90)';

  const iconColor = isFocused ? activeFg : inactiveFg;

  return (
    <TouchableOpacity
      accessibilityRole="button"
      accessibilityLabel={label}
      onPress={onPress}
      style={[
        styles.tabButtonWrap,
        isFocused ? styles.tabButtonWrapActive : styles.tabButtonWrapIdle,
      ]}
      activeOpacity={1}
    >
      <Animated.View
        style={[
          styles.floatingTabButton,
          isFocused ? styles.floatingTabButtonActive : styles.floatingTabButtonIdle,
          { backgroundColor: buttonBackground },
          animatedStyle,
        ]}
      >
        {iconConfig?.type === 'mdi' ? (
          <MaterialCommunityIcons
            name={iconConfig.icon}
            size={24}
            color={iconColor}
          />
        ) : (
          <iconConfig.icon
            size={24}
            color={iconColor}
            strokeWidth={isFocused ? 2.75 : 2.25}
          />
        )}
        {isFocused ? (
          <Text style={styles.activeTabText} numberOfLines={1}>
            {label}
          </Text>
        ) : null}
      </Animated.View>
    </TouchableOpacity>
  );
}

function PrimaryAction({ route, isFocused, navigation }: any) {
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
      scale.value = withTiming(0.96, { duration: 90 }, () => {
        scale.value = withTiming(1, { duration: 150 });
      });

      if (!isFocused) {
        navigation.navigate(route.name, route.params);
      }
    }
  };

  return (
    <TouchableOpacity
      accessibilityRole="button"
      accessibilityLabel={TAB_LABELS[route.name]}
      onPress={onPress}
      activeOpacity={1}
    >
      <Animated.View style={[styles.primaryAction, animatedStyle]}>
        <MaterialCommunityIcons name="map-marker-plus-outline" size={28} color={Colors.light.accentText} />
      </Animated.View>
    </TouchableOpacity>
  );
}

function CustomTabBar({ state, navigation }: any) {
  const colorScheme = useColorScheme() ?? 'light';
  const isDark = colorScheme === 'dark';
  const insets = useSafeAreaInsets();
  const orderedRoutes = ['index', 'nearby', 'CheckIn', 'Match', 'chat'];
  const safeBottom = Math.max(insets.bottom, 8);
  const dockHeight = 58;
  const tabBarHeight = dockHeight + safeBottom;
  const bottomFadeColors: [string, string, string, string] = isDark
    ? ['rgba(0,0,0,0)', 'rgba(0,0,0,0.28)', 'rgba(0,0,0,0.62)', 'rgba(0,0,0,0.82)']
    : ['rgba(255,255,255,0)', 'rgba(255,255,255,0.42)', 'rgba(255,255,255,0.88)', Colors.light.surface1];

  const visibleRoutes = state.routes
    .filter((route: any) => orderedRoutes.includes(route.name))
    .sort((a: any, b: any) => orderedRoutes.indexOf(a.name) - orderedRoutes.indexOf(b.name));

  const mainRoutes = visibleRoutes.filter((route: any) => MAIN_ROUTES.includes(route.name));
  const primaryRoute = visibleRoutes.find((route: any) => route.name === PRIMARY_ROUTE);

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
    <View pointerEvents="box-none" style={[styles.tabBarContainer, { height: tabBarHeight }]}>
      <LinearGradient
        pointerEvents="none"
        colors={bottomFadeColors}
        locations={[0, 0.42, 0.76, 1]}
        style={styles.tabBarFade}
      />
      <View
        style={[
          styles.tabBarSurface,
          {
            bottom: safeBottom,
            height: dockHeight,
          },
        ]}
      >
        {mainRoutes.map(renderTab)}

        {primaryRoute ? (
          <PrimaryAction
            route={primaryRoute}
            isFocused={state.index === state.routes.findIndex((r: any) => r.key === primaryRoute.key)}
            navigation={navigation}
          />
        ) : null}
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
        tabBarStyle: {
          position: 'absolute',
          backgroundColor: 'transparent',
          borderTopWidth: 0,
          elevation: 0,
        },
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
    zIndex: 30,
    overflow: 'visible',
  },
  tabBarFade: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 0,
    height: 124,
  },
  tabBarSurface: {
    position: 'absolute',
    left: 12,
    right: 12,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
  },
  tabButtonWrap: {
    alignItems: 'center',
    justifyContent: 'center',
    height: '100%',
  },
  tabButtonWrapIdle: {
    width: 48,
  },
  tabButtonWrapActive: {
    width: 108,
  },
  floatingTabButton: {
    height: 48,
    borderRadius: 24,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#121217',
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.10,
    shadowRadius: 12,
    elevation: 8,
  },
  floatingTabButtonIdle: {
    width: 48,
  },
  floatingTabButtonActive: {
    width: 108,
    flexDirection: 'row',
    gap: 8,
    paddingHorizontal: 16,
  },
  activeTabText: {
    color: '#222222',
    fontSize: 15,
    lineHeight: 18,
    fontFamily: 'Inter-Bold',
  },
  primaryAction: {
    height: 56,
    width: 72,
    borderRadius: 999,
    backgroundColor: '#FF37C7',
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#121217',
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.14,
    shadowRadius: 12,
    elevation: 10,
  },
});
