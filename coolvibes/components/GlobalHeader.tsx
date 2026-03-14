import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ViewStyle, TextStyle } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useTheme } from '@react-navigation/native';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { useRouter, useSegments, useGlobalSearchParams as useSearchParams } from 'expo-router';
import { BlurView } from 'expo-blur';
import { Image } from 'expo-image';
import { useAppSelector } from '@/store/hooks';
import { BottomSheetBackdrop } from '@gorhom/bottom-sheet';
import type { BottomSheetModal } from '@gorhom/bottom-sheet';
import { useCallback, useRef, useState } from 'react';
import { Dimensions } from 'react-native';
import { MessageSquare, MapPin, Calendar, Users, Star, ScrollText } from 'lucide-react-native';
import ProfileBottomSheet from '@/components/ProfileBottomSheet';
import { ScrollView } from 'react-native-gesture-handler';
import { getSafeImageURL, getSafeImageURLEx } from '@/helpers/safeUrl';
import { decodeProfileParam } from '@/helpers/profile';

const { width: SCREEN_WIDTH } = Dimensions.get('window');
const secondaryText = '#888';

export default function GlobalHeader() {
    const insets = useSafeAreaInsets();
    const { colors, dark } = useTheme();
    const router = useRouter();
    const segments = useSegments();
    const params = useSearchParams();

    // Read logged-in user from Redux store
    const authUser = useAppSelector(state => state.auth.user);
    const profileSheetRef = useRef<BottomSheetModal>(null);

    const [isSheetOpen, setIsSheetOpen] = useState(false);

    const handleOpenProfile = useCallback(() => {
        setIsSheetOpen(true);
        profileSheetRef.current?.present();
    }, []);

    const renderBackdrop = useCallback(
        (props: any) => <BottomSheetBackdrop {...props} disappearsOnIndex={-1} appearsOnIndex={0} />,
        []
    );

    const isAuth = (segments as any[])[0] === '(auth)';
    const isChatDetail = (segments as any[]).includes('ChatDetail');
    const isCheckIn = (segments as any[]).includes('CheckIn');
    const isSettings = (segments as any[]).includes('Settings');
    const isActivity = (segments as any[]).includes('Activity');
    const isMatch = (segments as any[]).includes('Match') || (segments as any[]).includes('MatchScreen');
    const isProfileEdit = (segments as any[]).includes('ProfileEdit');

    if (isAuth || isMatch || isProfileEdit) return null;

    const rootSubSegments = ['index', 'chat', 'Profile', 'Discover', 'nearby', 'Activity'];
    const segs = segments as string[];
    const isRoot = !isChatDetail && !isCheckIn && !isSettings && (
        segs.length === 0 ||
        (segs.length === 1 && segs[0] === '(tabs)') ||
        (segs.length === 2 && segs[0] === '(tabs)' && rootSubSegments.some(s => s.toLowerCase() === segs[1].toLowerCase()))
    );

    // Resolve chat user from route params
    const chatUserNameRaw = (params?.name as string) || (params?.chatId as string) || 'Chat';
    const chatUserName = chatUserNameRaw === 'Chat' ? 'Chat' : chatUserNameRaw;
    const chatUserStatus: string = (params?.status as string) || 'online';
    const chatUserAvatar: string = (params?.avatar as string) || `https://i.pravatar.cc/150?u=${chatUserName}`;
    const isTyping = String(params?.typing ?? '') === '1' || String(params?.typing ?? '') === 'true';
    const chatSubText = isTyping ? 'typing...' : chatUserStatus;
    const chatProfileParam = params?.profile as string | undefined;
    const chatProfilePayload = decodeProfileParam(chatProfileParam);

    const isOverlayHeader = !isSettings;
    const containerStyle: ViewStyle = {
        height: 60 + insets.top,
        paddingTop: insets.top,
        width: '100%',
        zIndex: isSheetOpen ? 1 : (isOverlayHeader ? 100 : 1),
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
        fontFamily: 'Outfit-Bold',
        letterSpacing: 2,
        color: colors.text,
        textTransform: 'uppercase',
    };

    const renderCenter = () => {
        if (isChatDetail) {
            return (
                <TouchableOpacity 
                    style={[styles.chatHeaderCenter, { paddingHorizontal: 0 }]}
                    activeOpacity={0.7}
                    onPress={handleOpenProfile}
                >
                    <View style={{ alignItems: 'center' }}>
                        <Text style={[brandText, { textAlign: 'center' }]} numberOfLines={1}>
                            {chatUserName}
                        </Text>
                        {!!chatSubText && (
                            <View style={styles.statusRow}>
                                {!isTyping && (
                                    <View style={[styles.statusDot, { backgroundColor: '#34C759' }]} />
                                )}
                                <Text style={[styles.chatStatus, { color: colors.text, opacity: 0.7 }]}>
                                    {chatSubText}
                                </Text>
                            </View>
                        )}
                    </View>
                </TouchableOpacity>
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
            const currentTab = segs[segs.length - 1] ?? '';
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
            if (currentTab === 'CheckIn') {
                return (
                    <View style={styles.brandContainer}>
                        <Text style={brandText}>CHECK-IN</Text>
                    </View>
                );
            }
            if (currentTab && currentTab.toLowerCase() === 'profile') {
                return (
                    <View style={styles.brandContainer}>
                        <Text style={brandText}>PROFILE</Text>
                    </View>
                );
            }
        }
        if (isCheckIn) {
            return (
                <View style={styles.brandContainer}>
                    <Text style={brandText}>CHECK-IN</Text>
                </View>
            );
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
                <View style={styles.rightButtons}>
                    <TouchableOpacity 
                        style={styles.avatarBtn} 
                        activeOpacity={0.7} 
                        onPress={handleOpenProfile}
                    >
                        <Image source={{ uri: chatUserAvatar }} style={styles.headerAvatar} contentFit="cover" />
                    </TouchableOpacity>
                </View>
            );
        }
        if (isSettings) {
            return <View style={styles.avatarBtn} />;
        }
        const avatarUri = getSafeImageURLEx(authUser?.id, authUser?.avatar, 'medium') || getSafeImageURLEx(authUser?.id, authUser?.avatar_url || authUser?.avatarUrl, 'medium');
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
                    onPress={() => router.navigate('/(tabs)/Profile')}
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
                        if (isCheckIn && params?.checkin_mode === 'create') {
                            router.setParams({ checkin_mode: undefined });
                        } else if (isCheckIn || isChatDetail || isSettings) {
                            router.back();
                        }
                        else if (isRoot) router.push('/Settings');
                        else router.back();
                    }}
                    style={styles.iconBtn}
                    activeOpacity={0.7}
                    hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
                >
                    <MaterialCommunityIcons
                        name={isCheckIn ? 'chevron-left' : (isSettings ? 'close' : (isRoot ? 'tune-vertical' : 'chevron-left'))}
                        size={isCheckIn ? 30 : (isSettings ? 26 : (isRoot ? 22 : 30))}
                        color={colors.text}
                    />
                </TouchableOpacity>

                {/* Center */}
                {renderCenter()}

                {/* Right */}
                {renderRight()}
            </View>

            {/* Profile Preview Sheet */}
            <ProfileBottomSheet
                ref={profileSheetRef}
                backdropComponent={renderBackdrop}
                onDismiss={() => setIsSheetOpen(false)}
                user={chatProfilePayload}
                fallback={{
                    id: String(params?.userId ?? params?.publicId ?? params?.chatId ?? ''),
                    name: chatUserName,
                    username: (params?.username as string) || undefined,
                    avatar: chatUserAvatar,
                }}
                isMe={false}
                onMessage={() => profileSheetRef.current?.dismiss()}
            />
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
        fontFamily: 'Outfit-Bold',
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
    sheetBannerContainer: {
        height: 180,
    },
    sheetBanner: {
        width: '100%',
        height: '100%',
        backgroundColor: '#222',
    },
    sheetProfileSection: {
        marginTop: -40,
        paddingHorizontal: 20,
    },
    sheetAvatarContainer: {
        width: 100,
        height: 100,
        borderRadius: 50,
        borderWidth: 4,
        overflow: 'hidden',
        backgroundColor: '#111',
    },
    sheetLargeAvatar: {
        width: '100%',
        height: '100%',
    },
    sheetHeaderDetails: {
        marginTop: 12,
        paddingBottom: 24,
    },
    sheetNameMain: {
        fontSize: 32,
        fontFamily: 'Outfit-Black',
        letterSpacing: -1,
        textTransform: 'uppercase',
    },
    sheetUsernameMain: {
        fontSize: 15,
        fontFamily: 'Inter-SemiBold',
        opacity: 0.5,
        marginTop: -2,
    },
    sheetBioMain: {
        marginTop: 16,
        fontSize: 15,
        lineHeight: 22,
        fontFamily: 'Inter-Regular',
        opacity: 0.8,
    },
    sheetMetaRow: {
        flexDirection: 'row',
        alignItems: 'center',
        marginTop: 16,
    },
    sheetMetaItem: {
        flexDirection: 'row',
        alignItems: 'center',
        gap: 6,
    },
    sheetMetaInfo: {
        fontSize: 13,
        fontFamily: 'Inter-SemiBold',
        opacity: 0.5,
    },
    sheetStatsContainer: {
        flexDirection: 'row',
        marginTop: 20,
    },
    sheetStatUnit: {
        flexDirection: 'row',
        alignItems: 'center',
        gap: 8,
    },
    sheetStatNum: {
        fontFamily: 'Inter-Bold',
        fontSize: 16,
    },
    sheetStatLab: {
        fontSize: 14,
        fontFamily: 'Inter-SemiBold',
        opacity: 0.5,
        textTransform: 'lowercase',
    },
    sheetDivider: {
        height: 1,
        backgroundColor: 'rgba(128,128,128,0.1)',
        marginVertical: 10,
    },
});
