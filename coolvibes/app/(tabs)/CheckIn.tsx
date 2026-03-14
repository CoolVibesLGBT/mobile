import React, { useMemo, useState, useCallback, useEffect } from 'react';
import { View, Text, StyleSheet, FlatList, TouchableOpacity, Dimensions, KeyboardAvoidingView, Platform, BackHandler } from 'react-native';
import MapView, { Marker, PROVIDER_GOOGLE } from 'react-native-maps';
import { useTheme } from '@react-navigation/native';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { CheckInRadar } from '@/components/CheckInBar';
import PostCard from '@/components/PostCard';
import ChatInput from '@/components/ChatInput';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useAppSelector } from '@/store/hooks';
import Animated, { FadeIn, FadeOut } from 'react-native-reanimated';
import { getCurrentLocation } from '@/utils/location';
import { LocalizedStringToString } from '@/utils/utils';
import { getSafeImageURLEx } from '@/helpers/safeUrl';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');
const DEFAULT_COORDS = { latitude: 41.0082, longitude: 28.9784 };
const MAP_DELTA = { latitudeDelta: 0.02, longitudeDelta: 0.02 };

const MOCK_CHECKINS = [
    {
        id: 1,
        user: { name: 'Alex Thompson', username: 'alex_t', avatar: 'https://i.pravatar.cc/150?u=alex' },
        image: 'https://picsum.photos/800/800?random=11',
        caption: 'Checking in at the Rainbow Hub! 🌈 #inclusive #vibes',
        likes: 42,
        comments: 5,
        time: 'Just now',
    },
    {
        id: 2,
        user: { name: 'Jordan Blue', username: 'jordan_b', avatar: 'https://i.pravatar.cc/150?u=jordan' },
        image: 'https://picsum.photos/800/800?random=12',
        caption: 'Great atmosphere here. Feeling productive. ☕️',
        likes: 128,
        comments: 12,
        time: '20 mins ago',
    },
    {
        id: 3,
        user: { name: 'Taylor Swift', username: 'taylor_s', avatar: 'https://i.pravatar.cc/150?u=taylor' },
        image: 'https://picsum.photos/800/800?random=13',
        caption: 'Love the new monochrome theme! So sleek. ⚫️⚪️',
        likes: 850,
        comments: 45,
        time: '1 hour ago',
    },
];

export default function CheckInScreen() {
    const { colors, dark } = useTheme();
    const insets = useSafeAreaInsets();
    const authUser = useAppSelector(state => state.auth.user);
    const systemData = useAppSelector(state => state.system.data);
    const tabBarHeight = (Platform.OS === 'ios' ? 62 : 66) + Math.max(insets.bottom, 8);
    const createContentBottom = tabBarHeight + 110;

    const [selectedTags, setSelectedTags] = useState<string[]>([]);
    const [isCreateOpen, setIsCreateOpen] = useState(false);
    const [userLocation, setUserLocation] = useState(DEFAULT_COORDS);
    const [checkins, setCheckins] = useState(MOCK_CHECKINS);
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
        if (!isCreateOpen) return;
        const onBackPress = () => {
            setIsCreateOpen(false);
            return true;
        };
        const sub = BackHandler.addEventListener('hardwareBackPress', onBackPress);
        return () => sub.remove();
    }, [isCreateOpen]);

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

    const tagAttachments = useMemo(() => {
        return selectedTags.map(tagKey => {
            const tag = tagMap.get(tagKey);
            const label = tag?.name ? LocalizedStringToString(tag.name, authUser?.default_language) : tagKey;
            return {
                type: 'tag' as const,
                name: label,
                icon: tag?.icon,
                data: { tag: tagKey, label },
            };
        });
    }, [selectedTags, tagMap, authUser?.default_language]);

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

        const newItem = {
            id: Date.now(),
            user: { name, username, avatar },
            image: mediaImage,
            caption: trimmed || (hasTags ? 'Check-in' : 'Check-in'),
            likes: 0,
            comments: 0,
            time: 'Just now',
            tags: [...selectedTags],
        };

        setCheckins(prev => [newItem, ...prev]);
        setSelectedTags([]);
        setIsCreateOpen(false);
    }, [authUser, selectedTags]);

    const handleOpenCreate = useCallback(() => {
        setIsCreateOpen(true);
    }, []);

    const handleCloseCreate = useCallback(() => {
        setIsCreateOpen(false);
        setSelectedTags([]);
    }, []);

    const handleExit = useCallback(() => {
        setIsCreateOpen(false);
        setSelectedTags([]);
    }, []);

    const sheetBg = dark ? 'rgba(0,0,0,0.82)' : 'rgba(255,255,255,0.96)';
    const sheetBorder = dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.08)';
    const overlayBg = dark ? 'rgba(0,0,0,0.96)' : 'rgba(255,255,255,0.98)';

    return (
        <View style={[styles.container, { backgroundColor: colors.background }]}>
            <MapView
                provider={PROVIDER_GOOGLE}
                style={StyleSheet.absoluteFill}
                region={mapRegion}
                onRegionChangeComplete={(region) => {
                    if (!isCreateOpen) setMapRegion(region);
                }}
                showsUserLocation
                showsMyLocationButton
                scrollEnabled={!isCreateOpen}
                rotateEnabled={!isCreateOpen}
                pitchEnabled={!isCreateOpen}
            >
                <Marker coordinate={userLocation} />
            </MapView>

            <View style={styles.overlay} pointerEvents="box-none">
                <TouchableOpacity
                    style={styles.fab}
                    onPress={handleOpenCreate}
                    activeOpacity={0.9}
                >
                    <MaterialCommunityIcons name="map-marker-plus" size={22} color="#fff" />
                </TouchableOpacity>

                <View style={[styles.sheet, { backgroundColor: sheetBg, borderTopColor: sheetBorder }]} pointerEvents="auto">
                    <View style={[styles.sheetHandle, { backgroundColor: dark ? 'rgba(255,255,255,0.2)' : '#E5E7EB' }]} />
                    <View style={styles.sheetHeader}>
                        <Text style={[styles.sheetTitle, { color: colors.text }]}>Check-ins</Text>
                        <View style={[styles.sheetBadge, { backgroundColor: dark ? 'rgba(16,185,129,0.2)' : 'rgba(16,185,129,0.12)' }]}>
                            <Text style={[styles.sheetBadgeText, { color: dark ? '#6EE7B7' : '#059669' }]}>
                                {checkins.length}
                            </Text>
                        </View>
                    </View>
                    <View style={styles.sheetBody}>
                        <FlatList
                            data={checkins}
                            keyExtractor={(item) => item.id.toString()}
                            renderItem={({ item }) => <PostCard {...item} />}
                            contentContainerStyle={[styles.listContent, { paddingBottom: tabBarHeight + 12 }]}
                            showsVerticalScrollIndicator={false}
                        />
                    </View>

                </View>
            </View>

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
    overlay: {
        ...StyleSheet.absoluteFillObject,
        justifyContent: 'flex-end',
    },
    fab: {
        position: 'absolute',
        right: 20,
        bottom: SCREEN_HEIGHT * 0.5 + 24,
        width: 54,
        height: 54,
        borderRadius: 27,
        backgroundColor: '#10B981',
        alignItems: 'center',
        justifyContent: 'center',
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 10 },
        shadowOpacity: 0.2,
        shadowRadius: 12,
        elevation: 10,
    },
    sheet: {
        borderTopWidth: 1,
        borderTopLeftRadius: 26,
        borderTopRightRadius: 26,
        height: SCREEN_HEIGHT * 0.52,
        paddingBottom: 8,
    },
    sheetHandle: {
        width: 36,
        height: 4,
        borderRadius: 2,
        alignSelf: 'center',
        marginTop: 8,
        marginBottom: 8,
    },
    sheetHeader: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
        paddingHorizontal: 16,
        paddingBottom: 10,
    },
    sheetTitle: {
        fontSize: 15,
        fontFamily: 'Outfit-Black',
        letterSpacing: 0.2,
    },
    sheetBadge: {
        paddingHorizontal: 10,
        paddingVertical: 4,
        borderRadius: 12,
    },
    sheetBadgeText: {
        fontSize: 10,
        fontFamily: 'Inter-Bold',
        letterSpacing: 1,
    },
    listContent: {
        paddingTop: 8,
    },
    sheetBody: {
        flex: 1,
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
    selectedTagsWrap: {
        paddingHorizontal: 16,
        paddingVertical: 10,
        borderTopWidth: 1,
        flexDirection: 'row',
        flexWrap: 'wrap',
        gap: 8,
    },
    selectedTag: {
        flexDirection: 'row',
        alignItems: 'center',
        gap: 6,
        paddingHorizontal: 10,
        paddingVertical: 6,
        borderRadius: 14,
        maxWidth: SCREEN_WIDTH - 48,
    },
    selectedTagText: {
        fontSize: 10,
        fontFamily: 'Inter-Bold',
        letterSpacing: 0.5,
        textTransform: 'uppercase',
    },
    createInputWrap: {
        width: '100%',
        position: 'absolute',
        left: 0,
        right: 0,
        zIndex: 5,
    },
});
