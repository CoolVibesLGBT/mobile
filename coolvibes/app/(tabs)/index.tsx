import React, { useState } from 'react';
import {
    View,
    Text,
    StyleSheet,
    TouchableOpacity,
    Dimensions,
    StatusBar,
    Platform,
} from 'react-native';
import { useTheme } from '@react-navigation/native';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import Animated, { 
    FadeIn, 
    FadeOut, 
    useAnimatedStyle, 
    withSpring,
    useSharedValue,
} from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import DiscoverScreen from './Discover';

const { width } = Dimensions.get('window');

const VibesPlaceholder = () => {
    const { colors, dark } = useTheme();
    return (
        <View style={styles.vibesContainer}>
            <View style={[styles.vibesCard, { backgroundColor: dark ? '#111' : '#F9F9F9' }]}>
                <Image 
                    source={require('../../assets/icons/vibes.webp')} 
                    style={styles.vibesLargeIcon} 
                    contentFit="contain"
                />
                <Text style={[styles.vibesTitle, { color: colors.text }]}>Vibes Mode</Text>
                <Text style={[styles.vibesSubtitle, { color: dark ? '#666' : '#999' }]}>
                    A premium visual experience for discovering the most atmospheric moments in the community.
                </Text>
                <TouchableOpacity style={[styles.vibesButton, { backgroundColor: colors.text }]}>
                    <Text style={[styles.vibesButtonText, { color: colors.background }]}>Enter Vibes</Text>
                </TouchableOpacity>
            </View>
        </View>
    );
};

export default function HomeScreen() {
    const { colors, dark } = useTheme();
    const [activeTab, setActiveTab] = useState<'flows' | 'vibes'>('flows');
    const insets = useSafeAreaInsets();
    const indicatorPosition = useSharedValue(0);

    const handleTabPress = (tab: 'flows' | 'vibes') => {
        setActiveTab(tab);
        indicatorPosition.value = withSpring(tab === 'flows' ? 0 : width / 2, { damping: 20, stiffness: 150 });
    };

    const indicatorStyle = useAnimatedStyle(() => ({
        transform: [{ translateX: indicatorPosition.value + (width / 4) - 20 }],
    }));

    const borderColor = dark ? '#1A1A1A' : '#F0F0F0';
    const tabColor = dark ? '#FFFFFF' : '#000000';
    const inactiveTabColor = dark ? '#666666' : '#999999';

    return (
        <View style={[styles.container, { backgroundColor: colors.background }]}>
            <StatusBar barStyle={dark ? 'light-content' : 'dark-content'} />
            
            {/* Premium Header / Tab Switcher - Now integrated seamlessly below GlobalHeader */}
            <View style={[styles.header, { borderBottomColor: borderColor, marginTop: 60 + insets.top, borderBottomWidth: 1 }]}>
                <View style={styles.tabSwitcher}>
                    <TouchableOpacity 
                        onPress={() => handleTabPress('flows')}
                        style={styles.tabButton}
                        activeOpacity={0.7}
                    >
                        <View style={styles.tabContent}>
                            <Image 
                                source={require('../../assets/icons/flows.webp')} 
                                style={[styles.tabIcon, { opacity: activeTab === 'flows' ? 1 : 0.4 }]} 
                                contentFit="contain"
                            />
                            <Text style={[
                                styles.tabText, 
                                { color: activeTab === 'flows' ? tabColor : inactiveTabColor, fontFamily: activeTab === 'flows' ? 'Inter-Bold' : 'Inter-SemiBold' }
                            ]}>Cool</Text>
                        </View>
                    </TouchableOpacity>

                    <TouchableOpacity 
                        onPress={() => handleTabPress('vibes')}
                        style={styles.tabButton}
                        activeOpacity={0.7}
                    >
                        <View style={styles.tabContent}>
                            <Image 
                                source={require('../../assets/icons/vibes.webp')} 
                                style={[styles.tabIcon, { opacity: activeTab === 'vibes' ? 1 : 0.4 }]} 
                                contentFit="contain"
                            />
                            <Text style={[
                                styles.tabText, 
                                { color: activeTab === 'vibes' ? tabColor : inactiveTabColor, fontFamily: activeTab === 'vibes' ? 'Inter-Bold' : 'Inter-SemiBold' }
                            ]}>Vibes</Text>
                        </View>
                    </TouchableOpacity>
                    
                    {/* Minimalist Indicator */}
                    <Animated.View style={[styles.activeIndicator, { backgroundColor: tabColor }, indicatorStyle]} />
                </View>
            </View>

            {/* Content Area */}
            <View style={{ flex: 1, paddingBottom: Platform.OS === 'ios' ? 88 : 68 }}>
                {activeTab === 'flows' ? (
                    <Animated.View entering={FadeIn} style={{ flex: 1 }}>
                         <DiscoverScreen hideHeader={true} />
                    </Animated.View>
                ) : (
                    <Animated.View entering={FadeIn} style={{ flex: 1 }}>
                        <VibesPlaceholder />
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
        borderBottomWidth: 1,
        zIndex: 10,
    },
    tabSwitcher: {
        flexDirection: 'row',
        height: 64,
        position: 'relative',
    },
    tabButton: {
        flex: 1,
        alignItems: 'center',
        justifyContent: 'center',
    },
    tabContent: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 12,
    },
    tabIcon: {
        width: 32,
        height: 32,
    },
    tabText: {
        fontSize: 16,
        letterSpacing: 0.5,
    },
    activeIndicator: {
        position: 'absolute',
        bottom: 0,
        height: 3,
        width: 40,
        borderRadius: 2,
    },
    vibesContainer: {
        flex: 1,
        alignItems: 'center',
        justifyContent: 'center',
        padding: 24,
    },
    vibesCard: {
        width: '100%',
        padding: 40,
        borderRadius: 32,
        alignItems: 'center',
        justifyContent: 'center',
    },
    vibesLargeIcon: {
        width: 120,
        height: 120,
        marginBottom: 24,
    },
    vibesTitle: {
        fontSize: 28,
        fontFamily: 'Outfit-Black',
        marginBottom: 12,
        textAlign: 'center',
        letterSpacing: -0.5,
    },
    vibesSubtitle: {
        fontSize: 15,
        fontFamily: 'Inter-Regular',
        textAlign: 'center',
        lineHeight: 22,
        opacity: 0.8,
        marginBottom: 32,
    },
    vibesButton: {
        paddingHorizontal: 32,
        paddingVertical: 14,
        borderRadius: 25,
    },
    vibesButtonText: {
        fontSize: 14,
        fontFamily: 'Inter-Bold',
        textTransform: 'uppercase',
        letterSpacing: 1,
    },
});
