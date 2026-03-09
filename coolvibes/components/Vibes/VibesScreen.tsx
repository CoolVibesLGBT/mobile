import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  ActivityIndicator,
  FlatList,
  ListRenderItemInfo,
  NativeScrollEvent,
  NativeSyntheticEvent,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { BlurView } from 'expo-blur';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Sparkles, Volume2, VolumeX } from 'lucide-react-native';

import { api } from '@/services/apiService';
import { defaultServiceServerId, serviceURL } from '@/config';
import { getSafeImageURL, getSafeImageURLEx } from '@/helpers/safeUrl';

import { BurstOverlay, VibeItem } from './VibeItem';
import type { BurstType, VibeItemData } from './types';

const dummyVibes = require('@/mock/dummy_vibes.json') as {
  data?: { posts?: unknown[] };
};

function normalizeVibesResponse(response: any): { posts: any[]; cursor: string | null } {
  const payload = response?.data ?? response ?? {};
  const posts = Array.isArray(payload?.posts) ? payload.posts : [];
  const rawCursor = payload?.cursor ?? response?.cursor ?? null;
  return {
    posts,
    cursor: rawCursor != null ? String(rawCursor) : null,
  };
}

function mapPostsToVibes(posts: any[]): VibeItemData[] {
  return posts
    .filter((post) => post?.attachments?.length)
    .map((post): VibeItemData => {
      const attachment = post.attachments[0];
      const file = attachment?.file;
      const author = post.author ?? {};
      const mimeType = file?.mime_type ?? '';
      const isVideo = mimeType.startsWith('video/');

      let mediaUrl = '';
      let posterUrl = '';

      if (isVideo) {
        mediaUrl =
          getSafeImageURL(attachment, 'high') ||
          getSafeImageURL(attachment, 'medium') ||
          getSafeImageURL(attachment, 'low') ||
          getSafeImageURL(attachment, 'preview') ||
          getSafeImageURL(attachment, 'original') ||
          '';

        if (!mediaUrl && file?.storage_path) {
          const serviceUri = serviceURL[defaultServiceServerId];
          const path = String(file.storage_path).replace(/^\.\//, '');
          mediaUrl = `${serviceUri}/${path}`;
        }

        posterUrl = getSafeImageURL(attachment, 'poster') || '';
      } else {
        mediaUrl =
          getSafeImageURL(attachment, 'large') ||
          getSafeImageURL(attachment, 'medium') ||
          getSafeImageURL(attachment, 'small') ||
          getSafeImageURL(attachment, 'original') ||
          '';
      }

      return {
        id: String(post.public_id ?? post.id),
        mediaUrl,
        mediaType: isVideo ? 'video' : 'image',
        posterUrl: posterUrl || undefined,
        username: author.username || author.displayname || 'Unknown',
        dateOfBirth: author.date_of_birth,
        avatar: getSafeImageURLEx(author.public_id, author.avatar, 'small') || '',
        description: file?.name || 'Vibe',
        bio: author.bio || '',
        author,
      };
    })
    .filter((item) => Boolean(item.id && item.mediaUrl));
}

export default function VibesScreen() {
  const insets = useSafeAreaInsets();
  const flatListRef = useRef<FlatList<VibeItemData>>(null);
  const cursorRef = useRef<string | null>(null);
  const hasMoreRef = useRef(true);
  const isFetchingRef = useRef(false);

  const [viewportHeight, setViewportHeight] = useState(0);
  const [vibes, setVibes] = useState<VibeItemData[]>([]);
  const [activeIndex, setActiveIndex] = useState(0);
  const [isMuted, setIsMuted] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [isMediaLoading, setIsMediaLoading] = useState(false);
  const [burstType, setBurstType] = useState<BurstType | null>(null);

  const hasVibes = vibes.length > 0;

  const fetchVibesFromApi = useCallback(async (loadMore = false) => {
    if (isFetchingRef.current) {
      return;
    }
    if (loadMore && !hasMoreRef.current) {
      return;
    }

    try {
      isFetchingRef.current = true;
      if (!loadMore) {
        setIsLoading(true);
      }

      const response = await api.fetchVibes({
        limit: 15,
        cursor: loadMore ? cursorRef.current ?? '' : '',
      });

      const { posts, cursor: nextCursor } = normalizeVibesResponse(response);
      const mapped = mapPostsToVibes(posts);
      const hasMorePosts = Boolean(nextCursor && nextCursor !== '0' && nextCursor !== 'null' && nextCursor !== 'undefined');

      cursorRef.current = nextCursor;
      hasMoreRef.current = hasMorePosts;

      setVibes((prev) => {
        if (!loadMore) {
          return mapped;
        }
        const existingIds = new Set(prev.map((item) => item.id));
        return [...prev, ...mapped.filter((item) => !existingIds.has(item.id))];
      });
    } catch (error) {
      console.error('Vibes fetch failed', error);
      if (!loadMore) {
        const fallback = mapPostsToVibes(dummyVibes.data?.posts || []);
        setVibes(fallback);
        hasMoreRef.current = false;
        cursorRef.current = null;
      }
    } finally {
      if (!loadMore) {
        setIsLoading(false);
      }
      isFetchingRef.current = false;
    }
  }, []);

  useEffect(() => {
    void fetchVibesFromApi(false);
  }, [fetchVibesFromApi]);

  useEffect(() => {
    if (hasVibes) {
      setIsMediaLoading(true);
    }
  }, [activeIndex, hasVibes]);

  useEffect(() => {
    if (hasVibes && activeIndex >= vibes.length - 5) {
      void fetchVibesFromApi(true);
    }
  }, [activeIndex, fetchVibesFromApi, hasVibes, vibes.length]);

  useEffect(() => {
    if (!burstType) {
      return undefined;
    }
    const timeout = setTimeout(() => setBurstType(null), 900);
    return () => clearTimeout(timeout);
  }, [burstType]);

  const keyExtractor = useCallback((item: VibeItemData) => item.id, []);

  const getItemLayout = useCallback(
    (_: ArrayLike<VibeItemData> | null | undefined, index: number) => ({
      length: viewportHeight,
      offset: viewportHeight * index,
      index,
    }),
    [viewportHeight]
  );

  const handleMomentumEnd = useCallback(
    (event: NativeSyntheticEvent<NativeScrollEvent>) => {
      if (!viewportHeight) {
        return;
      }
      const nextIndex = Math.round(event.nativeEvent.contentOffset.y / viewportHeight);
      if (nextIndex !== activeIndex) {
        setActiveIndex(nextIndex);
      }
    },
    [activeIndex, viewportHeight]
  );

  const renderItem = useCallback(
    ({ item, index }: ListRenderItemInfo<VibeItemData>) => (
      <VibeItem
        vibe={item}
        isActive={index === activeIndex}
        isMuted={isMuted}
        viewportHeight={viewportHeight}
        bottomInset={insets.bottom + 84}
        onMediaReady={() => setIsMediaLoading(false)}
        onBurst={setBurstType}
      />
    ),
    [activeIndex, insets.bottom, isMuted, viewportHeight]
  );

  const loaderVisible = isLoading || isMediaLoading;
  const currentVibe = useMemo(() => vibes[activeIndex], [activeIndex, vibes]);

  return (
    <View
      style={styles.container}
      onLayout={(event) => {
        const nextHeight = Math.round(event.nativeEvent.layout.height);
        if (nextHeight && nextHeight !== viewportHeight) {
          setViewportHeight(nextHeight);
          requestAnimationFrame(() => {
            if (flatListRef.current && activeIndex > 0) {
              flatListRef.current.scrollToOffset({ offset: nextHeight * activeIndex, animated: false });
            }
          });
        }
      }}
    >
      {viewportHeight > 0 ? (
        <FlatList
          ref={flatListRef}
          data={vibes}
          renderItem={renderItem}
          keyExtractor={keyExtractor}
          pagingEnabled
          snapToInterval={viewportHeight}
          decelerationRate="fast"
          showsVerticalScrollIndicator={false}
          onMomentumScrollEnd={handleMomentumEnd}
          getItemLayout={getItemLayout}
          windowSize={3}
          initialNumToRender={2}
          maxToRenderPerBatch={3}
          removeClippedSubviews
        />
      ) : null}

      <View style={[styles.topControls, { top: insets.top + 14 }]} pointerEvents="box-none">
        <Pressable style={styles.muteButton} onPress={() => setIsMuted((value) => !value)}>
          <BlurView intensity={35} tint="dark" style={styles.muteButtonBlur}>
            {isMuted ? <VolumeX size={22} color="#FFFFFF" /> : <Volume2 size={22} color="#FFFFFF" />}
          </BlurView>
        </Pressable>
      </View>

      {loaderVisible ? (
        <View style={styles.loaderOverlay} pointerEvents="none">
          <BlurView intensity={35} tint="dark" style={styles.loaderCard}>
            <View style={styles.loaderIconWrap}>
              <ActivityIndicator size="large" color="rgba(255,255,255,0.75)" />
              <Sparkles size={18} color="#FFFFFF" style={styles.sparkles} />
            </View>
            <Text style={styles.loaderText}>Loading Vibes</Text>
          </BlurView>
        </View>
      ) : null}

      {!isLoading && !hasVibes ? (
        <View style={styles.emptyState}>
          <View style={styles.emptyIconBox}>
            <Sparkles size={34} color="#5A5A5A" />
          </View>
          <Text style={styles.emptyTitle}>No Vibes Found</Text>
          <Text style={styles.emptySubtitle}>Check back later for new discoveries.</Text>
        </View>
      ) : null}

      <BurstOverlay type={burstType} />

      {currentVibe == null && !isLoading ? <View style={styles.blackFill} /> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000000',
  },
  topControls: {
    position: 'absolute',
    right: 18,
    zIndex: 20,
  },
  muteButton: {
    borderRadius: 28,
    overflow: 'hidden',
  },
  muteButtonBlur: {
    width: 52,
    height: 52,
    borderRadius: 26,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(0,0,0,0.32)',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'rgba(255,255,255,0.14)',
  },
  loaderOverlay: {
    ...StyleSheet.absoluteFillObject,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(0,0,0,0.45)',
    zIndex: 40,
  },
  loaderCard: {
    width: 190,
    paddingHorizontal: 24,
    paddingVertical: 26,
    borderRadius: 28,
    alignItems: 'center',
    overflow: 'hidden',
  },
  loaderIconWrap: {
    width: 52,
    height: 52,
    alignItems: 'center',
    justifyContent: 'center',
  },
  sparkles: {
    position: 'absolute',
  },
  loaderText: {
    marginTop: 18,
    color: '#FFFFFF',
    fontSize: 14,
    fontFamily: 'Inter-Bold',
    letterSpacing: 2,
    textTransform: 'uppercase',
  },
  emptyState: {
    ...StyleSheet.absoluteFillObject,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 24,
    backgroundColor: '#000000',
    zIndex: 30,
  },
  emptyIconBox: {
    width: 84,
    height: 84,
    borderRadius: 30,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(24,24,24,0.92)',
    marginBottom: 20,
  },
  emptyTitle: {
    color: '#FFFFFF',
    fontSize: 22,
    fontFamily: 'Outfit-Black',
  },
  emptySubtitle: {
    color: '#7A7A7A',
    fontSize: 14,
    fontFamily: 'Inter-Medium',
    marginTop: 8,
  },
  blackFill: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: '#000000',
  },
});
