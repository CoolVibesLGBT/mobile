import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ViewStyle, TextStyle } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useTheme } from '@react-navigation/native';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { useRouter, useSegments, useLocalSearchParams } from 'expo-router';
import { BlurView } from 'expo-blur';
import { Image } from 'expo-image';
import { useAppSelector } from '@/store/hooks';

export default function GlobalHeader() {
    const insets = useSafeAreaInsets();
    const { colors, dark } = useTheme();
    const router = useRouter();
    const segments = useSegments();
    const params = useLocalSearchParams();

    // Read logged-in user from Redux store
    const authUser = useAppSelector(state => state.auth.user);

    const isAuth = (segments as any[])[0] === '(auth)';
    const isChatDetail = (segments as any[]).includes('ChatDetail');
    const isCheckIn = (segments as any[]).includes('CheckIn');
    const isSettings = (segments as any[]).includes('Settings');
    const isActivity = (segments as any[]).includes('Activity');
    const isMatch = (segments as any[]).includes('Match') || (segments as any[]).includes('MatchScreen');

    if (isAuth || isMatch) return null;

    const rootSubSegments = ['index', 'chat', 'Profile', 'Discover', 'nearby', 'Activity'];
    const segs = segments as string[];
    const isRoot = !isChatDetail && !isCheckIn && !isSettings && (
        segs.length === 0 ||
        (segs.length === 1 && segs[0] === '(tabs)') ||
        (segs.length === 2 && segs[0] === '(tabs)' && rootSubSegments.includes(segs[1]))
    );

    // Resolve chat user from route params (populated by ChatDetail on navigate)
    const chatUserName: string   = (params?.name  as string) || (params?.chatId as string) || 'Chat';
    const chatUserStatus: string = (params?.status as string) || 'online';
    const chatUserAvatar: string = (params?.avatar as string) || `https://i.pravatar.cc/150?u=${chatUserName}`;

    const isOverlayHeader = !isSettings;
    const containerStyle: ViewStyle = {
        height: 60 + insets.top,
        paddingTop: insets.top,
        width: '100%',
        zIndex: isOverlayHeader ? 1000 : 1,
        backgroundColor: 'transparent',
        ...(isOverlayHeader
            ? { position: 'absolute', top: 0 }
            : { position: 'relative' }),
    };

    const contentStyle: ViewStyle = {
        flex: 1,
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
        paddingHorizontal: 16,
        borderBottomWidth: 0.5,
        borderBottomColor: dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.08)',
    };

    const brandText: TextStyle = {
        fontSize: 18,
        fontFamily: 'Outfit-Black',
        letterSpacing: 2,
        color: colors.text,
        textTransform: 'uppercase',
    };

    const renderCenter = () => {
        if (isChatDetail) {
            return (
                <View style={styles.chatHeaderCenter}>
                    <Text style={[styles.chatName, { color: colors.text }]} numberOfLines={1}>
                        {chatUserName}
                    </Text>
                    <View style={styles.statusRow}>
                        <View style={[
                            styles.statusDot,
                            { backgroundColor: chatUserStatus === 'online' ? '#34C759' : (dark ? '#555' : '#BBB') }
                        ]} />
                        <Text style={[styles.chatStatus, { color: dark ? '#888' : '#AAA' }]}>
                            {chatUserStatus}
                        </Text>
                    </View>
                </View>
            );
        }
        if (isSettings) {
            return (
                <View style={styles.brandContainer}>
                    <Text style={brandText}>SETTINGS</Text>
                </View>
            );
        }
        if (isActivity) {
            return (
                <View style={styles.brandContainer}>
                    <Text style={brandText}>ACTIVITY</Text>
                </View>
            );
        }
        if (isRoot) {
            const currentTab = segs[segs.length - 1];
            if (currentTab === 'chat') {
                return (
                    <View style={styles.brandContainer}>
                        <Text style={brandText}>MESSAGES</Text>
                    </View>
                );
            }
            if (currentTab === 'nearby') {
                return (
                    <View style={styles.brandContainer}>
                        <Text style={brandText}>NEARBY</Text>
                    </View>
                );
            }
        }
        return (
            <View style={styles.brandContainer}>
                <Text style={brandText}>COOLVIBES</Text>
            </View>
        );
    };

    const renderRight = () => {
        if (isChatDetail) {
            return (
                <TouchableOpacity style={styles.avatarBtn} activeOpacity={0.7}>
                    <Image source={{ uri: chatUserAvatar }} style={styles.headerAvatar} contentFit="cover" />
                </TouchableOpacity>
            );
        }
        if (isSettings) {
            return <View style={styles.avatarBtn} />;
        }
        const avatarUri = authUser?.avatar_url || authUser?.avatarUrl || `https://i.pravatar.cc/150?u=me`;
        return (
            <View style={styles.rightButtons}>
                {!isActivity && (
                    <TouchableOpacity
                        onPress={() => router.push('/(tabs)/Activity')}
                        style={styles.headerBtn}
                        activeOpacity={0.7}
                    >
                        <MaterialCommunityIcons name="bell-outline" size={24} color={colors.text} />
                    </TouchableOpacity>
                )}

                <TouchableOpacity
                    onPress={() => router.push('/(tabs)/Profile')}
                    style={styles.avatarBtn}
                    activeOpacity={0.7}
                >
                    {avatarUri ? (
                        <Image source={{ uri: avatarUri }} style={styles.headerAvatar} contentFit="cover" />
                    ) : (
                        <MaterialCommunityIcons name="account-circle-outline" size={28} color={colors.text} />
                    )}
                </TouchableOpacity>
            </View>
        );
    };

    const borderColor = dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.06)';

    return (
        <View style={[containerStyle, (!isRoot && !isChatDetail && !isCheckIn) && { borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: borderColor }]}>
            <BlurView
                intensity={dark ? 45 : 90}
                style={StyleSheet.absoluteFill}
                tint={dark ? 'dark' : 'light'}
            />
            <View style={contentStyle}>
                {/* Left */}
                <TouchableOpacity
                    onPress={() => {
                        if (isCheckIn || isChatDetail || isSettings) router.back();
                        else if (isRoot) router.push('/Settings');
                        else router.back();
                    }}
                    style={styles.iconBtn}
                    activeOpacity={0.7}
                    hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
                >
                    <MaterialCommunityIcons
                        name={isCheckIn || isSettings ? 'close' : (isRoot ? 'tune-vertical' : 'chevron-left')}
                        size={isCheckIn || isSettings ? 26 : (isRoot ? 22 : 30)}
                        color={colors.text}
                    />
                </TouchableOpacity>

                {/* Center */}
                {renderCenter()}

                {/* Right */}
                {renderRight()}
            </View>
        </View>
    );
}

const styles = StyleSheet.create({
    brandContainer: {
        flex: 1,
        alignItems: 'center',
    },
    chatHeaderCenter: {
        flex: 1,
        alignItems: 'center',
        justifyContent: 'center',
        paddingHorizontal: 8,
    },
    chatName: {
        fontSize: 15,
        fontFamily: 'Outfit-Black',
        textTransform: 'uppercase',
        letterSpacing: 0.5,
    },
    statusRow: {
        flexDirection: 'row',
        alignItems: 'center',
        marginTop: 2,
        gap: 5,
    },
    statusDot: {
        width: 6,
        height: 6,
        borderRadius: 3,
    },
    chatStatus: {
        fontSize: 10,
        fontFamily: 'Inter-SemiBold',
        textTransform: 'capitalize',
    },
    avatarBtn: {
        width: 44,
        height: 44,
        alignItems: 'center',
        justifyContent: 'center',
    },
    headerAvatar: {
        width: 34,
        height: 34,
        borderRadius: 17,
    },
    iconBtn: {
        width: 44,
        height: 44,
        alignItems: 'center',
        justifyContent: 'center',
    },
    rightButtons: {
        flexDirection: 'row',
        alignItems: 'center',
        gap: 4,
    },
    headerBtn: {
        width: 40,
        height: 40,
        alignItems: 'center',
        justifyContent: 'center',
    },
});
