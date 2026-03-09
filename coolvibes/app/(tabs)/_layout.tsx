import React, { useEffect } from 'react';
import { View, TouchableOpacity, Text, StyleSheet, Platform } from 'react-native';
import { Tabs, useRouter } from 'expo-router';
import { useTheme } from '@react-navigation/native';
import { BlurView } from 'expo-blur';
import * as Haptics from 'expo-haptics';
import Animated, { useAnimatedStyle, withTiming, useSharedValue } from 'react-native-reanimated';
import { Flame, Radar, MessageSquare, MapPin, Plus } from 'lucide-react-native';

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

function TabItem({ route, isFocused, navigation, colors }: any) {
  const scale = useSharedValue(isFocused ? 1.2 : 1);

  useEffect(() => {
    scale.value = withTiming(isFocused ? 1.2 : 1, { duration: 250 });
  }, [isFocused]);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  const onPress = () => {
    const event = navigation.emit({
      type: 'tabPress',
      target: route.key,
      canPreventDefault: true,
    });

    if (!isFocused && !event.defaultPrevented) {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
      navigation.navigate(route.name, route.params);
    }
  };

  const Icon = TAB_ICONS[route.name];
  const label = TAB_LABELS[route.name];
  const activeColor = colors.text;
  const inactiveColor = colors.text + '50'; // 30% opacity

  return (
    <TouchableOpacity
      accessibilityRole="button"
      onPress={onPress}
      style={styles.tabItem}
      activeOpacity={0.8}
    >
      <Animated.View style={[styles.iconWrapper, animatedStyle]}>
        <Icon size={25} color={isFocused ? activeColor : inactiveColor} strokeWidth={isFocused ? 2.5 : 2} />
      </Animated.View>
      <Text style={[
        styles.tabLabel, 
        { color: isFocused ? activeColor : inactiveColor },
      ]}>
        {label}
      </Text>
    </TouchableOpacity>
  );
}

function CheckInButton() {
  const router = useRouter();
  const { colors, dark } = useTheme();

  const onPress = () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    router.push('/CheckIn');
  };

  return (
    <View style={styles.checkInButtonWrapper}>
      <TouchableOpacity 
        onPress={onPress} 
        style={[
          styles.checkInButton, 
          { 
            backgroundColor: colors.text,
            borderColor: dark ? '#111' : '#FFF',
          }
        ]} 
        activeOpacity={0.9}
      >
        <Plus size={28} color={dark ? '#000' : '#FFF'} strokeWidth={3.5} />
      </TouchableOpacity>
    </View>
  );
}

function CustomTabBar({ state, descriptors, navigation }: any) {
  const { colors, dark } = useTheme();
  const orderedRoutes = ['index', 'nearby', 'Match', 'chat'];

  const visibleRoutes = state.routes
    .filter((route: any) => orderedRoutes.includes(route.name))
    .sort((a: any, b: any) => orderedRoutes.indexOf(a.name) - orderedRoutes.indexOf(b.name));

  const firstHalf = visibleRoutes.slice(0, 2);
  const secondHalf = visibleRoutes.slice(2);

  const renderTab = (route: any) => {
    const { options } = descriptors[route.key];
    const isFocused = state.index === state.routes.findIndex((r: any) => r.key === route.key);
    return (
      <TabItem
        key={route.key}
        route={route}
        isFocused={isFocused}
        options={options}
        navigation={navigation}
        colors={colors}
      />
    );
  };

  return (
    <View style={[styles.tabBarContainer, { backgroundColor: dark ? 'rgba(0,0,0,0.92)' : 'rgba(255,255,255,0.92)' }]}>
      <BlurView
        intensity={dark ? 40 : 100}
        style={StyleSheet.absoluteFill}
        tint={dark ? 'dark' : 'light'}
      />
      <View style={[styles.tabBarContent, { borderTopColor: dark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.05)' }]}>
        {firstHalf.map(renderTab)}
        <CheckInButton />
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
    height: Platform.OS === 'ios' ? 88 : 68,
    backgroundColor: 'transparent',
    borderTopWidth: 0,
    elevation: 0,
  },
  tabBarContent: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
    borderTopWidth: 0.5,
    paddingBottom: Platform.OS === 'ios' ? 20 : 0,
  },
  tabItem: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    height: '100%',
    paddingTop: 8,
  },
  iconWrapper: {
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 4,
  },
  tabLabel: {
    fontSize: 9,
    fontFamily: 'Inter-Bold',
    letterSpacing: 0.8,
    textTransform: 'uppercase',
  },
  checkInButtonWrapper: {
    width: 68,
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 10,
    height: '100%',
    paddingTop: Platform.OS === 'ios' ? -10 : 0,
  },
  checkInButton: {
    width: 52,
    height: 52,
    borderRadius: 26,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: Platform.OS === 'ios' ? -35 : -30, 
    borderWidth: 4,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.2,
    shadowRadius: 8,
    elevation: 10,
  },
});
