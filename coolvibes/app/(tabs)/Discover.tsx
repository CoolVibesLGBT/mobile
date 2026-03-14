import React, { useMemo, useState, useCallback, useEffect } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, Modal, Pressable, ActivityIndicator } from 'react-native';
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

const POSTS = [
    {
        id: 1,
        user: { name: 'Jordan Blue', username: 'jordan_b', avatar: 'https://i.pravatar.cc/150?u=jordan' },
        image: 'https://picsum.photos/800/800?random=1',
        caption: 'Enjoying the vibes today. #coolvibes #community',
        likes: 1240,
        comments: 48,
        time: '2 hours ago',
    },
    {
        id: 2,
        user: { name: 'Taylor Swift', username: 'taylor_s', avatar: 'https://i.pravatar.cc/150?u=taylor' },
        image: 'https://picsum.photos/800/800?random=2',
        caption: 'New music coming soon! Stay tuned. ✨',
        likes: 8500,
        comments: 320,
        time: '5 hours ago',
    },
    {
        id: 3,
        user: { name: 'Chris Evans', username: 'cevans', avatar: 'https://i.pravatar.cc/150?u=chris' },
        image: 'https://picsum.photos/800/800?random=3',
        caption: 'Morning workout done! 💪',
        likes: 4500,
        comments: 110,
        time: '8 hours ago',
    },
];

export default function DiscoverScreen({ hideHeader = false }: { hideHeader?: boolean }) {
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
        } finally {
            setUploadingStory(false);
        }
    }, [fetchStories, uploadingStory]);

    useEffect(() => {
        fetchStories();
    }, [fetchStories]);

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
    
    return (
        <View style={[styles.container, { backgroundColor: colors.background }]}>
            {/* Custom Header - DISABLED as we use GlobalHeader */}

            <ScrollView 
                showsVerticalScrollIndicator={false} 
                contentContainerStyle={{ 
                    paddingTop: hideHeader ? 0 : (60 + insets.top), 
                    paddingBottom: 100 
                }}
            >
                {/* Stories Section */}
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
                            <View style={[styles.myStoryContainer, { backgroundColor: dark ? '#1A1A1A' : '#F5F5F5' }]}>
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
                                <TouchableOpacity key={story.id} style={styles.storyItem} onPress={() => openViewer(index)}>
                                    <View style={[
                                        styles.storyAvatarContainer, 
                                        { borderColor: story.active ? colors.text : (dark ? '#333' : '#EEE') }
                                    ]}>
                                        {story.cover || story.avatar ? (
                                            <Image source={{ uri: story.cover || story.avatar }} style={styles.storyAvatar} contentFit="cover" />
                                        ) : (
                                            <View style={[styles.storyAvatar, { backgroundColor: dark ? '#222' : '#DDD' }]} />
                                        )}
                                    </View>
                                    <Text style={[styles.storyName, { color: colors.text }]} numberOfLines={1}>{story.name}</Text>
                                </TouchableOpacity>
                            ))
                        )}
                    </ScrollView>
                </View>

                {/* Posts Section */}
                <View style={styles.postsContainer}>
                    {POSTS.map(post => (
                        <PostCard key={post.id} {...post} />
                    ))}
                </View>

                {/* Bottom Padding */}
                <View style={{ height: 120 }} />
            </ScrollView>

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
