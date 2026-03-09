import React, { useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Dimensions, StatusBar, Platform } from 'react-native';
import { useTheme } from '@react-navigation/native';
import Animated, { FadeIn, useAnimatedStyle, withSpring, useSharedValue } from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import TodayTab from '@/components/Screens/Discover/DiscoverTabs/Today';
import RightNowTab from '@/components/Screens/Discover/DiscoverTabs/RightNow';
import NearByTab from '@/components/Screens/Discover/DiscoverTabs/NearBy';

const { width } = Dimensions.get('window');

type TabType = 'today' | 'rightnow' | 'nearby';

export default function NearbyScreen() {
    const { colors, dark } = useTheme();
    const [activeTab, setActiveTab] = useState<TabType>('today');
    const insets = useSafeAreaInsets();
    const indicatorPosition = useSharedValue(0);

    const getTabIndex = (tab: TabType) => {
        if (tab === 'today') return 0;
        if (tab === 'rightnow') return 1;
        return 2;
    };

    const handleTabPress = (tab: TabType) => {
        setActiveTab(tab);
        const index = getTabIndex(tab);
        indicatorPosition.value = withSpring(index * (width / 3), { damping: 20, stiffness: 150 });
    };

    const indicatorStyle = useAnimatedStyle(() => ({
        transform: [{ translateX: indicatorPosition.value + (width / 6) - 20 }],
    }));

    const borderColor = dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.08)';
    const tabColor = dark ? '#FFFFFF' : '#000000';
    const inactiveTabColor = dark ? '#666666' : '#999999';

    return (
        <View style={[styles.container, { backgroundColor: colors.background }]}>
            <StatusBar barStyle={dark ? 'light-content' : 'dark-content'} />
            
            <View style={[styles.header, { borderBottomColor: borderColor, marginTop: 60 + insets.top, borderBottomWidth: 1 }]}>
                <View style={styles.tabSwitcher}>
                    {[
                        { id: 'today', label: 'Bugün' },
                        { id: 'rightnow', label: 'Şimdi' },
                        { id: 'nearby', label: 'Yakınımda' }
                    ].map((tab) => {
                        const isActive = activeTab === tab.id;
                        return (
                            <TouchableOpacity 
                                key={tab.id}
                                onPress={() => handleTabPress(tab.id as TabType)}
                                style={styles.tabButton}
                                activeOpacity={0.7}
                            >
                                <Text style={[
                                    styles.tabText, 
                                    { 
                                        color: isActive ? tabColor : inactiveTabColor, 
                                        fontFamily: isActive ? 'Inter-Bold' : 'Inter-SemiBold',
                                        fontSize: 14,
                                        letterSpacing: isActive ? 0.5 : 0,
                                    }
                                ]}>{tab.label}</Text>
                            </TouchableOpacity>
                        );
                    })}
                    
                    <Animated.View style={[styles.activeIndicator, { backgroundColor: tabColor }, indicatorStyle]} />
                </View>
            </View>

            <View style={{ flex: 1, paddingBottom: Platform.OS === 'ios' ? 88 : 68 }}>
                {activeTab === 'today' && (
                    <Animated.View entering={FadeIn} style={{ flex: 1 }}>
                        <TodayTab />
                    </Animated.View>
                )}
                {activeTab === 'rightnow' && (
                    <Animated.View entering={FadeIn} style={{ flex: 1 }}>
                        <RightNowTab />
                    </Animated.View>
                )}
                {activeTab === 'nearby' && (
                    <Animated.View entering={FadeIn} style={{ flex: 1 }}>
                        <NearByTab />
                    </Animated.View>
                )}
            </View>
        </View>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
    },
    header: {
        width: '100%',
        backgroundColor: 'transparent',
        zIndex: 10,
    },
    tabSwitcher: {
        flexDirection: 'row',
        height: 54,
        position: 'relative',
    },
    tabButton: {
        flex: 1,
        alignItems: 'center',
        justifyContent: 'center',
    },
    tabText: {
        textTransform: 'uppercase',
    },
    activeIndicator: {
        position: 'absolute',
        bottom: 0,
        height: 3,
        width: 40,
        borderRadius: 2,
    },
});
