import React, { useMemo } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';

import { api } from '@/services/apiService';
import { calculateAge } from '@/helpers/safeUrl';

import { ActionBar } from './ActionBar';
import type { BurstType, VibeItemData } from './types';

interface VibeDetailsOverlayProps {
  vibe: VibeItemData;
  bottomInset: number;
  onBurst: (type: BurstType) => void;
}

export function VibeDetailsOverlay({ vibe, bottomInset, onBurst }: VibeDetailsOverlayProps) {
  const router = useRouter();

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
    <>
      <LinearGradient
        colors={['transparent', 'rgba(0,0,0,0.2)', 'rgba(0,0,0,0.78)']}
        locations={[0.5, 0.72, 1]}
        style={StyleSheet.absoluteFillObject}
      />
      <View style={[styles.overlay, { paddingBottom: bottomInset + 18 }]}> 
        <View style={styles.infoColumn} pointerEvents="box-none">
          <Pressable onPress={handleOpenProfile} hitSlop={10}>
            <Text style={styles.username}>
              {vibe.username}
              {age ? <Text style={styles.age}> {age}</Text> : null}
            </Text>
          </Pressable>
          {!!vibe.bio && <Text style={styles.bio}>{vibe.bio}</Text>}
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
    </>
  );
}

const styles = StyleSheet.create({
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
});
