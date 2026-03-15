import React, { useMemo } from 'react';
import { Pressable, StyleSheet, Text, View, useWindowDimensions } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import RenderHTML from 'react-native-render-html';

import { api } from '@/services/apiService';
import { calculateAge } from '@/helpers/safeUrl';
import { encodeProfileParam } from '@/helpers/profile';

import { ActionBar } from './ActionBar';
import type { BurstType, VibeItemData } from './types';

interface VibeDetailsOverlayProps {
  vibe: VibeItemData;
  bottomInset: number;
  onBurst: (type: BurstType) => void;
}

export function VibeDetailsOverlay({ vibe, bottomInset, onBurst }: VibeDetailsOverlayProps) {
  const router = useRouter();
  const { width } = useWindowDimensions();

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
          username: vibe.author.username || vibe.username,
          avatar: vibe.avatar,
          status: 'online',
          profile: encodeProfileParam(vibe.author),
        },
      });
    } catch (error) {
      console.error('Vibes create chat failed', error);
      router.push({
        pathname: '/ChatDetail',
        params: {
          chatId: userId,
          name: vibe.author.displayname || vibe.username,
          username: vibe.author.username || vibe.username,
          avatar: vibe.avatar,
          status: 'online',
          profile: encodeProfileParam(vibe.author),
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
    <>
      <LinearGradient
        colors={['transparent', 'rgba(0,0,0,0.2)', 'rgba(0,0,0,0.78)']}
        locations={[0.5, 0.72, 1]}
        style={StyleSheet.absoluteFillObject}
        pointerEvents="none"
      />
      <View style={[styles.overlay, { paddingBottom: bottomInset }]} pointerEvents="box-none">
        <View style={styles.infoColumn} pointerEvents="box-none">
          {!!vibe.bioHtml ? (
            <RenderHTML
              contentWidth={Math.max(0, width * 0.7 - 20)}
              source={{ html: vibe.bioHtml }}
              baseStyle={styles.bio}
              defaultTextProps={{ selectable: false }}
            />
          ) : null}
          <Pressable onPress={handleOpenProfile} hitSlop={10}>
            <Text style={styles.username}>
              {vibe.username}
              {age ? <Text style={styles.age}> {age}</Text> : null}
            </Text>
          </Pressable>
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
    </>
  );
}

const styles = StyleSheet.create({
  overlay: {
    ...StyleSheet.absoluteFillObject,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-end',
    paddingHorizontal: 16,
    zIndex: 20,
  },
  infoColumn: {
    flex: 1,
    maxWidth: '70%',
    justifyContent: 'flex-end',
    paddingRight: 20,
    paddingBottom: 8,
  },
  username: {
    color: '#FFFFFF',
    fontSize: 27,
    fontFamily: 'Outfit-Black',
    lineHeight: 32,
    letterSpacing: 0.1,
    marginTop: 7,
  },
  age: {
    fontSize: 20,
    fontFamily: 'Outfit-Regular',
  },
  bio: {
    color: 'rgba(255,255,255,0.85)',
    fontSize: 13,
    lineHeight: 20,
    fontFamily: 'Inter-Medium',
    marginBottom: 2,
  },
  actionsWrap: {
    alignSelf: 'flex-end',
    paddingBottom: 14,
  },
});
