import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  ActivityIndicator,
  LayoutChangeEvent,
  PanResponder,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { BlurView } from 'expo-blur';
import { Image } from 'expo-image';
import * as Localization from 'expo-localization';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Sparkles, Volume2, VolumeX } from 'lucide-react-native';
import { useVideoPlayer, VideoView } from 'expo-video';

import { api } from '@/services/apiService';
import { defaultServiceServerId, serviceURL } from '@/config';
import { getSafeImageURL, getSafeImageURLEx } from '@/helpers/safeUrl';
import { toSafeBioHtml } from '@/helpers/lexicalPlainText';

import { BurstOverlay } from './VibeItem';
import { VibeDetailsOverlay } from './VibeDetailsOverlay';
import { VibesGLRenderer } from './VibesGLRenderer';
import type { BurstType, VibeItemData } from './types';

const dummyVibes = require('@/mock/dummy_vibes.json') as {
  data?: { posts?: unknown[] };
};

type PositionState = {
  current: number;
  target: number;
  velocity: number;
};

type TransitionState = {
  fromIndex: number;
  toIndex: number;
  progress: number;
  direction: -1 | 0 | 1;
};

function coerceLocalizedText(value: unknown): string {
  if (typeof value === 'string') {
    return value;
  }
  if (!value || typeof value !== 'object') {
    return '';
  }

  const record = value as Record<string, unknown>;
  const languageCode = Localization.getLocales?.()?.[0]?.languageCode;

  const candidates = [
    languageCode,
    languageCode ? `${languageCode}-${Localization.getLocales?.()?.[0]?.regionCode ?? ''}` : null,
    'en',
  ].filter(Boolean) as string[];

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

function coerceBioText(value: unknown): string {
  const localized = coerceLocalizedText(value);
  if (!localized) {
    return '';
  }
  return localized;
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
        bio: coerceBioText(author.bio) || '',
        bioHtml: toSafeBioHtml(coerceLocalizedText(author.bio)) || '',
        author,
      };
    })
    .filter((item) => Boolean(item.id && item.mediaUrl));
}

function MediaPoster({ vibe, opacity = 1, translateY = 0 }: { vibe: VibeItemData; opacity?: number; translateY?: number }) {
  const sourceUri = vibe.mediaType === 'video' ? vibe.posterUrl || vibe.mediaUrl : vibe.mediaUrl;
  return (
    <Image
      source={{ uri: sourceUri }}
      style={[StyleSheet.absoluteFillObject, { opacity, transform: [{ translateY }] }]}
      contentFit="cover"
      cachePolicy="memory-disk"
    />
  );
}

function ActiveVideoMedia({ vibe, isMuted, onReady }: { vibe: VibeItemData; isMuted: boolean; onReady: () => void }) {
  const [videoReady, setVideoReady] = useState(false);
  const player = useVideoPlayer(vibe.mediaUrl, (instance) => {
    instance.loop = true;
    instance.muted = isMuted;
  });

  useEffect(() => {
    setVideoReady(false);
  }, [vibe.id]);

  useEffect(() => {
    player.muted = isMuted;
  }, [isMuted, player]);

  useEffect(() => {
    try {
      player.play();
    } catch (error) {
      console.warn('Vibes video play failed', error);
    }

    return () => {};
  }, [player, vibe.id]);

  useEffect(() => {
    if (videoReady) {
      onReady();
    }
  }, [onReady, videoReady]);

  return (
    <View style={StyleSheet.absoluteFillObject}>
      {!videoReady && vibe.posterUrl ? <MediaPoster vibe={vibe} /> : null}
      <VideoView
        player={player}
        style={StyleSheet.absoluteFillObject}
        contentFit="cover"
        nativeControls={false}
        fullscreenOptions={{ enable: false }}
        onFirstFrameRender={() => {
          setVideoReady(true);
          onReady();
        }}
      />
    </View>
  );
}

function ActiveImageMedia({ vibe, onReady }: { vibe: VibeItemData; onReady: () => void }) {
  return (
    <Image
      source={{ uri: vibe.mediaUrl }}
      style={StyleSheet.absoluteFillObject}
      contentFit="cover"
      cachePolicy="memory-disk"
      onLoadEnd={onReady}
    />
  );
}

function ActiveMedia({ vibe, isMuted, onReady }: { vibe: VibeItemData; isMuted: boolean; onReady: () => void }) {
  if (vibe.mediaType === 'video') {
    return <ActiveVideoMedia vibe={vibe} isMuted={isMuted} onReady={onReady} />;
  }
  return <ActiveImageMedia vibe={vibe} onReady={onReady} />;
}

export default function VibesScreen() {
  const insets = useSafeAreaInsets();
  const cursorRef = useRef<string | null>(null);
  const hasMoreRef = useRef(true);
  const isFetchingRef = useRef(false);
  const animationFrameRef = useRef<number>(0);
  const loadedMediaIdsRef = useRef<Set<string>>(new Set());
  const positionRef = useRef<PositionState>({ current: 0, target: 0, velocity: 0 });
  const interactionRef = useRef({
    isDragging: false,
    lastY: 0,
    dragStartPos: 0,
    dragHistory: [] as { time: number; y: number }[],
  });
  const transitionStateRef = useRef<TransitionState>({
    fromIndex: 0,
    toIndex: 0,
    progress: 0,
    direction: 0,
  });

  const [vibes, setVibes] = useState<VibeItemData[]>([]);
  const [activeIndex, setActiveIndex] = useState(0);
  const [isMuted, setIsMuted] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [isMediaLoading, setIsMediaLoading] = useState(false);
  const [burstType, setBurstType] = useState<BurstType | null>(null);
  const [viewportHeight, setViewportHeight] = useState(0);
  const [transitionState, setTransitionState] = useState<TransitionState>({
    fromIndex: 0,
    toIndex: 0,
    progress: 0,
    direction: 0,
  });

  const hasVibes = vibes.length > 0;
  const currentVibe = useMemo(() => vibes[activeIndex], [activeIndex, vibes]);
  const transitionFromVibe = vibes[transitionState.fromIndex];
  const transitionToVibe = vibes[transitionState.toIndex];
  const isTransitioning = transitionState.direction !== 0 && transitionState.fromIndex !== transitionState.toIndex;
  const isSettled = transitionState.direction === 0 || transitionState.fromIndex === transitionState.toIndex;

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
          if (mapped.length === 0) {
            setIsMediaLoading(false);
          }
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
        setIsMediaLoading(false);
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
    if (!burstType) {
      return undefined;
    }
    const timeout = setTimeout(() => setBurstType(null), 900);
    return () => clearTimeout(timeout);
  }, [burstType]);

  useEffect(() => {
    if (!hasVibes) {
      return undefined;
    }

    let mounted = true;
    let lastActiveIndex = -1;
    let lastTime = 0;

    const tick = (time: number) => {
      if (!mounted) {
        return;
      }

      const pos = positionRef.current;

      if (!interactionRef.current.isDragging) {
        if (lastTime === 0) {
          lastTime = time;
        }
        const deltaTime = Math.min(0.05, (time - lastTime) * 0.001);
        lastTime = time;
        const stiffness = 150;
        const damping = 26;
        const force = (pos.target - pos.current) * stiffness;
        const dampingForce = -pos.velocity * damping;
        const acceleration = force + dampingForce;
        pos.velocity += acceleration * deltaTime;
        pos.current += pos.velocity * deltaTime;

        if (Math.abs(pos.target - pos.current) < 0.0005 && Math.abs(pos.velocity) < 0.0005) {
          pos.current = pos.target;
          pos.velocity = 0;
        }
      }

      pos.current = Math.max(0, Math.min(vibes.length - 1, pos.current));

      let nextTransition: TransitionState;
      const p = pos.current;
      const fromIndex = Math.max(0, Math.min(vibes.length - 1, Math.floor(p)));
      const toIndex = Math.max(0, Math.min(vibes.length - 1, Math.ceil(p)));
      const progress = p - fromIndex;
      const direction: -1 | 0 | 1 = fromIndex === toIndex ? 0 : pos.velocity >= 0 ? 1 : -1;
      nextTransition = { fromIndex, toIndex, progress, direction };
      const prevTransition = transitionStateRef.current;
      const shouldUpdateTransition =
        prevTransition.fromIndex !== nextTransition.fromIndex ||
        prevTransition.toIndex !== nextTransition.toIndex ||
        prevTransition.direction !== nextTransition.direction ||
        Math.abs(prevTransition.progress - nextTransition.progress) > 0.002;

      if (shouldUpdateTransition) {
        transitionStateRef.current = nextTransition;
        setTransitionState(nextTransition);
      }

      const nextActiveIndex = Math.max(0, Math.min(vibes.length - 1, Math.round(pos.current)));
      if (nextActiveIndex !== lastActiveIndex) {
        lastActiveIndex = nextActiveIndex;
        setActiveIndex(nextActiveIndex);
      }

      animationFrameRef.current = requestAnimationFrame(tick);
    };

    animationFrameRef.current = requestAnimationFrame(tick);
    return () => {
      mounted = false;
      if (animationFrameRef.current) {
        cancelAnimationFrame(animationFrameRef.current);
      }
    };
  }, [hasVibes, vibes]);

  const snapToNearest = useCallback(() => {
    const history = interactionRef.current.dragHistory;
    const first = history[0];
    const last = history[history.length - 1];

    if (first && last) {
      const duration = last.time - first.time;
      const distance = last.y - first.y;
      if (duration > 20 && Math.abs(distance) > 10) {
        positionRef.current.velocity = (distance / duration) * -0.8;
      }
    }

    const projectedTarget = positionRef.current.current + positionRef.current.velocity * 0.2;
    let newTarget = Math.round(projectedTarget);
    newTarget = Math.max(0, Math.min(vibes.length - 1, newTarget));
    positionRef.current.target = newTarget;
  }, [vibes.length]);

  const panResponder = useMemo(
    () =>
      PanResponder.create({
        onMoveShouldSetPanResponder: (_, gestureState) => Math.abs(gestureState.dy) > 4,
        onPanResponderGrant: (_, gestureState) => {
          interactionRef.current.isDragging = true;
          interactionRef.current.lastY = gestureState.y0;
          interactionRef.current.dragStartPos = positionRef.current.current;
          interactionRef.current.dragHistory = [{ time: Date.now(), y: gestureState.y0 }];
          positionRef.current.velocity = 0;
        },
        onPanResponderMove: (_, gestureState) => {
          const now = Date.now();
          interactionRef.current.lastY = gestureState.moveY;
          positionRef.current.current = interactionRef.current.dragStartPos - gestureState.dy * 0.0045;
          positionRef.current.current = Math.max(0, Math.min(vibes.length - 1, positionRef.current.current));
          positionRef.current.target = positionRef.current.current;
          interactionRef.current.dragHistory.push({ time: now, y: gestureState.moveY });
          if (interactionRef.current.dragHistory.length > 5) {
            interactionRef.current.dragHistory.shift();
          }
        },
        onPanResponderRelease: () => {
          interactionRef.current.isDragging = false;
          snapToNearest();
        },
        onPanResponderTerminate: () => {
          interactionRef.current.isDragging = false;
          snapToNearest();
        },
      }),
    [snapToNearest, vibes.length]
  );

  const showInitialLoader = isLoading && !hasVibes;
  const showMediaLoader = isMediaLoading && hasVibes;
  const fromTranslateY = transitionState.direction === 1 ? -transitionState.progress * viewportHeight : transitionState.progress * viewportHeight;
  const toTranslateY = transitionState.direction === 1 ? (1 - transitionState.progress) * viewportHeight : -(1 - transitionState.progress) * viewportHeight;

  const handleLayout = (event: LayoutChangeEvent) => {
    setViewportHeight(event.nativeEvent.layout.height);
  };

  return (
    <View style={styles.container} onLayout={handleLayout} {...panResponder.panHandlers}>
      {hasVibes ? <VibesGLRenderer vibes={vibes} positionRef={positionRef} opacity={1} /> : null}

      {currentVibe && isSettled ? (
        <ActiveMedia
          vibe={currentVibe}
          isMuted={isMuted}
          onReady={() => {
            loadedMediaIdsRef.current.add(currentVibe.id);
            setIsMediaLoading(false);
          }}
        />
      ) : null}

      {viewportHeight > 0 && isTransitioning && transitionFromVibe ? (
        <MediaPoster vibe={transitionFromVibe} translateY={fromTranslateY} opacity={0} />
      ) : null}
      {viewportHeight > 0 && isTransitioning && transitionToVibe ? (
        <MediaPoster vibe={transitionToVibe} translateY={toTranslateY} opacity={0} />
      ) : null}

      <View style={[styles.topControls, { top: insets.top + 10 }]} pointerEvents="box-none">
        <Pressable style={styles.muteButton} onPress={() => setIsMuted((value) => !value)}>
          <BlurView intensity={35} tint="dark" style={styles.muteButtonBlur}>
            {isMuted ? <VolumeX size={22} color="#FFFFFF" /> : <Volume2 size={22} color="#FFFFFF" />}
          </BlurView>
        </Pressable>
      </View>

      {currentVibe ? <VibeDetailsOverlay vibe={currentVibe} bottomInset={insets.bottom + 74} onBurst={setBurstType} /> : null}

      {showInitialLoader ? (
        <View style={[styles.loaderTopWrap, { top: insets.top + 10 }]} pointerEvents="none">
          <BlurView intensity={35} tint="dark" style={styles.loaderPill}>
            <ActivityIndicator size="small" color="#FFFFFF" />
            <Text style={styles.loaderPillText}>Loading vibes</Text>
          </BlurView>
        </View>
      ) : null}

      {showMediaLoader ? (
        <View style={[styles.loaderTopWrap, { top: insets.top + 10 }]} pointerEvents="none">
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
});
