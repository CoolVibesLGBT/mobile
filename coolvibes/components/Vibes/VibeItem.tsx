import React, { useEffect, useMemo, useState } from 'react';
import { Pressable, StyleSheet, Text, View, useWindowDimensions } from 'react-native';
import { BlurView } from 'expo-blur';
import { Image } from 'expo-image';
import { LinearGradient } from 'expo-linear-gradient';
import { useVideoPlayer, VideoView } from 'expo-video';
import { useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import RenderHTML from 'react-native-render-html';

import { api } from '@/services/apiService';
import { calculateAge } from '@/helpers/safeUrl';

import { ActionBar } from './ActionBar';
import type { BurstType, VibeItemData } from './types';

interface VibeItemProps {
  vibe: VibeItemData;
  isActive: boolean;
  isMuted: boolean;
  viewportHeight: number;
  bottomInset: number;
  onMediaReady: () => void;
  onBurst: (type: BurstType) => void;
}

function VideoMedia({
  uri,
  posterUrl,
  isActive,
  isMuted,
  onReady,
}: {
  uri: string;
  posterUrl?: string;
  isActive: boolean;
  isMuted: boolean;
  onReady: () => void;
}) {
  const [hasFirstFrame, setHasFirstFrame] = useState(false);
  const player = useVideoPlayer(uri, (instance) => {
    instance.loop = true;
    instance.muted = isMuted;
  });

  useEffect(() => {
    player.muted = isMuted;
  }, [isMuted, player]);

  useEffect(() => {
    if (isActive) {
      player.play();
    } else {
      player.pause();
    }
  }, [isActive, player]);

  useEffect(() => {
    if (hasFirstFrame && isActive) {
      onReady();
    }
  }, [hasFirstFrame, isActive, onReady]);

  return (
    <View style={styles.mediaFill}>
      {!hasFirstFrame && posterUrl ? (
        <Image source={{ uri: posterUrl }} style={styles.mediaFill} contentFit="cover" />
      ) : null}
      <VideoView
        player={player}
        style={styles.mediaFill}
        contentFit="cover"
        nativeControls={false}
        allowsFullscreen={false}
        onFirstFrameRender={() => {
          setHasFirstFrame(true);
          if (isActive) {
            onReady();
          }
        }}
      />
    </View>
  );
}

export function VibeItem({
  vibe,
  isActive,
  isMuted,
  viewportHeight,
  bottomInset,
  onMediaReady,
  onBurst,
}: VibeItemProps) {
  const router = useRouter();
  const { width } = useWindowDimensions();
  const [imageLoaded, setImageLoaded] = useState(false);

  useEffect(() => {
    setImageLoaded(false);
  }, [vibe.id]);

  useEffect(() => {
    if (vibe.mediaType === 'image' && imageLoaded && isActive) {
      onMediaReady();
    }
  }, [imageLoaded, isActive, onMediaReady, vibe.mediaType]);

  const age = useMemo(() => {
    if (!vibe.dateOfBirth) {
      return null;
    }
    const value = calculateAge(vibe.dateOfBirth);
    return typeof value === 'number' ? value : null;
  }, [vibe.dateOfBirth]);

  const handleLike = async () => {
    try {
      await api.handlePostLike(vibe.id);
    } catch (error) {
      console.error('Vibes like failed', error);
    }
  };

  const handleMessage = async () => {
    const userId = vibe.author.id;
    if (!userId) {
      return;
    }

    try {
      const response = await api.createChat([userId]);
      const chatId = (response as { chat?: { id?: string } })?.chat?.id ?? userId;
      router.push({
        pathname: '/ChatDetail',
        params: {
          chatId,
          name: vibe.author.displayname || vibe.username,
          avatar: vibe.avatar,
          status: 'online',
        },
      });
    } catch (error) {
      console.error('Vibes create chat failed', error);
      router.push({
        pathname: '/ChatDetail',
        params: {
          chatId: userId,
          name: vibe.author.displayname || vibe.username,
          avatar: vibe.avatar,
          status: 'online',
        },
      });
    }
  };

  const handleOpenProfile = () => {
    void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    router.push({
      pathname: '/(tabs)/Profile',
      params: {
        publicId: vibe.author.public_id ?? '',
        username: vibe.author.username ?? vibe.username,
      },
    });
  };

  return (
    <View style={[styles.page, { height: viewportHeight }]}> 
      <View style={styles.mediaFill}>
        {vibe.mediaType === 'video' ? (
          <VideoMedia
            uri={vibe.mediaUrl}
            posterUrl={vibe.posterUrl}
            isActive={isActive}
            isMuted={isMuted}
            onReady={onMediaReady}
          />
        ) : (
          <Image
            source={{ uri: vibe.mediaUrl }}
            style={styles.mediaFill}
            contentFit="cover"
            onLoadEnd={() => {
              setImageLoaded(true);
              if (isActive) {
                onMediaReady();
              }
            }}
          />
        )}
      </View>

      <LinearGradient
        colors={['transparent', 'rgba(0,0,0,0.2)', 'rgba(0,0,0,0.78)']}
        locations={[0.5, 0.72, 1]}
        style={styles.gradient}
      />

      <View style={[styles.overlay, { paddingBottom: bottomInset + 18 }]}> 
        <View style={styles.infoColumn} pointerEvents="box-none">
          <Pressable onPress={handleOpenProfile} hitSlop={10}>
            <Text style={styles.username}>
              {vibe.username}
              {age ? <Text style={styles.age}> {age}</Text> : null}
            </Text>
          </Pressable>
          {!!vibe.bioHtml ? (
            <RenderHTML
              contentWidth={Math.max(0, width * 0.7 - 20)}
              source={{ html: vibe.bioHtml }}
              baseStyle={styles.bio}
              defaultTextProps={{ selectable: false }}
            />
          ) : null}
          {!vibe.bio && !!vibe.description && <Text style={styles.bio}>{vibe.description}</Text>}
        </View>

        <View style={styles.actionsWrap}>
          <ActionBar
            avatarUrl={vibe.avatar}
            onLike={() => {
              void handleLike();
            }}
            onMessage={() => {
              void handleMessage();
            }}
            onOpenProfile={handleOpenProfile}
            onBurst={onBurst}
          />
        </View>
      </View>
    </View>
  );
}

export function BurstOverlay({ type }: { type: BurstType | null }) {
  if (!type) {
    return null;
  }

  const accent = type === 'like' ? '#EF4444' : '#EAB308';
  const label = type === 'like' ? 'LIKED' : 'BLOCKED';

  return (
    <View pointerEvents="none" style={styles.burstRoot}>
      <BlurView intensity={35} tint="dark" style={styles.burstBackdrop}>
        <LinearGradient
          colors={['rgba(0,0,0,0.12)', `${accent}55`, 'rgba(0,0,0,0.12)']}
          start={{ x: 0.5, y: 0 }}
          end={{ x: 0.5, y: 1 }}
          style={styles.burstBackdrop}
        />
      </BlurView>
      <View style={styles.burstCenter}>
        <View style={[styles.burstIconWrap, { shadowColor: accent }]}> 
          <Text style={[styles.burstIcon, { color: accent }]}>{type === 'like' ? '♥' : '×'}</Text>
        </View>
        <Text style={styles.burstLabel}>{label}</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  page: {
    width: '100%',
    backgroundColor: '#000000',
  },
  mediaFill: {
    ...StyleSheet.absoluteFillObject,
  },
  gradient: {
    ...StyleSheet.absoluteFillObject,
  },
  overlay: {
    ...StyleSheet.absoluteFillObject,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-end',
    paddingHorizontal: 18,
  },
  infoColumn: {
    flex: 1,
    paddingRight: 16,
  },
  username: {
    color: '#FFFFFF',
    fontSize: 30,
    fontFamily: 'Outfit-Black',
    lineHeight: 34,
  },
  age: {
    fontSize: 24,
    fontFamily: 'Outfit-Regular',
  },
  bio: {
    color: 'rgba(255,255,255,0.85)',
    fontSize: 14,
    lineHeight: 20,
    fontFamily: 'Inter-Medium',
    marginTop: 8,
    maxWidth: 260,
  },
  actionsWrap: {
    alignSelf: 'flex-end',
    paddingBottom: 4,
  },
  burstRoot: {
    ...StyleSheet.absoluteFillObject,
    zIndex: 50,
    alignItems: 'center',
    justifyContent: 'center',
  },
  burstBackdrop: {
    ...StyleSheet.absoluteFillObject,
  },
  burstCenter: {
    alignItems: 'center',
    justifyContent: 'center',
    gap: 18,
  },
  burstIconWrap: {
    width: 150,
    height: 150,
    borderRadius: 75,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(255,255,255,0.08)',
    shadowOpacity: 0.45,
    shadowRadius: 30,
    shadowOffset: { width: 0, height: 0 },
  },
  burstIcon: {
    fontSize: 76,
    lineHeight: 88,
    fontFamily: 'Outfit-Black',
  },
  burstLabel: {
    color: '#FFFFFF',
    fontSize: 28,
    letterSpacing: 6,
    fontFamily: 'Inter-Bold',
  },
});
