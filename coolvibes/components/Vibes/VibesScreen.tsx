import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  ActivityIndicator,
  Dimensions,
  FlatList,
  LayoutChangeEvent,
  Platform,
  Pressable,
  StyleSheet,
  Text,
  View,
  ViewToken,
} from 'react-native';
import { BlurView } from 'expo-blur';
import * as Localization from 'expo-localization';
import * as SecureStore from 'expo-secure-store';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Sparkles, Volume2, VolumeX } from 'lucide-react-native';

import { api } from '@/services/apiService';
import { defaultServiceServerId, serviceURL } from '@/config';
import { getSafeImageURL, getSafeImageURLEx } from '@/helpers/safeUrl';
import { toSafeBioHtml } from '@/helpers/lexicalPlainText';

import { BurstOverlay, VibeItem } from './VibeItem';
import type { BurstType, VibeItemData } from './types';

const dummyVibes = require('@/mock/dummy_vibes.json') as {
  data?: { posts?: unknown[] };
};

const { height: SCREEN_HEIGHT } = Dimensions.get('window');

function coerceLocalizedText(value: unknown): string {
  if (typeof value === 'string') {
    return value;
  }
  if (!value || typeof value !== 'object') {
    return '';
  }

  const record = value as Record<string, unknown>;
  const languageCode = Localization.getLocales?.()?.[0]?.languageCode;
  const regionCode = Localization.getLocales?.()?.[0]?.regionCode;

  const candidates = [languageCode, languageCode && regionCode ? `${languageCode}-${regionCode}` : null, 'en'].filter(Boolean) as string[];

  for (const key of candidates) {
    const v = record[key];
    if (typeof v === 'string' && v.trim()) {
      return v;
    }
  }

  for (const v of Object.values(record)) {
    if (typeof v === 'string' && v.trim()) {
      return v;
    }
  }

  return '';
}

function normalizeVibesResponse(response: any): { posts: any[]; cursor: string | null } {
  const payload = response?.data ?? response ?? {};
  const posts = Array.isArray(payload?.posts) ? payload.posts : [];
  const rawCursor = payload?.cursor ?? response?.cursor ?? null;
  return {
    posts,
    cursor: rawCursor != null ? String(rawCursor) : null,
  };
}

function toAbsoluteServiceUrl(path: string): string {
  if (!path) return '';
  if (path.startsWith('http')) return path;

  const serviceUri = serviceURL[defaultServiceServerId];
  const cleanPath = path.startsWith('./') ? path.substring(2) : path;
  try {
    return new URL(cleanPath.startsWith('/') ? cleanPath : `/${cleanPath}`, serviceUri).href;
  } catch {
    return '';
  }
}

function pickVariantUrl(variants: any, key: string): string {
  const value = variants?.[key];
  if (!value) return '';
  if (typeof value === 'string') return value;
  if (typeof value === 'object' && value) {
    const url = (value as any).url ?? (value as any).uri;
    return typeof url === 'string' ? url : '';
  }
  return '';
}

function getBestVideoUrl(attachment: any, file: any): string {
  const videoVariants = attachment?.file?.variants?.video || attachment?.variants?.video;

  const candidatePaths = [
    pickVariantUrl(videoVariants, 'high'),
    pickVariantUrl(videoVariants, 'medium'),
    pickVariantUrl(videoVariants, 'low'),
    pickVariantUrl(videoVariants, 'preview'),
    pickVariantUrl(videoVariants, 'original'),
  ].filter(Boolean) as string[];

  for (const path of candidatePaths) {
    const url = toAbsoluteServiceUrl(path);
    if (url) return url;
  }

  const topUrl = file?.url || attachment?.file?.url || attachment?.url;
  if (typeof topUrl === 'string' && topUrl) {
    const url = toAbsoluteServiceUrl(topUrl);
    if (url) return url;
  }

  if (file?.storage_path) {
    const serviceUri = serviceURL[defaultServiceServerId];
    const path = String(file.storage_path).replace(/^\.\//, '');
    return `${serviceUri}/${path}`;
  }

  return '';
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
        mediaUrl = getBestVideoUrl(attachment, file);
        posterUrl = getSafeImageURL(attachment, 'poster') || getSafeImageURL(attachment, 'original') || '';
      } else {
        // Prefer JPG/PNG originals on mobile (more compatible than webp for GL and some decoders).
        mediaUrl =
          getSafeImageURL(attachment, 'original') ||
          getSafeImageURL(attachment, 'large') ||
          getSafeImageURL(attachment, 'medium') ||
          getSafeImageURL(attachment, 'small') ||
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
        bio: coerceLocalizedText(author.bio) || '',
        bioHtml: toSafeBioHtml(coerceLocalizedText(author.bio)) || '',
        author,
      };
    })
    .filter((item) => Boolean(item.id && item.mediaUrl));
}

interface VibesScreenProps {
  /**
   * Extra bottom padding to keep overlays (username/actions) above an absolute tab bar.
   * If the screen is already laid out between header + tab bar, pass 0.
   */
  overlayBottomInset?: number;
}

export default function VibesScreen({ overlayBottomInset }: VibesScreenProps) {
  const insets = useSafeAreaInsets();
  const listRef = useRef<FlatList<VibeItemData> | null>(null);
  const cursorRef = useRef<string | null>(null);
  const hasMoreRef = useRef(true);
  const isFetchingRef = useRef(false);
  const loadedMediaIdsRef = useRef<Set<string>>(new Set());

  const [vibes, setVibes] = useState<VibeItemData[]>([]);
  const [activeIndex, setActiveIndex] = useState(0);
  const [isMuted, setIsMuted] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [isMediaLoading, setIsMediaLoading] = useState(false);
  const [burstType, setBurstType] = useState<BurstType | null>(null);
  const [viewportHeight, setViewportHeight] = useState(SCREEN_HEIGHT);
  const [authToken, setAuthToken] = useState<string | null>(null);

  const hasVibes = vibes.length > 0;
  const currentVibe = useMemo(() => vibes[activeIndex], [activeIndex, vibes]);
  const mediaHeaders = useMemo(() => (authToken ? { Authorization: authToken } : undefined), [authToken]);
  const tabBarHeight = useMemo(
    () => (Platform.OS === 'ios' ? 62 : 66) + Math.max(insets.bottom, 8),
    [insets.bottom]
  );
  const overlayInset = overlayBottomInset ?? tabBarHeight;
  const topChromeInset = useMemo(() => 60 + insets.top + 64 + 1, [insets.top]);

  useEffect(() => {
    let mounted = true;
    const load = async () => {
      try {
        const token =
          Platform.OS === 'web' ? localStorage.getItem('authToken') : await SecureStore.getItemAsync('authToken');
        if (mounted) setAuthToken(token);
      } catch {
        // Ignore.
      }
    };
    void load();
    return () => {
      mounted = false;
    };
  }, []);

  const fetchVibesFromApi = useCallback(async (loadMore = false) => {
    if (isFetchingRef.current) return;
    if (loadMore && !hasMoreRef.current) return;

    try {
      isFetchingRef.current = true;
      if (!loadMore) {
        setIsLoading(true);
        loadedMediaIdsRef.current = new Set();
        setActiveIndex(0);
        listRef.current?.scrollToOffset({ offset: 0, animated: false });
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
        if (!loadMore) return mapped;
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
      if (!loadMore) setIsLoading(false);
      isFetchingRef.current = false;
    }
  }, []);

  useEffect(() => {
    void fetchVibesFromApi(false);
  }, [fetchVibesFromApi]);

  useEffect(() => {
    if (!hasVibes) {
      setIsMediaLoading(false);
      return;
    }
    const currentId = vibes[activeIndex]?.id;
    setIsMediaLoading(currentId ? !loadedMediaIdsRef.current.has(currentId) : false);
  }, [activeIndex, hasVibes, vibes]);

  useEffect(() => {
    if (hasVibes && activeIndex >= vibes.length - 5) {
      void fetchVibesFromApi(true);
    }
  }, [activeIndex, fetchVibesFromApi, hasVibes, vibes.length]);

  useEffect(() => {
    if (!burstType) return;
    const timeout = setTimeout(() => setBurstType(null), 900);
    return () => clearTimeout(timeout);
  }, [burstType]);

  const viewabilityConfigRef = useRef({ itemVisiblePercentThreshold: 80 });
  const onViewableItemsChangedRef = useRef(({ viewableItems }: { viewableItems: ViewToken[] }) => {
    const first = viewableItems.find((v) => v.isViewable);
    if (first?.index != null) {
      setActiveIndex(first.index);
    }
  });

  const handleLayout = (event: LayoutChangeEvent) => {
    const nextHeight = event.nativeEvent.layout.height;
    if (nextHeight > 0 && Math.abs(nextHeight - viewportHeight) > 1) {
      setViewportHeight(Math.round(nextHeight));
    }
  };

  const renderItem = useCallback(
    ({ item, index }: { item: VibeItemData; index: number }) => (
      <VibeItem
        vibe={item}
        isActive={index === activeIndex}
        isMuted={isMuted}
        viewportHeight={viewportHeight}
        topInset={topChromeInset}
        bottomInset={overlayInset}
        mediaHeaders={mediaHeaders}
        onMediaReady={() => {
          loadedMediaIdsRef.current.add(item.id);
          if (index === activeIndex) {
            setIsMediaLoading(false);
          }
        }}
        onBurst={setBurstType}
      />
    ),
    [activeIndex, isMuted, mediaHeaders, overlayInset, topChromeInset, viewportHeight]
  );

  const showInitialLoader = isLoading && !hasVibes;
  const showMediaLoader = isMediaLoading && hasVibes;

  return (
    <View style={styles.container} onLayout={handleLayout}>
      {hasVibes ? (
        <FlatList
          ref={(ref) => {
            listRef.current = ref;
          }}
          data={vibes}
          keyExtractor={(item) => item.id}
          renderItem={renderItem}
          // Full-bleed paging: don't let iOS inject safe-area/top insets that break snap height.
          contentInsetAdjustmentBehavior="never"
          pagingEnabled
          snapToInterval={viewportHeight}
          snapToAlignment="start"
          decelerationRate="fast"
          bounces={false}
          overScrollMode="never"
          showsVerticalScrollIndicator={false}
          viewabilityConfig={viewabilityConfigRef.current}
          onViewableItemsChanged={onViewableItemsChangedRef.current}
          initialNumToRender={3}
          maxToRenderPerBatch={3}
          windowSize={5}
          removeClippedSubviews
          getItemLayout={(_, index) => ({
            length: viewportHeight,
            offset: viewportHeight * index,
            index,
          })}
          extraData={activeIndex}
        />
      ) : null}

      <View style={[styles.topControls, { top: 10 }]} pointerEvents="box-none">
        <Pressable style={styles.muteButton} onPress={() => setIsMuted((value) => !value)}>
          <BlurView intensity={35} tint="dark" style={styles.muteButtonBlur}>
            {isMuted ? <VolumeX size={22} color="#FFFFFF" /> : <Volume2 size={22} color="#FFFFFF" />}
          </BlurView>
        </Pressable>
      </View>

      {showInitialLoader ? (
        <View style={[styles.loaderTopWrap, { top: 10 }]} pointerEvents="none">
          <BlurView intensity={35} tint="dark" style={styles.loaderPill}>
            <ActivityIndicator size="small" color="#FFFFFF" />
            <Text style={styles.loaderPillText}>Loading vibes</Text>
          </BlurView>
        </View>
      ) : null}

      {showMediaLoader ? (
        <View style={[styles.loaderTopWrap, { top: 10 }]} pointerEvents="none">
          <BlurView intensity={30} tint="dark" style={styles.loaderDot}>
            <ActivityIndicator size="small" color="#FFFFFF" />
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
      {__DEV__ && currentVibe ? (
        <View style={[styles.devHud, { top: 70 }]} pointerEvents="none">
          <Text style={styles.devHudText}>
            {`vibes=${vibes.length} idx=${activeIndex} mediaLoading=${isMediaLoading ? '1' : '0'} type=${currentVibe.mediaType}`}
          </Text>
        </View>
      ) : null}
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
    zIndex: 44,
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
  loaderTopWrap: {
    position: 'absolute',
    left: 0,
    right: 0,
    alignItems: 'center',
    zIndex: 42,
  },
  loaderPill: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 7,
    paddingHorizontal: 12,
    height: 32,
    borderRadius: 16,
    backgroundColor: 'rgba(12,12,12,0.5)',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'rgba(255,255,255,0.14)',
    overflow: 'hidden',
  },
  loaderPillText: {
    color: '#FFFFFF',
    fontSize: 11,
    fontFamily: 'Inter-SemiBold',
    letterSpacing: 0.25,
    textTransform: 'uppercase',
  },
  loaderDot: {
    width: 30,
    height: 30,
    borderRadius: 15,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(12,12,12,0.44)',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'rgba(255,255,255,0.12)',
    overflow: 'hidden',
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
  devHud: {
    position: 'absolute',
    left: 12,
    right: 12,
    zIndex: 50,
    paddingHorizontal: 10,
    paddingVertical: 8,
    borderRadius: 12,
    backgroundColor: 'rgba(0,0,0,0.55)',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'rgba(255,255,255,0.14)',
  },
  devHudText: {
    color: 'rgba(255,255,255,0.85)',
    fontSize: 11,
    fontFamily: 'Inter-SemiBold',
  },
});
