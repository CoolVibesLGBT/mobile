import React, { useMemo, useRef, useState, useCallback, useEffect } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, Modal, Pressable, ActivityIndicator, FlatList } from 'react-native';
import { Image } from 'expo-image';
import { useTheme } from '@react-navigation/native';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import PostCard from '@/components/PostCard';
import { getSafeImageURL, getSafeImageURLEx } from '@/helpers/safeUrl';
import { VideoView, useVideoPlayer } from 'expo-video';
import * as ImagePicker from 'expo-image-picker';
import { api } from '@/services/apiService';
import { useAppSelector } from '@/store/hooks';
import { reportAppError } from '@/helpers/errorReporter';
import * as Localization from 'expo-localization';
import { lexicalToPlainText } from '@/helpers/lexicalPlainText';

type StoryItem = {
    id: string;
    name: string;
    avatar?: string | null;
    cover?: string | null;
    mediaUrl?: string | null;
    isVideo?: boolean;
    active?: boolean;
    raw?: any;
};

type TimelinePostCard = {
    id: string;
    user: {
        name: string;
        avatar: string;
        username: string;
        verified?: boolean;
    };
    image?: string;
    caption: string;
    likes: number;
    comments: number;
    time: string;
    raw?: any;
};

function coerceLocalizedText(value: unknown): string {
    if (typeof value === 'string') return value;
    if (!value || typeof value !== 'object') return '';

    const record = value as Record<string, unknown>;
    const languageCode = Localization.getLocales?.()?.[0]?.languageCode;
    const regionCode = Localization.getLocales?.()?.[0]?.regionCode;

    const candidates = [
        languageCode,
        languageCode && regionCode ? `${languageCode}-${regionCode}` : null,
        'en',
    ].filter(Boolean) as string[];

    for (const key of candidates) {
        const v = record[key];
        if (typeof v === 'string' && v.trim()) return v;
    }

    for (const v of Object.values(record)) {
        if (typeof v === 'string' && v.trim()) return v;
    }

    return '';
}

function normalizeTimelineResponse(response: any): { posts: any[]; cursor: string | null } {
    const payload = response?.data ?? response ?? {};
    const data = payload?.data ?? payload ?? {};
    const posts = Array.isArray(data?.posts) ? data.posts : Array.isArray(payload?.posts) ? payload.posts : [];
    const rawCursor = data?.cursor ?? payload?.cursor ?? null;
    return {
        posts,
        cursor: rawCursor != null ? String(rawCursor) : null,
    };
}

function formatRelativeTime(value: unknown): string {
    if (typeof value !== 'string') return '';
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return '';

    const delta = Date.now() - date.getTime();
    const minutes = Math.floor(delta / 60000);
    const hours = Math.floor(delta / 3600000);
    const days = Math.floor(delta / 86400000);

    if (minutes < 1) return 'just now';
    if (minutes < 60) return `${minutes} min ago`;
    if (hours < 24) return `${hours} hours ago`;
    if (days < 7) return `${days} days ago`;
    return date.toLocaleDateString();
}

function extractFirstImageAltTextFromLexical(input: unknown): string {
    if (typeof input !== 'string') return '';
    const trimmed = input.trim();
    if (!trimmed.startsWith('{')) return '';
    try {
        const parsed = JSON.parse(trimmed) as any;
        const stack: any[] = [parsed?.root ?? parsed];
        let guard = 0;
        while (stack.length && guard < 600) {
            guard += 1;
            const node = stack.pop();
            if (!node || typeof node !== 'object') continue;
            if (node.type === 'image' && typeof node.altText === 'string' && node.altText.trim()) {
                return node.altText.trim();
            }
            const children = node.children;
            if (Array.isArray(children)) {
                for (let i = children.length - 1; i >= 0; i -= 1) {
                    stack.push(children[i]);
                }
            }
        }
    } catch {
        // ignore parse errors
    }
    return '';
}

function mapTimelinePostsToCards(posts: any[]): TimelinePostCard[] {
    return (Array.isArray(posts) ? posts : [])
        .map((post: any) => {
            const author = post?.author ?? {};
            const seed = author?.public_id || author?.id || post?.author_id || post?.public_id || post?.id;
            const avatar = getSafeImageURLEx(seed, author?.avatar, 'small') || '';
            const attachments = Array.isArray(post?.attachments) ? post.attachments : [];
            const firstAttachment = attachments[0];
            const image =
                getSafeImageURL(firstAttachment, 'original') ||
                getSafeImageURL(firstAttachment, 'large') ||
                getSafeImageURL(firstAttachment, 'medium') ||
                getSafeImageURL(firstAttachment, 'small') ||
                undefined;

            const content = coerceLocalizedText(post?.content);
            const plain = lexicalToPlainText(content);
            const caption =
                (plain != null && plain.trim()) ? plain.trim()
                : extractFirstImageAltTextFromLexical(content) || '';

            const counts = post?.engagements?.counts || post?.engagement_counts || post?.engagements || {};
            const likes = Number(counts?.like_received_count ?? counts?.like_count ?? 0) || 0;
            const comments = Number(counts?.comment_count ?? 0) || 0;

            return {
                id: String(post?.public_id ?? post?.id ?? seed ?? Math.random()),
                user: {
                    name: author?.displayname || author?.username || 'User',
                    username: author?.username || author?.displayname || 'user',
                    avatar,
                },
                image,
                caption,
                likes,
                comments,
                time: formatRelativeTime(post?.created_at),
                raw: post,
            } as TimelinePostCard;
        })
        .filter((item) => Boolean(item.id));
}

export default function DiscoverScreen({ hideHeader = false, refreshToken }: { hideHeader?: boolean; refreshToken?: string }) {
    const { colors, dark } = useTheme();
    const insets = useSafeAreaInsets();
    const authUser = useAppSelector(state => state.auth.user);
    const [stories, setStories] = useState<StoryItem[]>([]);
    const [loadingStories, setLoadingStories] = useState(true);
    const [uploadingStory, setUploadingStory] = useState(false);
    const [viewerOpen, setViewerOpen] = useState(false);
    const [viewerIndex, setViewerIndex] = useState(0);
    const transformStories = useCallback((rawStories: any[]) => {
        const active = rawStories.filter((story: any) => !story?.is_expired);
        const sorted = [...active].sort(
            (a, b) => new Date(b?.created_at || 0).getTime() - new Date(a?.created_at || 0).getTime()
        );

        return sorted.map((story: any) => {
            const user = story?.user || {};
            const seed = user?.public_id || user?.id || story?.user_id || story?.id;
            const cover =
                getSafeImageURL(story?.media, 'thumbnail') ||
                getSafeImageURL(story?.media, 'small') ||
                getSafeImageURL(story?.media, 'icon') ||
                getSafeImageURL(story?.media, 'medium') ||
                null;
            const isVideo = Boolean(story?.media?.file?.mime_type?.startsWith('video/'));
            const mediaUrl =
                getSafeImageURL(story?.media, 'original') ||
                getSafeImageURL(story?.media, 'large') ||
                getSafeImageURL(story?.media, 'medium') ||
                cover ||
                null;
            const avatar =
                getSafeImageURLEx(seed, user?.avatar, 'icon') ||
                getSafeImageURLEx(seed, user?.avatar, 'small');
            return {
                id: String(story?.id || seed),
                name: user?.displayname || user?.username || 'User',
                avatar,
                cover,
                mediaUrl,
                isVideo,
                active: true,
                raw: story,
            } as StoryItem;
        });
    }, []);

    const fetchStories = useCallback(async () => {
        try {
            setLoadingStories(true);
            const response: any = await api.fetchStories({ limit: 50 });
            const storiesData =
                response?.data?.stories ||
                response?.stories ||
                response?.data?.data?.stories ||
                [];
            setStories(transformStories(storiesData));
        } catch (error) {
            console.error('Failed to fetch stories', error);
            setStories([]);
        } finally {
            setLoadingStories(false);
        }
    }, [transformStories]);

    const handleAddStory = useCallback(async () => {
        if (uploadingStory) return;
        try {
            const permissionResult = await ImagePicker.requestMediaLibraryPermissionsAsync();
            if (permissionResult.status !== 'granted') return;
            const result = await ImagePicker.launchImageLibraryAsync({
                mediaTypes: ImagePicker.MediaTypeOptions.All,
                quality: 0.9,
                videoMaxDuration: 30,
            });
            if (result.canceled || !result.assets?.length) return;
            const asset = result.assets[0];
            const isVideo = asset.type === 'video';
            const fallbackExt = isVideo ? 'mp4' : 'jpg';
            const file = {
                uri: asset.uri,
                name: asset.fileName || `story-${Date.now()}.${fallbackExt}`,
                type: asset.mimeType || (isVideo ? 'video/mp4' : 'image/jpeg'),
            } as any;
            setUploadingStory(true);
            await api.uploadStory({ story: file });
            await fetchStories();
        } catch (error) {
            console.error('Failed to upload story', error);
            reportAppError(error, { source: 'stories', action: 'user.upload_story' });
        } finally {
            setUploadingStory(false);
        }
    }, [fetchStories, uploadingStory]);

    useEffect(() => {
        fetchStories();
    }, [fetchStories]);

    // --- Timeline / Cool posts ---
    const timelineListRef = useRef<FlatList<TimelinePostCard> | null>(null);
    const timelineCursorRef = useRef<string | null>(null);
    const timelineHasMoreRef = useRef(true);
    const timelineFetchingRef = useRef(false);

    const [timeline, setTimeline] = useState<TimelinePostCard[]>([]);
    const [timelineLoading, setTimelineLoading] = useState(true);
    const [timelineRefreshing, setTimelineRefreshing] = useState(false);
    const [timelineLoadingMore, setTimelineLoadingMore] = useState(false);
    const [timelineError, setTimelineError] = useState<string | null>(null);

    const fetchTimeline = useCallback(
        async ({ refresh = false, loadMore = false }: { refresh?: boolean; loadMore?: boolean } = {}) => {
            if (timelineFetchingRef.current) return;
            if (loadMore && !timelineHasMoreRef.current) return;

            timelineFetchingRef.current = true;
            setTimelineError(null);

            if (refresh) setTimelineRefreshing(true);
            else if (loadMore) setTimelineLoadingMore(true);
            else setTimelineLoading(true);

            try {
                if (refresh) {
                    timelineCursorRef.current = null;
                    timelineHasMoreRef.current = true;
                    timelineListRef.current?.scrollToOffset({ offset: 0, animated: false });
                }

                const response: any = await api.fetchTimeline({
                    limit: 10,
                    cursor: loadMore ? (timelineCursorRef.current ?? '') : '',
                });

                const { posts, cursor } = normalizeTimelineResponse(response);
                const cards = mapTimelinePostsToCards(posts);

                const hasMore =
                    Boolean(cursor) &&
                    cursor !== '0' &&
                    cursor !== 'null' &&
                    cursor !== 'undefined';

                timelineCursorRef.current = hasMore ? cursor : null;
                timelineHasMoreRef.current = hasMore;

                setTimeline((prev) => {
                    if (!loadMore) return cards;
                    const existingIds = new Set(prev.map((item) => item.id));
                    return [...prev, ...cards.filter((item) => !existingIds.has(item.id))];
                });
            } catch (error) {
                console.error('Failed to fetch timeline', error);
                setTimelineError('Failed to load timeline');
                // apiService already reports the error globally; this is for UI state.
                timelineHasMoreRef.current = false;
                timelineCursorRef.current = null;
            } finally {
                setTimelineLoading(false);
                setTimelineRefreshing(false);
                setTimelineLoadingMore(false);
                timelineFetchingRef.current = false;
            }
        },
        []
    );

    useEffect(() => {
        void fetchTimeline();
    }, [fetchTimeline]);

    useEffect(() => {
        if (!refreshToken) return;
        void fetchTimeline({ refresh: true });
    }, [fetchTimeline, refreshToken]);

    const availableStories = useMemo(
        () => stories.filter((story) => story.mediaUrl || story.cover),
        [stories]
    );
    const currentStory = availableStories[viewerIndex];

    const openViewer = useCallback((index: number) => {
        setViewerIndex(index);
        setViewerOpen(true);
    }, []);

    const closeViewer = useCallback(() => {
        setViewerOpen(false);
    }, []);

    const goNext = useCallback(() => {
        if (viewerIndex < availableStories.length - 1) {
            setViewerIndex(prev => prev + 1);
        } else {
            setViewerOpen(false);
        }
    }, [availableStories.length, viewerIndex]);

    const goPrev = useCallback(() => {
        if (viewerIndex > 0) {
            setViewerIndex(prev => prev - 1);
        }
    }, [viewerIndex]);

    const videoPlayer = useVideoPlayer(currentStory?.mediaUrl || '', player => {
        player.loop = true;
    });

    useEffect(() => {
        if (!viewerOpen || !currentStory?.isVideo) {
            videoPlayer.pause();
            return;
        }
        videoPlayer.play();
    }, [viewerOpen, currentStory?.isVideo, videoPlayer]);

    useEffect(() => {
        if (availableStories.length === 0) {
            setViewerOpen(false);
            setViewerIndex(0);
            return;
        }
        if (viewerIndex >= availableStories.length) {
            setViewerIndex(0);
        }
    }, [availableStories.length, viewerIndex]);

    const borderColor = dark ? '#1A1A1A' : '#F0F0F0';

    const handleRefresh = useCallback(() => {
        void fetchStories();
        void fetchTimeline({ refresh: true });
    }, [fetchStories, fetchTimeline]);

    const handleLoadMore = useCallback(() => {
        if (timelineLoading || timelineRefreshing || timelineLoadingMore) return;
        if (!timelineHasMoreRef.current) return;
        void fetchTimeline({ loadMore: true });
    }, [fetchTimeline, timelineLoading, timelineLoadingMore, timelineRefreshing]);
    
    return (
        <View style={[styles.container, { backgroundColor: colors.background }]}>
            {/* Custom Header - DISABLED as we use GlobalHeader */}

            <FlatList
                ref={(ref) => {
                    timelineListRef.current = ref;
                }}
                data={timeline}
                keyExtractor={(item) => item.id}
                renderItem={({ item }) => {
                    const { id, raw, ...card } = item;
                    return <PostCard postId={id} {...card} />;
                }}
                showsVerticalScrollIndicator={false}
                contentContainerStyle={{
                    paddingTop: hideHeader ? 0 : (60 + insets.top),
                    paddingBottom: 120,
                }}
                refreshing={timelineRefreshing}
                onRefresh={handleRefresh}
                onEndReached={handleLoadMore}
                onEndReachedThreshold={0.5}
                removeClippedSubviews
                ListHeaderComponent={
                    <View style={[styles.storiesWrapper, { borderBottomColor: borderColor }]}>
                        <ScrollView
                            horizontal
                            showsHorizontalScrollIndicator={false}
                            contentContainerStyle={styles.storiesContainer}
                        >
                            <TouchableOpacity
                                style={styles.storyItem}
                                onPress={authUser ? handleAddStory : undefined}
                                disabled={!authUser || uploadingStory}
                            >
                                <View
                                    style={[
                                        styles.myStoryContainer,
                                        { backgroundColor: dark ? '#1A1A1A' : '#F5F5F5' },
                                    ]}
                                >
                                    {uploadingStory ? (
                                        <ActivityIndicator size="small" color={colors.text} />
                                    ) : (
                                        <MaterialCommunityIcons name="plus" size={24} color={colors.text} />
                                    )}
                                </View>
                                <Text style={[styles.storyName, { color: colors.text }]}>Add Story</Text>
                            </TouchableOpacity>

                            {loadingStories && availableStories.length === 0 ? (
                                <View style={styles.loadingStories}>
                                    <ActivityIndicator size="small" color={colors.text} />
                                </View>
                            ) : (
                                availableStories.map((story: any, index: number) => (
                                    <TouchableOpacity
                                        key={story.id}
                                        style={styles.storyItem}
                                        onPress={() => openViewer(index)}
                                    >
                                        <View
                                            style={[
                                                styles.storyAvatarContainer,
                                                { borderColor: story.active ? colors.text : (dark ? '#333' : '#EEE') },
                                            ]}
                                        >
                                            {story.cover || story.avatar ? (
                                                <Image
                                                    source={{ uri: story.cover || story.avatar }}
                                                    style={styles.storyAvatar}
                                                    contentFit="cover"
                                                />
                                            ) : (
                                                <View
                                                    style={[
                                                        styles.storyAvatar,
                                                        { backgroundColor: dark ? '#222' : '#DDD' },
                                                    ]}
                                                />
                                            )}
                                        </View>
                                        <Text
                                            style={[styles.storyName, { color: colors.text }]}
                                            numberOfLines={1}
                                        >
                                            {story.name}
                                        </Text>
                                    </TouchableOpacity>
                                ))
                            )}
                        </ScrollView>
                    </View>
                }
                ListEmptyComponent={
                    timelineLoading ? (
                        <View style={styles.loadingTimeline}>
                            <ActivityIndicator size="small" color={colors.text} />
                            <Text style={[styles.stateText, { color: dark ? '#777' : '#888' }]}>Loading timeline...</Text>
                        </View>
                    ) : timelineError ? (
                        <View style={styles.loadingTimeline}>
                            <Text style={[styles.stateText, { color: dark ? '#f87171' : '#dc2626' }]}>{timelineError}</Text>
                        </View>
                    ) : (
                        <View style={styles.loadingTimeline}>
                            <Text style={[styles.stateText, { color: dark ? '#777' : '#888' }]}>No posts yet.</Text>
                        </View>
                    )
                }
                ListFooterComponent={
                    timelineLoadingMore ? (
                        <View style={styles.loadingMore}>
                            <ActivityIndicator size="small" color={colors.text} />
                        </View>
                    ) : null
                }
            />

            <Modal
                visible={viewerOpen}
                animationType="fade"
                transparent={false}
                onRequestClose={closeViewer}
            >
                <View style={[styles.viewerContainer, { backgroundColor: '#000' }]}>
                    <View style={[styles.viewerTopBar, { paddingTop: insets.top + 8 }]}>
                    <View style={styles.viewerProgress}>
                        {availableStories.map((_, index) => (
                            <View key={`${index}`} style={styles.viewerProgressTrack}>
                                <View
                                        style={[
                                            styles.viewerProgressFill,
                                            { width: index <= viewerIndex ? '100%' : '0%' },
                                        ]}
                                    />
                                </View>
                            ))}
                        </View>

                        <View style={styles.viewerHeader}>
                            <View style={styles.viewerUser}>
                                {currentStory?.avatar ? (
                                    <Image source={{ uri: currentStory.avatar }} style={styles.viewerAvatar} contentFit="cover" />
                                ) : (
                                    <View style={[styles.viewerAvatar, { backgroundColor: '#222' }]} />
                                )}
                                <Text style={styles.viewerName} numberOfLines={1}>
                                    {currentStory?.name || 'Story'}
                                </Text>
                            </View>
                            <TouchableOpacity onPress={closeViewer} style={styles.viewerClose}>
                                <MaterialCommunityIcons name="close" size={22} color="#FFF" />
                            </TouchableOpacity>
                        </View>
                    </View>

                    <Pressable style={styles.viewerNavLeft} onPress={goPrev} />
                    <Pressable style={styles.viewerNavRight} onPress={goNext} />

                    <View style={styles.viewerContent}>
                        {currentStory?.isVideo && currentStory?.mediaUrl ? (
                            <VideoView
                                player={videoPlayer}
                                style={styles.viewerMedia}
                                allowsFullscreen
                                allowsPictureInPicture
                            />
                        ) : currentStory?.mediaUrl ? (
                            <Image source={{ uri: currentStory.mediaUrl }} style={styles.viewerMedia} contentFit="cover" />
                        ) : null}
                    </View>
                </View>
            </Modal>
        </View>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
    },
    header: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
        paddingHorizontal: 16,
        paddingTop: 50,
        paddingBottom: 15,
        borderBottomWidth: 1,
    },
    logoText: {
        fontSize: 26,
        fontWeight: '900',
        letterSpacing: -1.2,
    },
    headerIcons: {
        flexDirection: 'row',
        alignItems: 'center',
        gap: 16,
    },
    headerIcon: {
        padding: 4,
    },
    storiesWrapper: {
        paddingVertical: 15,
        borderBottomWidth: 1,
    },
    storiesContainer: {
        paddingHorizontal: 16,
        gap: 16,
    },
    storyItem: {
        alignItems: 'center',
        width: 72,
    },
    myStoryContainer: {
        width: 66,
        height: 66,
        borderRadius: 33,
        alignItems: 'center',
        justifyContent: 'center',
        marginBottom: 8,
        borderWidth: 1,
        borderColor: 'rgba(0,0,0,0.05)',
    },
    storyAvatarContainer: {
        width: 66,
        height: 66,
        borderRadius: 33,
        borderWidth: 2,
        padding: 2,
        alignItems: 'center',
        justifyContent: 'center',
        marginBottom: 8,
    },
    storyAvatar: {
        width: 58,
        height: 58,
        borderRadius: 29,
    },
    storyName: {
        fontSize: 12,
        fontFamily: 'Inter-SemiBold',
        letterSpacing: -0.2,
    },
    loadingStories: {
        height: 80,
        alignItems: 'center',
        justifyContent: 'center',
        width: 72,
    },
    loadingTimeline: {
        paddingTop: 28,
        paddingHorizontal: 16,
        alignItems: 'center',
        justifyContent: 'center',
        gap: 10,
    },
    stateText: {
        fontSize: 13,
        fontFamily: 'Inter-SemiBold',
    },
    loadingMore: {
        paddingVertical: 18,
        alignItems: 'center',
        justifyContent: 'center',
    },
    postsContainer: {
        width: '100%',
    },
    viewerContainer: {
        flex: 1,
    },
    viewerTopBar: {
        position: 'absolute',
        top: 0,
        left: 0,
        right: 0,
        zIndex: 10,
        paddingHorizontal: 12,
    },
    viewerProgress: {
        flexDirection: 'row',
        gap: 4,
    },
    viewerProgressTrack: {
        flex: 1,
        height: 2,
        backgroundColor: 'rgba(255,255,255,0.25)',
        borderRadius: 2,
        overflow: 'hidden',
    },
    viewerProgressFill: {
        height: 2,
        backgroundColor: '#FFF',
    },
    viewerHeader: {
        marginTop: 12,
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
    },
    viewerUser: {
        flexDirection: 'row',
        alignItems: 'center',
        gap: 8,
        flex: 1,
        paddingRight: 12,
    },
    viewerAvatar: {
        width: 32,
        height: 32,
        borderRadius: 16,
    },
    viewerName: {
        color: '#FFF',
        fontSize: 14,
        fontFamily: 'Inter-SemiBold',
    },
    viewerClose: {
        width: 32,
        height: 32,
        borderRadius: 16,
        alignItems: 'center',
        justifyContent: 'center',
        backgroundColor: 'rgba(255,255,255,0.12)',
    },
    viewerContent: {
        flex: 1,
        alignItems: 'center',
        justifyContent: 'center',
    },
    viewerMedia: {
        width: '100%',
        height: '100%',
    },
    viewerNavLeft: {
        position: 'absolute',
        left: 0,
        top: 0,
        bottom: 0,
        width: '35%',
        zIndex: 5,
    },
    viewerNavRight: {
        position: 'absolute',
        right: 0,
        top: 0,
        bottom: 0,
        width: '35%',
        zIndex: 5,
    },
});
