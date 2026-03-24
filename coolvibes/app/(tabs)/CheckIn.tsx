import React, { useMemo, useState, useCallback, useEffect, useRef } from 'react';
import { View, Text, StyleSheet, FlatList, TouchableOpacity, KeyboardAvoidingView, Platform, BackHandler, StatusBar, ActivityIndicator } from 'react-native';
import MapView, { Marker, PROVIDER_GOOGLE } from 'react-native-maps';
import { useTheme } from '@react-navigation/native';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { CheckInRadar } from '@/components/CheckInBar';
import PostCard from '@/components/PostCard';
import ChatInput from '@/components/ChatInput';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useAppSelector } from '@/store/hooks';
import Animated, { FadeIn, FadeOut, useSharedValue, useAnimatedStyle, withRepeat, withTiming, Easing } from 'react-native-reanimated';
import { BlurView } from 'expo-blur';
import { LinearGradient } from 'expo-linear-gradient';
import { getCurrentLocation } from '@/utils/location';
import { LocalizedStringToString } from '@/utils/utils';
import { api } from '@/services/apiService';
import { getSafeImageURL, getSafeImageURLEx } from '@/helpers/safeUrl';
import { getTagGradient } from '@/helpers/colors';
import { lexicalToPlainText } from '@/helpers/lexicalPlainText';

const DEFAULT_COORDS = { latitude: 41.0082, longitude: 28.9784 };
const MAP_DELTA = { latitudeDelta: 0.02, longitudeDelta: 0.02 };
const GLOBAL_HEADER_HEIGHT = 60;

type ViewModeType = 'map' | 'list';

type CheckinUser = {
    name: string;
    username: string;
    avatar: string;
    verified?: boolean;
};

type CheckinItem = {
    id: string;
    user: CheckinUser;
    image?: string;
    caption: string;
    likes: number;
    comments: number;
    time: string;
    tags: string[];
    latitude?: number;
    longitude?: number;
    raw?: any;
};

const DEFAULT_CHECKIN_LIMIT = 50;

const formatRelativeTime = (value?: string | null) => {
    if (!value) return '';
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return '';
    const diffMs = Date.now() - date.getTime();
    const diffSeconds = Math.max(0, Math.floor(diffMs / 1000));
    if (diffSeconds < 60) return 'Just now';
    const diffMinutes = Math.floor(diffSeconds / 60);
    if (diffMinutes < 60) return `${diffMinutes} min${diffMinutes === 1 ? '' : 's'} ago`;
    const diffHours = Math.floor(diffMinutes / 60);
    if (diffHours < 24) return `${diffHours} hour${diffHours === 1 ? '' : 's'} ago`;
    const diffDays = Math.floor(diffHours / 24);
    if (diffDays < 7) return `${diffDays} day${diffDays === 1 ? '' : 's'} ago`;
    const diffWeeks = Math.floor(diffDays / 7);
    if (diffWeeks < 4) return `${diffWeeks} week${diffWeeks === 1 ? '' : 's'} ago`;
    const diffMonths = Math.floor(diffDays / 30);
    if (diffMonths < 12) return `${diffMonths} month${diffMonths === 1 ? '' : 's'} ago`;
    const diffYears = Math.floor(diffDays / 365);
    return `${diffYears} year${diffYears === 1 ? '' : 's'} ago`;
};

export default function CheckInScreen() {
    const { colors, dark } = useTheme();
    const insets = useSafeAreaInsets();
    const router = useRouter();
    const params = useLocalSearchParams();
    const authUser = useAppSelector(state => state.auth.user);
    const systemData = useAppSelector(state => state.system.data);
    const language = useAppSelector(state => state.system.language) || authUser?.default_language || 'en';
    const draftCheckinParam = Array.isArray(params?.draft_checkin) ? params.draft_checkin[0] : params?.draft_checkin;
    const tabBarHeight = (Platform.OS === 'ios' ? 62 : 66) + Math.max(insets.bottom, 8);
    const createContentBottom = tabBarHeight + 110;
    const contentPaddingTop = GLOBAL_HEADER_HEIGHT + insets.top;
    const borderColor = dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.07)';
    const toggleBg = dark ? '#111' : '#F0F0F0';
    const mapBtnBg = dark ? 'rgba(17,17,17,0.65)' : 'rgba(255,255,255,0.85)';
    const mapBtnBorder = dark ? 'rgba(255,255,255,0.14)' : 'rgba(0,0,0,0.08)';
    const mapBtnIcon = dark ? '#fff' : '#111';

    const [selectedTags, setSelectedTags] = useState<string[]>([]);
    const [isCreateOpen, setIsCreateOpen] = useState(false);
    const [userLocation, setUserLocation] = useState(DEFAULT_COORDS);
    const [checkins, setCheckins] = useState<CheckinItem[]>([]);
    const [checkinsLoading, setCheckinsLoading] = useState(false);
    const [checkinsRefreshing, setCheckinsRefreshing] = useState(false);
    const [checkinsError, setCheckinsError] = useState<string | null>(null);
    const [viewMode, setViewMode] = useState<ViewModeType>('map');
    const mapRef = useRef<MapView>(null);
    const checkinsRequestRef = useRef(false);
    const fabPulse = useSharedValue(0);
    const [mapRegion, setMapRegion] = useState({
        latitude: DEFAULT_COORDS.latitude,
        longitude: DEFAULT_COORDS.longitude,
        latitudeDelta: MAP_DELTA.latitudeDelta,
        longitudeDelta: MAP_DELTA.longitudeDelta,
    });

    useEffect(() => {
        let active = true;
        const loadLocation = async () => {
            try {
                const coords = await getCurrentLocation();
                if (active) {
                    setUserLocation(coords);
                    setMapRegion({
                        latitude: coords.latitude,
                        longitude: coords.longitude,
                        latitudeDelta: MAP_DELTA.latitudeDelta,
                        longitudeDelta: MAP_DELTA.longitudeDelta,
                    });
                }
            } catch {
                if (active) {
                    setUserLocation(DEFAULT_COORDS);
                    setMapRegion({
                        latitude: DEFAULT_COORDS.latitude,
                        longitude: DEFAULT_COORDS.longitude,
                        latitudeDelta: MAP_DELTA.latitudeDelta,
                        longitudeDelta: MAP_DELTA.longitudeDelta,
                    });
                }
            }
        };
        loadLocation();
        return () => {
            active = false;
        };
    }, []);

    useEffect(() => {
        fetchCheckins();
    }, [fetchCheckins]);

    useEffect(() => {
        fabPulse.value = withRepeat(
            withTiming(1, { duration: 1800, easing: Easing.out(Easing.quad) }),
            -1,
            false
        );
    }, [fabPulse]);

    useEffect(() => {
        const mode = params?.checkin_mode;
        if (mode === 'create') {
            setIsCreateOpen(true);
        } else {
            setIsCreateOpen(false);
        }
    }, [params?.checkin_mode]);

    useEffect(() => {
        if (!isCreateOpen) return;
        const onBackPress = () => {
            setIsCreateOpen(false);
            router.setParams({ checkin_mode: undefined });
            return true;
        };
        const sub = BackHandler.addEventListener('hardwareBackPress', onBackPress);
        return () => sub.remove();
    }, [isCreateOpen, router]);

    useEffect(() => {
        if (!draftCheckinParam || typeof draftCheckinParam !== 'string') return;

        try {
            const decoded = JSON.parse(decodeURIComponent(draftCheckinParam));
            if (decoded && typeof decoded === 'object' && decoded.id) {
                setCheckins(prev => {
                    if (prev.some(item => item.id === decoded.id)) return prev;
                    return [decoded as CheckinItem, ...prev];
                });
                setViewMode('list');
            }
        } catch {
            // ignore malformed draft payload
        } finally {
            router.setParams({ draft_checkin: undefined });
        }
    }, [draftCheckinParam, router]);

    const tagMap = useMemo(() => {
        const map = new Map<string, any>();
        const root = (systemData as any)?.data ?? systemData;
        const list = root?.checkin_tag_types ?? [];
        list.forEach((tag: any) => {
            if (tag?.is_visible === false) return;
            if (tag?.tag) map.set(tag.tag, tag);
        });
        return map;
    }, [systemData]);

    const resolveTagDisplay = useCallback((tagKey: string) => {
        const tag = tagMap.get(tagKey);
        return {
            key: tagKey,
            label: tag?.name ? LocalizedStringToString(tag.name, language) : tagKey,
            icon: tag?.icon,
            gradient: getTagGradient(tag?.tag ?? tagKey),
        };
    }, [tagMap, language]);

    const tagAttachments = useMemo(() => {
        return selectedTags.map(tagKey => {
            const tag = tagMap.get(tagKey);
            const label = tag?.name ? LocalizedStringToString(tag.name, language) : tagKey;
            const gradient = getTagGradient(tag?.tag ?? tagKey);
            return {
                type: 'tag' as const,
                name: label,
                icon: tag?.icon,
                gradient,
                data: { tag: tagKey, label, gradient },
            };
        });
    }, [selectedTags, tagMap, language]);

    const mapCheckinPost = useCallback((post: any, index: number): CheckinItem | null => {
        if (!post) return null;
        const author = post?.author || post?.user || post?.owner || {};
        const id = String(post?.public_id ?? post?.id ?? `checkin-${index}`);
        const username = author?.username || author?.displayname || 'user';
        const name = author?.displayname || author?.username || 'User';
        const avatar =
            getSafeImageURLEx(
                author?.public_id ?? author?.id ?? username,
                author?.avatar || author?.avatar_url || author?.avatarUrl,
                'small'
            ) || `https://i.pravatar.cc/150?u=${username}`;

        const localizedContent = LocalizedStringToString(post?.content, language);
        const lexicalText = lexicalToPlainText(localizedContent) ?? lexicalToPlainText(post?.content);
        const isJsonish = typeof localizedContent === 'string' && /^[\[{]/.test(localizedContent.trim());
        const fallbackContent = isJsonish ? '' : localizedContent;
        const caption = (lexicalText || fallbackContent || post?.text || post?.body || '').trim() || 'Check-in';

        let attachments: any[] = [];
        if (Array.isArray(post?.attachments)) attachments = post.attachments;
        else if (post?.attachments) attachments = [post.attachments];
        else if (Array.isArray(post?.media)) attachments = post.media;
        else if (post?.media) attachments = [post.media];

        const image =
            getSafeImageURL(attachments[0], 'large') ||
            getSafeImageURL(attachments[0], 'medium') ||
            getSafeImageURL(attachments[0], 'small') ||
            undefined;

        const likes = Number(
            post?.engagements?.counts?.like_received_count ??
            post?.engagements?.counts?.like_count ??
            post?.likes_count ??
            post?.likes ??
            0
        );
        const comments = Number(
            post?.engagements?.counts?.comment_count ??
            post?.comment_count ??
            post?.comments ??
            0
        );

        const latitude =
            post?.lat ??
            post?.latitude ??
            post?.location?.lat ??
            post?.location?.latitude ??
            post?.coords?.latitude ??
            post?.coordinate?.latitude;
        const longitude =
            post?.lng ??
            post?.longitude ??
            post?.location?.lng ??
            post?.location?.longitude ??
            post?.coords?.longitude ??
            post?.coordinate?.longitude;
        const normalizedLat = typeof latitude === 'string' ? Number(latitude) : latitude;
        const normalizedLng = typeof longitude === 'string' ? Number(longitude) : longitude;

        return {
            id,
            user: {
                name,
                username,
                avatar,
                verified: Boolean(author?.verified ?? author?.is_verified ?? author?.isVerified),
            },
            image,
            caption,
            likes: Number.isFinite(likes) ? likes : 0,
            comments: Number.isFinite(comments) ? comments : 0,
            time: formatRelativeTime(post?.created_at ?? post?.updated_at ?? ''),
            tags: Array.isArray(post?.extras?.tags) ? post.extras.tags : [],
            latitude: Number.isFinite(normalizedLat) ? (normalizedLat as number) : undefined,
            longitude: Number.isFinite(normalizedLng) ? (normalizedLng as number) : undefined,
            raw: post,
        };
    }, [language]);

    const fetchCheckins = useCallback(async (opts?: { refresh?: boolean }) => {
        if (checkinsRequestRef.current) return;
        checkinsRequestRef.current = true;
        const isRefresh = opts?.refresh === true;
        if (isRefresh) {
            setCheckinsRefreshing(true);
        } else {
            setCheckinsLoading(true);
        }
        setCheckinsError(null);
        try {
            const response: any = await api.fetchCheckIns({ limit: DEFAULT_CHECKIN_LIMIT });
            const payload = response?.data ?? response ?? {};
            if (response?.success === false || payload?.success === false) {
                throw new Error(response?.message || payload?.message || 'Failed to fetch check-ins');
            }
            const posts = Array.isArray(payload?.posts)
                ? payload.posts
                : Array.isArray(response?.posts)
                    ? response.posts
                    : [];
            const mapped = posts
                .map((post: any, index: number) => mapCheckinPost(post, index))
                .filter((item: CheckinItem | null): item is CheckinItem => Boolean(item && item.id));
            setCheckins(mapped);
        } catch (error) {
            console.error('Failed to fetch check-ins', error);
            setCheckinsError('Check-ins yüklenemedi');
        } finally {
            setCheckinsLoading(false);
            setCheckinsRefreshing(false);
            checkinsRequestRef.current = false;
        }
    }, [mapCheckinPost]);

    const handleRemoveTagAttachment = useCallback((media: any) => {
        const tagKey = media?.data?.tag || media?.name;
        if (!tagKey) return;
        setSelectedTags(prev => prev.filter(t => t !== tagKey));
    }, []);

    const handleSelectTag = useCallback((tag: string) => {
        setSelectedTags(prev =>
            prev.includes(tag) ? prev.filter(t => t !== tag) : [...prev, tag]
        );
    }, []);

    const handleClearTags = useCallback(() => {
        setSelectedTags([]);
    }, []);

    const handleSendMessage = useCallback((text: string, media: any[]) => {
        const trimmed = text?.trim?.() ?? '';
        const mediaImage = media?.find((m: any) => m?.type === 'image' && m?.uri)?.uri;
        const hasTags = selectedTags.length > 0;
        if (!trimmed && !mediaImage && !hasTags) return;

        const name = authUser?.displayname || authUser?.username || 'You';
        const username = authUser?.username || 'you';
        const avatar = getSafeImageURLEx(authUser?.public_id ?? authUser?.id ?? username, authUser?.avatar, 'small') || `https://i.pravatar.cc/150?u=${username}`;

        const newItem: CheckinItem = {
            id: String(Date.now()),
            user: { name, username, avatar },
            image: mediaImage,
            caption: trimmed || (hasTags ? 'Check-in' : 'Check-in'),
            likes: 0,
            comments: 0,
            time: 'Just now',
            tags: [...selectedTags],
            latitude: userLocation.latitude,
            longitude: userLocation.longitude,
        };

        setCheckins(prev => [newItem, ...prev]);
        setSelectedTags([]);
        setIsCreateOpen(false);
        router.setParams({ checkin_mode: undefined });
    }, [authUser, selectedTags, userLocation, router]);

    const handleOpenCreate = useCallback(() => {
        router.push('/CheckInCreate');
    }, [router]);

    const handleExit = useCallback(() => {
        setIsCreateOpen(false);
        setSelectedTags([]);
        router.setParams({ checkin_mode: undefined });
    }, [router]);

    const handleMyLocation = useCallback(() => {
        const next = {
            latitude: userLocation.latitude,
            longitude: userLocation.longitude,
            latitudeDelta: mapRegion.latitudeDelta,
            longitudeDelta: mapRegion.longitudeDelta,
        };
        setMapRegion(next);
        mapRef.current?.animateToRegion(next, 350);
    }, [userLocation, mapRegion.latitudeDelta, mapRegion.longitudeDelta]);

    const overlayBg = dark ? 'rgba(0,0,0,0.96)' : 'rgba(255,255,255,0.98)';
    const isFetchingCheckins = checkinsLoading || checkinsRefreshing;

    const fabPulseStyle = useAnimatedStyle(() => ({
        transform: [{ scale: 0.85 + fabPulse.value * 0.9 }],
        opacity: 0.45 * (1 - fabPulse.value),
    }));

    const fabPulseStyleAlt = useAnimatedStyle(() => {
        const t = (fabPulse.value + 0.5) % 1;
        return {
            transform: [{ scale: 0.85 + t * 0.9 }],
            opacity: 0.28 * (1 - t),
        };
    });

    const VIEW_ICONS: { key: ViewModeType; icon: string }[] = [
        { key: 'map', icon: 'map-outline' },
        { key: 'list', icon: 'format-list-bulleted' },
    ];

    const getCheckinCoordinate = useCallback((item: any, index: number) => {
        const lat =
            item?.lat ??
            item?.latitude ??
            item?.location?.lat ??
            item?.location?.latitude ??
            item?.coords?.latitude ??
            item?.coordinate?.latitude;
        const lng =
            item?.lng ??
            item?.longitude ??
            item?.location?.lng ??
            item?.location?.longitude ??
            item?.coords?.longitude ??
            item?.coordinate?.longitude;

        if (typeof lat === 'number' && typeof lng === 'number') {
            return { latitude: lat, longitude: lng };
        }

        const seed = Number(item?.id ?? index + 1);
        const offset = 0.002 + (index % 5) * 0.001;
        const angle = (seed % 360) * (Math.PI / 180);
        return {
            latitude: userLocation.latitude + Math.cos(angle) * offset,
            longitude: userLocation.longitude + Math.sin(angle) * offset,
        };
    }, [userLocation]);

    const checkinMarkers = useMemo(() => {
        return checkins.map((item, index) => ({
            item,
            coordinate: getCheckinCoordinate(item, index),
        }));
    }, [checkins, getCheckinCoordinate]);

    return (
        <View style={[styles.container, { backgroundColor: colors.background }]}>
            <StatusBar barStyle={dark ? 'light-content' : 'dark-content'} />

            <View style={[styles.subHeader, { paddingTop: contentPaddingTop + 6, borderBottomColor: borderColor, backgroundColor: colors.background }]}>
                <View style={styles.subRow}>
                    <View style={{ flex: 1 }}>
                        <Text style={[styles.title, { color: colors.text }]}>Check-ins</Text>
                        <Text style={[styles.subtitle, { color: dark ? '#666' : '#AAA' }]}>
                            {checkins.length} check-ins
                        </Text>
                    </View>
                    <View style={styles.controls}>
                        <TouchableOpacity
                            onPress={() => fetchCheckins({ refresh: true })}
                            activeOpacity={0.8}
                            disabled={isFetchingCheckins}
                            style={[styles.refreshBtn, { borderColor, backgroundColor: toggleBg }]}
                        >
                            {isFetchingCheckins ? (
                                <ActivityIndicator size="small" color={dark ? '#FFF' : '#111'} />
                            ) : (
                                <MaterialCommunityIcons name="refresh" size={18} color={dark ? '#FFF' : '#111'} />
                            )}
                        </TouchableOpacity>
                        <View style={[styles.toggle, { backgroundColor: toggleBg, borderColor }]}>
                            {VIEW_ICONS.map(({ key, icon }) => {
                                const active = viewMode === key;
                                return (
                                    <TouchableOpacity
                                        key={key}
                                        onPress={() => setViewMode(key)}
                                        activeOpacity={0.8}
                                        style={[styles.toggleBtn, active && { backgroundColor: dark ? '#FFF' : '#000' }]}
                                    >
                                        <MaterialCommunityIcons
                                            name={icon as any}
                                            size={16}
                                            color={active ? (dark ? '#000' : '#FFF') : (dark ? '#666' : '#AAA')}
                                        />
                                    </TouchableOpacity>
                                );
                            })}
                        </View>
                    </View>
                </View>
            </View>

            <View style={[styles.content, { paddingBottom: tabBarHeight }]}>
                {viewMode === 'map' && (
                    <View style={{ flex: 1 }}>
                        <MapView
                            ref={mapRef}
                            provider={PROVIDER_GOOGLE}
                            style={StyleSheet.absoluteFill}
                            region={mapRegion}
                            onRegionChangeComplete={(region) => {
                                if (!isCreateOpen) setMapRegion(region);
                            }}
                            showsUserLocation
                            showsMyLocationButton={false}
                            scrollEnabled={!isCreateOpen}
                            rotateEnabled={!isCreateOpen}
                            pitchEnabled={!isCreateOpen}
                        >
                            <Marker coordinate={userLocation} />
                            {checkinMarkers.map(({ item, coordinate }) => (
                                <Marker
                                    key={item.id}
                                    coordinate={coordinate}
                                    title={item?.user?.name || item?.user?.username || 'Check-in'}
                                    description={item?.caption}
                                />
                            ))}
                        </MapView>
                        <View style={[styles.mapControls, { bottom: tabBarHeight + 96 }]}>
                            <TouchableOpacity
                                style={[styles.mapCtrlBtn, { backgroundColor: mapBtnBg, borderColor: mapBtnBorder }]}
                                onPress={handleMyLocation}
                                activeOpacity={0.85}
                                hitSlop={{ top: 6, bottom: 6, left: 6, right: 6 }}
                            >
                                <BlurView intensity={dark ? 30 : 80} tint={dark ? 'dark' : 'light'} style={StyleSheet.absoluteFill} />
                                <MaterialCommunityIcons name="crosshairs-gps" size={22} color={mapBtnIcon} />
                            </TouchableOpacity>
                        </View>
                    </View>
                )}

                {viewMode === 'list' && (
                    checkinsLoading && checkins.length === 0 ? (
                        <View style={[styles.stateWrap, { paddingBottom: tabBarHeight + 12 }]}>
                            <ActivityIndicator size="small" color={colors.text} />
                            <Text style={[styles.stateText, { color: dark ? '#777' : '#888' }]}>Loading check-ins...</Text>
                        </View>
                    ) : checkinsError ? (
                        <View style={[styles.stateWrap, { paddingBottom: tabBarHeight + 12 }]}>
                            <Text style={[styles.stateText, { color: dark ? '#f87171' : '#dc2626' }]}>{checkinsError}</Text>
                        </View>
                    ) : (
                        <FlatList
                            data={checkins}
                            keyExtractor={(item) => item.id.toString()}
                            renderItem={({ item }) => {
                                const tagDisplays = item.tags.map(tagKey => resolveTagDisplay(tagKey));
                                return <PostCard {...item} tags={tagDisplays} />;
                            }}
                            contentContainerStyle={{ paddingBottom: tabBarHeight + 12 }}
                            showsVerticalScrollIndicator={false}
                            refreshing={checkinsRefreshing}
                            onRefresh={() => fetchCheckins({ refresh: true })}
                        />
                    )
                )}
            </View>

            {!isCreateOpen && (
                <TouchableOpacity
                    style={[styles.fab, { bottom: tabBarHeight + 18 }]}
                    onPress={handleOpenCreate}
                    activeOpacity={0.9}
                >
                    <Animated.View pointerEvents="none" style={[styles.fabPulseHeart, fabPulseStyleAlt]}>
                        <MaterialCommunityIcons name="heart-outline" size={56} color="rgba(255,255,255,0.7)" />
                    </Animated.View>
                    <Animated.View pointerEvents="none" style={[styles.fabPulseHeart, fabPulseStyle]}>
                        <MaterialCommunityIcons name="heart" size={50} color="rgba(16,185,129,0.4)" />
                    </Animated.View>
                    <LinearGradient
                        colors={['#10B981', '#34D399']}
                        start={{ x: 0, y: 0 }}
                        end={{ x: 1, y: 1 }}
                        style={styles.fabGradient}
                    >
                        <View style={styles.fabRing} />
                        <View style={styles.fabHighlight} />
                        <MaterialCommunityIcons name="map-marker-plus" size={24} color="#fff" />
                    </LinearGradient>
                </TouchableOpacity>
            )}

            {isCreateOpen && (
                <Animated.View
                    entering={FadeIn.duration(200)}
                    exiting={FadeOut.duration(200)}
                    style={[styles.createOverlay, { backgroundColor: overlayBg, paddingTop: insets.top + 12, paddingBottom: createContentBottom }]}
                >
                    <TouchableOpacity style={styles.backdrop} activeOpacity={1} onPress={handleExit} />
                    <View style={styles.createHeader}>
                        <View>
                            <Text style={[styles.createTitle, { color: colors.text }]}>Check-in</Text>
                            <Text style={[styles.createSubtitle, { color: dark ? '#666' : '#888' }]}>
                                Durumunu seç ve paylaş
                            </Text>
                        </View>
                        <TouchableOpacity onPress={handleExit} style={styles.closeBtn} activeOpacity={0.8}>
                            <MaterialCommunityIcons name="close" size={18} color={colors.text} />
                        </TouchableOpacity>
                    </View>

                    <View style={styles.honeycombWrap} pointerEvents="box-none">
                        <CheckInRadar
                            selectedTags={selectedTags}
                            onSelectTag={handleSelectTag}
                            onClearTags={handleClearTags}
                            centerOffsetY={-24}
                        />
                        <View style={[styles.hintPill, { backgroundColor: dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.06)' }]}>
                            <Text style={[styles.hintText, { color: dark ? '#777' : '#888' }]}>SÜRÜKLE & SEÇ</Text>
                        </View>
                    </View>

                    <KeyboardAvoidingView
                        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
                        keyboardVerticalOffset={Platform.OS === 'ios' ? 90 : 0}
                        style={[styles.createInputWrap, { bottom: tabBarHeight }]}
                    >
                        <ChatInput
                            currentUser={authUser}
                            onSendMessage={handleSendMessage}
                            replyingTo={null}
                            onCancelReply={() => null}
                            editingMessage={null}
                            onCancelEdit={() => null}
                            extraMedia={tagAttachments}
                            onRemoveExtraMedia={handleRemoveTagAttachment}
                        />
                    </KeyboardAvoidingView>
                </Animated.View>
            )}
        </View>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
    },
    subHeader: {
        paddingHorizontal: 16,
        paddingBottom: 12,
        borderBottomWidth: StyleSheet.hairlineWidth,
        zIndex: 5,
    },
    subRow: { flexDirection: 'row', alignItems: 'center', gap: 10 },
    title: { fontSize: 22, fontFamily: 'Outfit-Black', letterSpacing: -0.4 },
    subtitle: { fontSize: 11, fontFamily: 'Inter-Medium', marginTop: 1 },
    controls: { flexDirection: 'row', gap: 6 },
    refreshBtn: {
        width: 36,
        height: 36,
        borderRadius: 10,
        borderWidth: StyleSheet.hairlineWidth,
        alignItems: 'center',
        justifyContent: 'center',
    },
    toggle: { flexDirection: 'row', borderRadius: 10, borderWidth: StyleSheet.hairlineWidth, padding: 3, gap: 2 },
    toggleBtn: { width: 30, height: 30, borderRadius: 7, alignItems: 'center', justifyContent: 'center' },
    content: { flex: 1 },
    stateWrap: {
        flex: 1,
        alignItems: 'center',
        justifyContent: 'center',
        paddingHorizontal: 16,
        gap: 10,
    },
    stateText: {
        fontSize: 13,
        fontFamily: 'Inter-Medium',
        textAlign: 'center',
    },
    fab: {
        position: 'absolute',
        right: 20,
        width: 60,
        height: 60,
        borderRadius: 30,
        alignItems: 'center',
        justifyContent: 'center',
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 10 },
        shadowOpacity: 0.25,
        shadowRadius: 14,
        elevation: 12,
        overflow: 'visible',
    },
    fabPulseHeart: {
        position: 'absolute',
        width: 78,
        height: 78,
        alignItems: 'center',
        justifyContent: 'center',
        borderRadius: 39,
        shadowColor: '#10B981',
        shadowOpacity: 0.45,
        shadowRadius: 16,
        shadowOffset: { width: 0, height: 6 },
        elevation: 6,
    },
    fabGradient: {
        width: '100%',
        height: '100%',
        borderRadius: 30,
        alignItems: 'center',
        justifyContent: 'center',
        overflow: 'hidden',
    },
    fabRing: {
        position: 'absolute',
        inset: 1.5,
        borderRadius: 999,
        borderWidth: 1,
        borderColor: 'rgba(255,255,255,0.35)',
    },
    fabHighlight: {
        position: 'absolute',
        top: -8,
        left: -10,
        right: -10,
        height: 24,
        backgroundColor: 'rgba(255,255,255,0.25)',
        transform: [{ rotate: '-8deg' }],
    },
    mapControls: {
        position: 'absolute',
        right: 16,
        zIndex: 12,
    },
    mapCtrlBtn: {
        width: 48,
        height: 48,
        borderRadius: 24,
        alignItems: 'center',
        justifyContent: 'center',
        borderWidth: 1,
        overflow: 'hidden',
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 6 },
        shadowOpacity: 0.22,
        shadowRadius: 10,
        elevation: 8,
    },
    createOverlay: {
        ...StyleSheet.absoluteFillObject,
    },
    backdrop: {
        ...StyleSheet.absoluteFillObject,
    },
    createHeader: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
        paddingHorizontal: 20,
        paddingBottom: 10,
        zIndex: 2,
    },
    createTitle: {
        fontSize: 18,
        fontFamily: 'Outfit-Black',
        letterSpacing: 0.2,
    },
    createSubtitle: {
        marginTop: 4,
        fontSize: 12,
        fontFamily: 'Inter-Medium',
    },
    closeBtn: {
        width: 36,
        height: 36,
        borderRadius: 18,
        alignItems: 'center',
        justifyContent: 'center',
        backgroundColor: 'rgba(127,127,127,0.12)',
    },
    honeycombWrap: {
        flex: 1,
        justifyContent: 'center',
        zIndex: 1,
    },
    hintPill: {
        position: 'absolute',
        bottom: 8,
        alignSelf: 'center',
        paddingHorizontal: 12,
        paddingVertical: 6,
        borderRadius: 14,
    },
    hintText: {
        fontSize: 9,
        fontFamily: 'Inter-Bold',
        letterSpacing: 1,
    },
    createInputWrap: {
        width: '100%',
        position: 'absolute',
        left: 0,
        right: 0,
        zIndex: 5,
    },
});
