import React, { useEffect, useState } from 'react';
import {
    View,
    Text,
    StyleSheet,
    TouchableOpacity,
    Dimensions,
    StatusBar,
    Platform,
    ActivityIndicator,
} from 'react-native';
import { useTheme } from '@react-navigation/native';
import { Image } from 'expo-image';
import { BlurView } from 'expo-blur';
import MaterialCommunityIcons from '@expo/vector-icons/MaterialCommunityIcons';
import Animated, { 
    FadeIn, 
    useAnimatedStyle, 
    withSpring,
    useSharedValue,
} from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useLocalSearchParams, useRouter } from 'expo-router';
import DiscoverScreen from './Discover';
import VibesScreen from '@/components/Vibes/VibesScreen';
import { useAppDispatch, useAppSelector } from '@/store/hooks';
import { clearPostUploadNotice } from '@/store/slice/postUploads';

const { width } = Dimensions.get('window');

export default function HomeScreen() {
    const { colors, dark } = useTheme();
    const [activeTab, setActiveTab] = useState<'flows' | 'vibes'>('flows');
    const insets = useSafeAreaInsets();
    const router = useRouter();
    const dispatch = useAppDispatch();
    const params = useLocalSearchParams<{ refresh_cool?: string }>();
    const postUploadNotice = useAppSelector((state) => state.postUploads.notice);
    const postUploadCompletedVersion = useAppSelector((state) => state.postUploads.completedVersion);
    const refreshToken = Array.isArray(params.refresh_cool) ? params.refresh_cool[0] : params.refresh_cool;
    const effectiveRefreshToken = refreshToken
        ? `${refreshToken}:${postUploadCompletedVersion}`
        : postUploadCompletedVersion > 0
            ? `post:${postUploadCompletedVersion}`
            : undefined;
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

    useEffect(() => {
        if (!postUploadNotice || postUploadNotice.kind === 'uploading') return;
        const timer = setTimeout(() => {
            dispatch(clearPostUploadNotice());
        }, 4200);
        return () => clearTimeout(timer);
    }, [dispatch, postUploadNotice]);

    return (
        <View style={[styles.container, { backgroundColor: colors.background }]}>
            <StatusBar barStyle={dark ? 'light-content' : 'dark-content'} />

            {/* Vibes should render full-screen behind header + tab bar so blur stays "live" while swiping. */}
            {activeTab === 'vibes' ? (
                <View style={StyleSheet.absoluteFillObject} pointerEvents="box-none">
                    <VibesScreen />
                </View>
            ) : null}
            
            {/* Premium Header / Tab Switcher - Now integrated seamlessly below GlobalHeader */}
            <View style={[styles.header, { borderBottomColor: borderColor, marginTop: 60 + insets.top, borderBottomWidth: 1 }]}>
                <BlurView
                    intensity={dark ? 45 : 90}
                    tint={dark ? 'dark' : 'light'}
                    style={StyleSheet.absoluteFill}
                    pointerEvents="none"
                    blurReductionFactor={Platform.OS === 'android' ? 2 : 4}
                    experimentalBlurMethod={Platform.OS === 'android' ? 'dimezisBlurView' : 'none'}
                />
                <View
                    pointerEvents="none"
                    style={[
                        StyleSheet.absoluteFill,
                        { backgroundColor: dark ? 'rgba(0,0,0,0.3)' : 'rgba(255,255,255,0.52)' },
                    ]}
                />
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
            <View
                style={{
                    flex: 1,
                    paddingBottom:
                        activeTab === 'flows' ? (Platform.OS === 'ios' ? 88 : 68) : 0,
                }}
                pointerEvents={activeTab === 'flows' ? 'auto' : 'none'}
            >
                {activeTab === 'flows' ? (
                    <Animated.View entering={FadeIn} style={{ flex: 1 }}>
                         <DiscoverScreen hideHeader={true} refreshToken={effectiveRefreshToken} />
                    </Animated.View>
                ) : null}
            </View>

            {activeTab === 'flows' && (
                <TouchableOpacity
                    style={[styles.fab, { bottom: (Platform.OS === 'ios' ? 84 : 74) + Math.max(insets.bottom, 8) }]}
                    onPress={() => router.push('/CreatePost')}
                    activeOpacity={0.9}
                >
                    <MaterialCommunityIcons name="pencil-plus-outline" size={24} color="#FFFFFF" />
                </TouchableOpacity>
            )}

            {postUploadNotice ? (
                <View
                    pointerEvents="none"
                    style={[
                        styles.uploadNoticeWrap,
                        {
                            bottom: (Platform.OS === 'ios' ? 84 : 74) + Math.max(insets.bottom, 8),
                            right: activeTab === 'flows' ? 92 : 16,
                        },
                    ]}
                >
                    <Animated.View
                        entering={FadeIn.duration(180)}
                        style={[
                            styles.uploadNoticeCard,
                            postUploadNotice.kind === 'error'
                                ? styles.uploadNoticeError
                                : styles.uploadNoticeDefault,
                        ]}
                    >
                        {postUploadNotice.kind === 'uploading' ? (
                            <ActivityIndicator size="small" color="#FFFFFF" />
                        ) : (
                            <MaterialCommunityIcons
                                name={postUploadNotice.kind === 'success' ? 'check-circle-outline' : 'alert-circle-outline'}
                                size={18}
                                color="#FFFFFF"
                            />
                        )}
                        <Text style={styles.uploadNoticeText} numberOfLines={2}>
                            {postUploadNotice.text}
                        </Text>
                    </Animated.View>
                </View>
            ) : null}
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
        overflow: 'hidden',
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
    fab: {
        position: 'absolute',
        right: 20,
        width: 56,
        height: 56,
        borderRadius: 28,
        backgroundColor: '#000000',
        alignItems: 'center',
        justifyContent: 'center',
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 8 },
        shadowOpacity: 0.22,
        shadowRadius: 14,
        elevation: 10,
        zIndex: 20,
    },
    uploadNoticeWrap: {
        position: 'absolute',
        left: 16,
        zIndex: 18,
    },
    uploadNoticeCard: {
        minHeight: 48,
        borderRadius: 18,
        paddingHorizontal: 14,
        paddingVertical: 12,
        flexDirection: 'row',
        alignItems: 'center',
        gap: 10,
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 8 },
        shadowOpacity: 0.14,
        shadowRadius: 16,
        elevation: 8,
    },
    uploadNoticeDefault: {
        backgroundColor: 'rgba(17,24,39,0.96)',
    },
    uploadNoticeError: {
        backgroundColor: 'rgba(127,29,29,0.96)',
    },
    uploadNoticeText: {
        flex: 1,
        color: '#FFFFFF',
        fontSize: 13,
        lineHeight: 18,
        fontFamily: 'Inter-SemiBold',
    },
});
