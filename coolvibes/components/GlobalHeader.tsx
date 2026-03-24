import React, { useCallback, useRef, useState, useMemo, useEffect } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ViewStyle, TextStyle, Platform, Modal, Pressable, Animated, Easing, ScrollView } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useTheme } from '@react-navigation/native';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { useRouter, useSegments, useGlobalSearchParams as useSearchParams } from 'expo-router';
import { BlurView } from 'expo-blur';
import { Image } from 'expo-image';
import { useAppSelector } from '@/store/hooks';
import { BottomSheetBackdrop } from '@gorhom/bottom-sheet';
import type { BottomSheetModal } from '@gorhom/bottom-sheet';
import BaseBottomSheetModal from '@/components/BaseBottomSheetModal';
import FullProfileView from '@/components/FullProfileView';
import { getLegalPage } from '@/helpers/legal';
import { getSafeImageURLEx } from '@/helpers/safeUrl';
import { decodeProfileParam, normalizeProfileUser } from '@/helpers/profile';
import { api } from '@/services/apiService';

export default function GlobalHeader() {
    const insets = useSafeAreaInsets();
    const { colors, dark } = useTheme();
    const router = useRouter();
    const segments = useSegments();
    const params = useSearchParams();

    // Read logged-in user from Redux store
    const authUser = useAppSelector(state => state.auth.user);
    const backgroundTasks = useAppSelector(state => state.postUploads.tasks);
    const profileSheetRef = useRef<BottomSheetModal>(null);
    const [fetchedUser, setFetchedUser] = useState<any | null>(null);
    const lastFetchKeyRef = useRef<string | null>(null);

    const [isSheetOpen, setIsSheetOpen] = useState(false);
    const [isSidebarOpen, setIsSidebarOpen] = useState(false);
    const sidebarTranslateX = useRef(new Animated.Value(-304)).current;

    const handleOpenProfile = useCallback(() => {
        setIsSheetOpen(true);
        profileSheetRef.current?.present();
    }, []);

    const handleOpenMenu = useCallback(() => {
        setIsSidebarOpen(true);
        Animated.timing(sidebarTranslateX, {
            toValue: 0,
            duration: 240,
            easing: Easing.out(Easing.cubic),
            useNativeDriver: true,
        }).start();
    }, [sidebarTranslateX]);

    const handleCloseMenu = useCallback((onClosed?: () => void) => {
        Animated.timing(sidebarTranslateX, {
            toValue: -304,
            duration: 220,
            easing: Easing.in(Easing.cubic),
            useNativeDriver: true,
        }).start(({ finished }) => {
            if (finished) {
                setIsSidebarOpen(false);
                onClosed?.();
            }
        });
    }, [sidebarTranslateX]);

    const renderBackdrop = useCallback(
        (props: any) => <BottomSheetBackdrop {...props} disappearsOnIndex={-1} appearsOnIndex={0} />,
        []
    );

    const isAuth = (segments as any[])[0] === '(auth)';
    const isChatDetail = (segments as any[]).includes('ChatDetail');
    const isCheckIn = (segments as any[]).includes('CheckIn');
    const isCheckInCreate = (segments as any[]).includes('CheckInCreate');
    const isSettings = (segments as any[]).includes('Settings');
    const isActivity = (segments as any[]).includes('Activity');
    const isMatch = (segments as any[]).includes('Match') || (segments as any[]).includes('MatchScreen');
    const isPendingTasks = (segments as any[]).includes('PendingTasks');
    const isClassifiedsRoot = (segments as any[]).includes('Classifieds');
    const isClassifiedDetail = (segments as any[]).includes('ClassifiedDetail');
    const isClassifiedCreate = (segments as any[]).includes('ClassifiedCreate');
    const isClassifiedsRoute = isClassifiedsRoot || isClassifiedDetail || isClassifiedCreate;
    const isPlacesRoot = (segments as any[]).includes('Places') || (segments as any[]).includes('places');
    const isPlaceDetail = (segments as any[]).includes('PlaceDetail') || (segments as any[]).includes('place-detail');
    const isPlacesRoute = isPlacesRoot || isPlaceDetail;
    const isProfileEdit = (segments as any[]).includes('ProfileEdit');
    const isCreatePost = (segments as any[]).includes('CreatePost');
    const isProfileMetricDetail = (segments as any[]).includes('ProfileMetricDetail');
    const shouldHide = isAuth || isMatch;

    const rootSubSegments = ['index', 'chat', 'Profile', 'Discover', 'nearby', 'Activity'];
    const segs = segments as string[];
    const isLegalIndex = segs[0] === 'legal' && segs.length === 1;
    const isLegalDetail = segs[0] === 'legal' && segs.includes('[page]');
    const isLegalRoute = isLegalIndex || isLegalDetail;
    const currentTab = segs[segs.length - 1] ?? '';
    const isProfileRoute = currentTab.toLowerCase() === 'profile';
    const isCheckInRoute = isCheckIn || isCheckInCreate;
    const isRoot = !isChatDetail && !isCheckInRoute && !isSettings && !isPendingTasks && !isClassifiedsRoute && !isPlacesRoute && !isLegalRoute && !isProfileEdit && !isCreatePost && !isProfileMetricDetail && (
        segs.length === 0 ||
        (segs.length === 1 && segs[0] === '(tabs)') ||
        (segs.length === 2 && segs[0] === '(tabs)' && rootSubSegments.some(s => s.toLowerCase() === segs[1].toLowerCase()))
    );
    const settingsReturnToParam = Array.isArray(params?.returnTo) ? params.returnTo[0] : params?.returnTo;
    const settingsReturnTo =
        typeof settingsReturnToParam === 'string' && settingsReturnToParam.startsWith('/')
            ? settingsReturnToParam
            : null;
    const legalPageParam = Array.isArray(params?.page) ? params.page[0] : params?.page;
    const currentLegalPage = getLegalPage(typeof legalPageParam === 'string' ? legalPageParam : null);
    const rootRoutePath = useMemo(() => {
        if (segs[0] !== '(tabs)') return '/(tabs)';
        if (!segs[1] || segs[1] === 'index') return '/(tabs)';
        return `/(tabs)/${segs[1]}`;
    }, [segs]);
    const sortedBackgroundTasks = useMemo(
        () => [...backgroundTasks].sort((a, b) => b.updatedAt - a.updatedAt),
        [backgroundTasks]
    );
    const pendingTaskCount = sortedBackgroundTasks.filter((task) => task.status === 'uploading').length;
    const recentTaskCount = sortedBackgroundTasks.filter((task) => task.status !== 'uploading').length;
    const sidebarAvatarUri = getSafeImageURLEx(authUser?.id ?? authUser?.public_id, authUser?.avatar, 'medium')
        || getSafeImageURLEx(authUser?.id ?? authUser?.public_id, authUser?.avatar_url || authUser?.avatarUrl, 'medium');
    const sidebarDisplayName = authUser?.displayname || authUser?.name || authUser?.username || 'CoolVibes';
    const sidebarHandle = authUser?.username ? `@${authUser.username}` : 'Open your spaces faster';
    const sidebarTaskLabel = pendingTaskCount > 0
        ? `${pendingTaskCount} active task${pendingTaskCount === 1 ? '' : 's'}`
        : recentTaskCount > 0
            ? `${recentTaskCount} recent task${recentTaskCount === 1 ? '' : 's'}`
            : 'No background tasks';
    const sidebarCardBackground = dark ? 'rgba(255,255,255,0.05)' : '#FFFFFF';
    const sidebarMutedText = dark ? 'rgba(255,255,255,0.58)' : 'rgba(17,24,39,0.58)';
    const sidebarIconBackground = dark ? 'rgba(255,255,255,0.08)' : 'rgba(17,24,39,0.06)';
    const sidebarPillBackground = dark ? 'rgba(255,255,255,0.08)' : 'rgba(15,23,42,0.06)';
    // Resolve chat user from route params
    const chatUserNameRaw = (params?.name as string) || (params?.chatId as string) || 'Chat';
    const chatUserName = chatUserNameRaw === 'Chat' ? 'Chat' : chatUserNameRaw;
    const chatUserStatus: string = (params?.status as string) || 'online';
    const chatUserAvatar: string = (params?.avatar as string) || `https://i.pravatar.cc/150?u=${chatUserName}`;
    const isTyping = String(params?.typing ?? '') === '1' || String(params?.typing ?? '') === 'true';
    const chatSubText = isTyping ? 'typing...' : chatUserStatus;
    const chatProfileParam = params?.profile as string | undefined;
    const chatProfilePayload = decodeProfileParam(chatProfileParam);

    const profileFallback = useMemo(() => ({
        id: String(params?.userId ?? params?.publicId ?? params?.chatId ?? ''),
        name: chatUserName,
        username: (params?.username as string) || undefined,
        avatar: chatUserAvatar,
    }), [params?.userId, params?.publicId, params?.chatId, params?.username, chatUserName, chatUserAvatar]);

    const normalizeName = (value?: string) => (typeof value === 'string' ? value.trim() : '');
    const isGenericName = (value: string) => {
        const lower = value.toLowerCase();
        return lower === 'chat' || lower === 'user' || lower === 'unknown' || lower === 'me';
    };
    const isValidUsername = (value?: string) => {
        const name = normalizeName(value);
        if (!name) return false;
        if (isGenericName(name)) return false;
        if (/\s/.test(name)) return false;
        return true;
    };
    const isValidNickname = (value?: string) => {
        const name = normalizeName(value);
        if (!name) return false;
        if (isGenericName(name)) return false;
        return true;
    };

    const fetchUsername = isValidUsername(chatProfilePayload?.username || chatProfilePayload?.raw?.username || profileFallback?.username)
        ? normalizeName(chatProfilePayload?.username || chatProfilePayload?.raw?.username || profileFallback?.username)
        : null;

    const fetchNickname = !fetchUsername && isValidNickname(chatProfilePayload?.nickname || chatProfilePayload?.raw?.nickname)
        ? normalizeName(chatProfilePayload?.nickname || chatProfilePayload?.raw?.nickname)
        : null;

    const identityKey =
        chatProfilePayload?.id ||
        chatProfilePayload?.public_id ||
        chatProfilePayload?.username ||
        chatProfilePayload?.raw?.id ||
        chatProfilePayload?.raw?.public_id ||
        chatProfilePayload?.raw?.username ||
        profileFallback?.id ||
        profileFallback?.username ||
        null;

    useEffect(() => {
        if (shouldHide) {
            setFetchedUser(null);
            lastFetchKeyRef.current = null;
            return;
        }
        setFetchedUser(null);
        lastFetchKeyRef.current = null;
    }, [identityKey, shouldHide]);

    useEffect(() => {
        if (shouldHide) return;
        const fetchKey = fetchUsername || fetchNickname;
        if (!fetchKey || lastFetchKeyRef.current === fetchKey) return;
        lastFetchKeyRef.current = fetchKey;
        let isActive = true;
        const run = async () => {
            try {
                const response = fetchUsername
                    ? await api.fetchProfile(fetchUsername)
                    : await api.fetchProfileByNickname(fetchNickname as string);
                const payload = (response as any)?.data ?? response;
                const profile =
                    payload?.user ||
                    payload?.data?.user ||
                    payload?.profile ||
                    payload?.data?.profile ||
                    payload?.data ||
                    payload;
                if (isActive && profile) setFetchedUser(profile);
            } catch {
                // ignore fetch errors
            }
        };
        run();
        return () => {
            isActive = false;
        };
    }, [fetchUsername, fetchNickname, shouldHide]);

    const profileUser = useMemo(
        () => normalizeProfileUser(fetchedUser ?? chatProfilePayload, profileFallback),
        [fetchedUser, chatProfilePayload, profileFallback]
    );

    const isOverlayHeader = !isSettings && !isPendingTasks && !isClassifiedsRoute && !isPlacesRoute && !isLegalRoute && !isProfileRoute && !isProfileEdit && !isCreatePost && !isProfileMetricDetail;
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
        if (isPendingTasks) {
            return (
                <View style={styles.brandContainer}>
                    <Text style={brandText}>PENDING TASKS</Text>
                </View>
            );
        }
        if (isClassifiedsRoot || isClassifiedDetail) {
            return (
                <View style={styles.brandContainer}>
                    <Text style={brandText}>CLASSIFIEDS</Text>
                </View>
            );
        }
        if (isClassifiedCreate) {
            return (
                <View style={styles.brandContainer}>
                    <Text style={brandText}>NEW LISTING</Text>
                </View>
            );
        }
        if (isPlacesRoute) {
            return (
                <View style={styles.brandContainer}>
                    <Text style={brandText}>PLACES</Text>
                </View>
            );
        }
        if (isLegalRoute) {
            return (
                <View style={styles.brandContainer}>
                    <Text style={brandText} numberOfLines={1}>
                        {(currentLegalPage?.title ?? 'Legal & Privacy').toUpperCase()}
                    </Text>
                </View>
            );
        }
        if (isProfileEdit) {
            return (
                <View style={styles.brandContainer}>
                    <Text style={brandText}>EDIT PROFILE</Text>
                </View>
            );
        }
        if (isCreatePost) {
            return (
                <View style={styles.brandContainer}>
                    <Text style={brandText}>CREATE POST</Text>
                </View>
            );
        }
        if (isProfileMetricDetail) {
            const metricTitleRaw = (params?.metricLabel as string) || 'Engagement';
            return (
                <View style={styles.brandContainer}>
                    <Text style={brandText} numberOfLines={1}>
                        {metricTitleRaw.toUpperCase()}
                    </Text>
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
        if (isCheckInRoute) {
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
        if (isPendingTasks) {
            return <View style={styles.avatarBtn} />;
        }
        if (isClassifiedsRoot) {
            return (
                <View style={styles.rightButtons}>
                    <TouchableOpacity
                        onPress={() => router.push('/ClassifiedCreate')}
                        style={styles.headerBtn}
                        activeOpacity={0.7}
                    >
                        <MaterialCommunityIcons name="plus" size={24} color={colors.text} />
                    </TouchableOpacity>
                </View>
            );
        }
        if (isClassifiedDetail || isClassifiedCreate) {
            return <View style={styles.avatarBtn} />;
        }
        if (isPlacesRoute) {
            return <View style={styles.avatarBtn} />;
        }
        if (isLegalRoute) {
            return <View style={styles.avatarBtn} />;
        }
        if (isProfileEdit) {
            return <View style={styles.avatarBtn} />;
        }
        if (isCreatePost) {
            return <View style={styles.avatarBtn} />;
        }
        if (isProfileMetricDetail) {
            return <View style={styles.avatarBtn} />;
        }
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
                    {sidebarAvatarUri ? (
                        <Image source={{ uri: sidebarAvatarUri }} style={styles.headerAvatar} contentFit="cover" />
                    ) : (
                        <MaterialCommunityIcons name="account-circle-outline" size={28} color={colors.text} />
                    )}
                </TouchableOpacity>
            </View>
        );
    };

    const handleSettingsPress = useCallback(() => {
        router.push({
            pathname: '/Settings',
            params: { returnTo: isRoot ? rootRoutePath : '/(tabs)' },
        });
    }, [isRoot, rootRoutePath, router]);

    const handleSidebarNavigate = useCallback((pathname: string) => {
        handleCloseMenu(() => {
            router.navigate(pathname as any);
        });
    }, [handleCloseMenu, router]);

    const renderLeft = () => {
        if (isRoot) {
            return (
                <View style={styles.leftButtons}>
                    <TouchableOpacity
                        onPress={handleOpenMenu}
                        style={styles.iconBtn}
                        activeOpacity={0.7}
                        hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
                    >
                        <MaterialCommunityIcons name="menu" size={28} color={colors.text} />
                    </TouchableOpacity>
                    <TouchableOpacity
                        onPress={handleSettingsPress}
                        style={styles.iconBtn}
                        activeOpacity={0.7}
                        hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
                    >
                        <MaterialCommunityIcons name="tune-vertical" size={22} color={colors.text} />
                    </TouchableOpacity>
                </View>
            );
        }

        return (
            <TouchableOpacity
                onPress={handleLeftPress}
                style={styles.iconBtn}
                activeOpacity={0.7}
                hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
            >
                <MaterialCommunityIcons
                    name="chevron-left"
                    size={isCheckInRoute ? 30 : (isSettings ? 30 : 30)}
                    color={colors.text}
                />
            </TouchableOpacity>
        );
    };

    const borderColor = dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.06)';
    const handleLeftPress = useCallback(() => {
        if (isCheckIn && params?.checkin_mode === 'create') {
            router.setParams({ checkin_mode: undefined });
            return;
        }

        if (isSettings) {
            if (settingsReturnTo) {
                router.navigate(settingsReturnTo as any);
                return;
            }
            if (router.canGoBack()) {
                router.back();
                return;
            }
            router.replace('/(tabs)');
            return;
        }

        if (isPendingTasks || isClassifiedsRoute || isPlacesRoute || isLegalRoute || isCheckInRoute || isChatDetail) {
            if (router.canGoBack()) {
                router.back();
            } else {
                if (isPendingTasks) {
                    router.replace('/(tabs)');
                } else if (isPlacesRoute) {
                    router.replace('/places');
                } else if (isLegalRoute) {
                    router.replace('/legal');
                } else {
                    router.replace(isClassifiedDetail || isClassifiedCreate ? '/Classifieds' : '/(tabs)');
                }
            }
            return;
        }

        if (router.canGoBack()) {
            router.back();
            return;
        }

        router.replace('/(tabs)');
    }, [isCheckIn, params?.checkin_mode, isSettings, settingsReturnTo, router, isChatDetail, isCheckInRoute, isClassifiedCreate, isClassifiedDetail, isClassifiedsRoute, isPendingTasks, isPlacesRoute, isLegalRoute]);

    if (shouldHide) return null;

    return (
        <View style={[containerStyle, (!isRoot && !isChatDetail && !isCheckInRoute) && { borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: borderColor }]}>
            <BlurView
                intensity={dark ? 45 : 90}
                style={StyleSheet.absoluteFill}
                tint={dark ? 'dark' : 'light'}
                blurReductionFactor={Platform.OS === 'android' ? 2 : 4}
                experimentalBlurMethod={Platform.OS === 'android' ? 'dimezisBlurView' : 'none'}
            />
            <View style={contentStyle}>
                {/* Left */}
                {renderLeft()}

                {/* Center */}
                {renderCenter()}

                {/* Right */}
                {renderRight()}
            </View>

            <Modal
                visible={isSidebarOpen}
                transparent
                animationType="none"
                statusBarTranslucent
                onRequestClose={() => handleCloseMenu()}
            >
                <View style={styles.sidebarRoot}>
                    <Pressable style={styles.sidebarBackdrop} onPress={() => handleCloseMenu()} />
                    <Animated.View
                        style={[
                            styles.sidebarPanel,
                            {
                                paddingTop: insets.top + 18,
                                backgroundColor: dark ? '#0B0B0B' : '#FFFFFF',
                                borderRightColor: borderColor,
                                transform: [{ translateX: sidebarTranslateX }],
                            },
                        ]}
                    >
                        <View style={styles.sidebarHeader}>
                            <Text style={[styles.sidebarTitle, { color: colors.text }]}>Menu</Text>
                            <TouchableOpacity
                                onPress={() => handleCloseMenu()}
                                style={[styles.sidebarCloseBtn, { backgroundColor: sidebarIconBackground }]}
                                activeOpacity={0.8}
                            >
                                <MaterialCommunityIcons name="close" size={22} color={colors.text} />
                            </TouchableOpacity>
                        </View>

                        <ScrollView
                            style={styles.sidebarScroll}
                            contentContainerStyle={styles.sidebarContent}
                            showsVerticalScrollIndicator={false}
                        >
                            <TouchableOpacity
                                style={[styles.sidebarHeroCard, { backgroundColor: sidebarCardBackground, borderColor }]}
                                activeOpacity={0.86}
                                onPress={() => handleSidebarNavigate('/(tabs)/Profile')}
                            >
                                <View style={[styles.sidebarHeroAvatarWrap, { backgroundColor: sidebarIconBackground, borderColor }]}>
                                    {sidebarAvatarUri ? (
                                        <Image source={{ uri: sidebarAvatarUri }} style={styles.sidebarHeroAvatar} contentFit="cover" />
                                    ) : (
                                        <MaterialCommunityIcons name="account-circle-outline" size={34} color={colors.text} />
                                    )}
                                </View>
                                <View style={styles.sidebarHeroBody}>
                                    <Text style={[styles.sidebarHeroTitle, { color: colors.text }]} numberOfLines={1}>
                                        {sidebarDisplayName}
                                    </Text>
                                    <Text style={[styles.sidebarHeroSubtitle, { color: sidebarMutedText }]} numberOfLines={1}>
                                        {sidebarHandle}
                                    </Text>
                                    <View style={styles.sidebarHeroMetaRow}>
                                        <View style={[styles.sidebarPill, { backgroundColor: sidebarPillBackground }]}>
                                            <Text style={[styles.sidebarPillText, { color: colors.text }]}>
                                                {sidebarTaskLabel}
                                            </Text>
                                        </View>
                                        <View style={[styles.sidebarPill, { backgroundColor: sidebarPillBackground }]}>
                                            <Text style={[styles.sidebarPillText, { color: colors.text }]}>
                                                Quick access
                                            </Text>
                                        </View>
                                    </View>
                                </View>
                                <View style={[styles.menuItemChevronWrap, { backgroundColor: sidebarIconBackground }]}>
                                    <MaterialCommunityIcons name="chevron-right" size={18} color={colors.text} />
                                </View>
                            </TouchableOpacity>

                            <View style={styles.sidebarSection}>
                                <Text style={[styles.sidebarSectionLabel, { color: sidebarMutedText }]}>Workspace</Text>

                                <TouchableOpacity
                                    style={[
                                        styles.menuItem,
                                        {
                                            borderColor,
                                            backgroundColor: isPendingTasks ? sidebarCardBackground : 'transparent',
                                        },
                                    ]}
                                    activeOpacity={0.82}
                                    onPress={() => handleSidebarNavigate('/PendingTasks')}
                                >
                                    <View style={[styles.menuItemIcon, { backgroundColor: sidebarIconBackground }]}>
                                        <MaterialCommunityIcons name="clipboard-text-clock-outline" size={20} color={colors.text} />
                                    </View>
                                    <View style={styles.menuItemBody}>
                                        <Text style={[styles.menuItemTitle, { color: colors.text }]}>Pending Tasks</Text>
                                        <Text style={[styles.menuItemSubtitle, { color: sidebarMutedText }]}>
                                            {sidebarTaskLabel}
                                        </Text>
                                    </View>
                                    {pendingTaskCount > 0 ? (
                                        <View style={[styles.menuItemBadge, { backgroundColor: colors.text }]}>
                                            <Text style={[styles.menuItemBadgeText, { color: dark ? '#0B0B0B' : '#FFFFFF' }]}>
                                                {pendingTaskCount}
                                            </Text>
                                        </View>
                                    ) : null}
                                    <View style={[styles.menuItemChevronWrap, { backgroundColor: sidebarIconBackground }]}>
                                        <MaterialCommunityIcons name="chevron-right" size={18} color={colors.text} />
                                    </View>
                                </TouchableOpacity>

                                <TouchableOpacity
                                    style={[
                                        styles.menuItem,
                                        {
                                            borderColor,
                                            backgroundColor: isClassifiedsRoute ? sidebarCardBackground : 'transparent',
                                        },
                                    ]}
                                    activeOpacity={0.82}
                                    onPress={() => handleSidebarNavigate('/Classifieds')}
                                >
                                    <View style={[styles.menuItemIcon, { backgroundColor: sidebarIconBackground }]}>
                                        <MaterialCommunityIcons name="briefcase-outline" size={20} color={colors.text} />
                                    </View>
                                    <View style={styles.menuItemBody}>
                                        <Text style={[styles.menuItemTitle, { color: colors.text }]}>Classifieds</Text>
                                        <Text style={[styles.menuItemSubtitle, { color: sidebarMutedText }]}>
                                            Offers, listings and community needs
                                        </Text>
                                    </View>
                                    <View style={[styles.menuItemChevronWrap, { backgroundColor: sidebarIconBackground }]}>
                                        <MaterialCommunityIcons name="chevron-right" size={18} color={colors.text} />
                                    </View>
                                </TouchableOpacity>

                                <TouchableOpacity
                                    style={[
                                        styles.menuItem,
                                        {
                                            borderColor,
                                            backgroundColor: isPlacesRoute ? sidebarCardBackground : 'transparent',
                                        },
                                    ]}
                                    activeOpacity={0.82}
                                    onPress={() => handleSidebarNavigate('/places')}
                                >
                                    <View style={[styles.menuItemIcon, { backgroundColor: sidebarIconBackground }]}>
                                        <MaterialCommunityIcons name="map-marker-outline" size={20} color={colors.text} />
                                    </View>
                                    <View style={styles.menuItemBody}>
                                        <Text style={[styles.menuItemTitle, { color: colors.text }]}>Places</Text>
                                        <Text style={[styles.menuItemSubtitle, { color: sidebarMutedText }]}>
                                            LGBTQ+ friendly venues nearby
                                        </Text>
                                    </View>
                                    <View style={[styles.menuItemChevronWrap, { backgroundColor: sidebarIconBackground }]}>
                                        <MaterialCommunityIcons name="chevron-right" size={18} color={colors.text} />
                                    </View>
                                </TouchableOpacity>

                                <TouchableOpacity
                                    style={[
                                        styles.menuItem,
                                        {
                                            borderColor,
                                            backgroundColor: isLegalRoute ? sidebarCardBackground : 'transparent',
                                        },
                                    ]}
                                    activeOpacity={0.82}
                                    onPress={() => handleSidebarNavigate('/legal')}
                                >
                                    <View style={[styles.menuItemIcon, { backgroundColor: sidebarIconBackground }]}>
                                        <MaterialCommunityIcons name="shield-outline" size={20} color={colors.text} />
                                    </View>
                                    <View style={styles.menuItemBody}>
                                        <Text style={[styles.menuItemTitle, { color: colors.text }]}>Legal</Text>
                                        <Text style={[styles.menuItemSubtitle, { color: sidebarMutedText }]}>
                                            Privacy, terms and guidelines
                                        </Text>
                                    </View>
                                    <View style={[styles.menuItemChevronWrap, { backgroundColor: sidebarIconBackground }]}>
                                        <MaterialCommunityIcons name="chevron-right" size={18} color={colors.text} />
                                    </View>
                                </TouchableOpacity>
                            </View>

                            <View style={[styles.sidebarFooterCard, { backgroundColor: sidebarCardBackground, borderColor }]}>
                                <Text style={[styles.sidebarFooterTitle, { color: colors.text }]}>CoolVibes</Text>
                                <Text style={[styles.sidebarFooterText, { color: sidebarMutedText }]}>
                                    Quick access to community tools, discovery and policy screens.
                                </Text>
                            </View>
                        </ScrollView>
                    </Animated.View>
                </View>
            </Modal>

            {/* Profile Preview Sheet */}
            <BaseBottomSheetModal
                ref={profileSheetRef}
                index={0}
                snapPoints={['92%']}
                enableDynamicSizing={false}
                backdropComponent={renderBackdrop}
                onDismiss={() => setIsSheetOpen(false)}
                backgroundStyle={{ backgroundColor: dark ? '#000' : '#FFF' }}
                handleIndicatorStyle={{ backgroundColor: dark ? '#333' : '#E0E0E0' }}
            >
                {profileUser && (
                    <FullProfileView
                        user={profileUser}
                        isMe={false}
                        useBottomSheetScroll
                        onMessage={() => profileSheetRef.current?.dismiss()}
                        onFollow={async () => {
                            const targetId = profileUser?.public_id || profileUser?.id;
                            if (targetId) await api.toggleFollow(String(targetId));
                        }}
                        onBlock={async () => {
                            const targetId = profileUser?.public_id || profileUser?.id;
                            if (targetId) await api.toggleBlockUser(String(targetId));
                        }}
                    />
                )}
            </BaseBottomSheetModal>
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
    leftButtons: {
        flexDirection: 'row',
        alignItems: 'center',
        gap: 2,
        minWidth: 88,
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
    sidebarRoot: {
        flex: 1,
        flexDirection: 'row',
    },
    sidebarBackdrop: {
        flex: 1,
        backgroundColor: 'rgba(2,6,23,0.42)',
    },
    sidebarPanel: {
        position: 'absolute',
        left: 0,
        top: 0,
        bottom: 0,
        width: 324,
        borderRightWidth: StyleSheet.hairlineWidth,
        borderTopRightRadius: 28,
        borderBottomRightRadius: 28,
        paddingHorizontal: 16,
        paddingBottom: 18,
        shadowColor: '#000',
        shadowOpacity: 0.18,
        shadowRadius: 24,
        shadowOffset: { width: 0, height: 14 },
        elevation: 18,
    },
    sidebarHeader: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
        marginBottom: 16,
    },
    sidebarTitle: {
        fontSize: 22,
        fontFamily: 'Outfit-Bold',
        letterSpacing: 0.6,
        textTransform: 'uppercase',
    },
    sidebarCloseBtn: {
        width: 40,
        height: 40,
        borderRadius: 20,
        alignItems: 'center',
        justifyContent: 'center',
    },
    sidebarScroll: {
        flex: 1,
    },
    sidebarContent: {
        gap: 16,
        paddingBottom: 12,
    },
    sidebarHeroCard: {
        borderWidth: 1,
        borderRadius: 24,
        padding: 16,
        flexDirection: 'row',
        alignItems: 'center',
        gap: 14,
    },
    sidebarHeroAvatarWrap: {
        width: 62,
        height: 62,
        borderRadius: 22,
        borderWidth: 1,
        alignItems: 'center',
        justifyContent: 'center',
        overflow: 'hidden',
    },
    sidebarHeroAvatar: {
        width: '100%',
        height: '100%',
    },
    sidebarHeroBody: {
        flex: 1,
        gap: 4,
    },
    sidebarHeroTitle: {
        fontSize: 17,
        fontFamily: 'Outfit-Bold',
    },
    sidebarHeroSubtitle: {
        fontSize: 13,
        fontFamily: 'Inter-Regular',
    },
    sidebarHeroMetaRow: {
        flexDirection: 'row',
        flexWrap: 'wrap',
        gap: 8,
        marginTop: 6,
    },
    sidebarPill: {
        borderRadius: 999,
        paddingHorizontal: 10,
        paddingVertical: 6,
    },
    sidebarPillText: {
        fontSize: 11,
        fontFamily: 'Inter-Bold',
    },
    sidebarSection: {
        gap: 10,
    },
    sidebarSectionLabel: {
        fontSize: 11,
        fontFamily: 'Inter-Bold',
        letterSpacing: 1.4,
        textTransform: 'uppercase',
    },
    menuItem: {
        borderWidth: 1,
        borderRadius: 22,
        padding: 14,
        flexDirection: 'row',
        alignItems: 'center',
        gap: 12,
    },
    menuItemIcon: {
        width: 42,
        height: 42,
        borderRadius: 16,
        alignItems: 'center',
        justifyContent: 'center',
    },
    menuItemBody: {
        flex: 1,
        gap: 3,
    },
    menuItemTitle: {
        fontSize: 15,
        fontFamily: 'Inter-Bold',
    },
    menuItemSubtitle: {
        fontSize: 12,
        lineHeight: 18,
        fontFamily: 'Inter-Regular',
    },
    menuItemBadge: {
        minWidth: 24,
        height: 24,
        borderRadius: 12,
        paddingHorizontal: 7,
        alignItems: 'center',
        justifyContent: 'center',
    },
    menuItemBadgeText: {
        fontSize: 11,
        fontFamily: 'Inter-Bold',
    },
    menuItemChevronWrap: {
        width: 28,
        height: 28,
        borderRadius: 14,
        alignItems: 'center',
        justifyContent: 'center',
    },
    sidebarFooterCard: {
        borderWidth: 1,
        borderRadius: 22,
        paddingHorizontal: 14,
        paddingVertical: 16,
    },
    sidebarFooterTitle: {
        fontSize: 15,
        fontFamily: 'Outfit-Bold',
    },
    sidebarFooterText: {
        marginTop: 6,
        fontSize: 13,
        lineHeight: 18,
        fontFamily: 'Inter-Regular',
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
