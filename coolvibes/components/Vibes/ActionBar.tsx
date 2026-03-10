import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { Image } from 'expo-image';
import { BlurView } from 'expo-blur';
import * as Haptics from 'expo-haptics';
import { Heart, MessageCircle, Plus } from 'lucide-react-native';

import type { BurstType } from './types';

interface ActionBarProps {
  avatarUrl: string;
  onLike: () => void;
  onMessage: () => void;
  onOpenProfile: () => void;
  onBurst: (type: BurstType) => void;
}

interface ActionButtonProps {
  icon: React.ComponentType<{ size?: number; color?: string; strokeWidth?: number }>;
  label: string;
  onPress: () => void;
}

const ActionButton = ({ icon: Icon, label, onPress }: ActionButtonProps) => (
  <Pressable onPress={onPress} style={styles.actionButton} hitSlop={10}>
    <BlurView intensity={34} tint="dark" style={styles.actionButtonBlur}>
      <Icon size={30} color="#FFFFFF" strokeWidth={2.2} />
    </BlurView>
    <Text style={styles.actionLabel}>{label}</Text>
  </Pressable>
);

export function ActionBar({ avatarUrl, onLike, onMessage, onOpenProfile, onBurst }: ActionBarProps) {
  const handleLike = () => {
    void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    onLike();
    onBurst('like');
  };

  const handleMessage = () => {
    void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    onMessage();
  };

  const handleOpenProfile = () => {
    void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    onOpenProfile();
  };

  return (
    <View style={styles.container}>
      <Pressable onPress={handleOpenProfile} style={styles.avatarWrap} hitSlop={10}>
        <Image source={{ uri: avatarUrl }} style={styles.avatar} contentFit="cover" />
        <View style={styles.followBadge}>
          <Plus size={14} color="#FFFFFF" strokeWidth={3} />
        </View>
      </Pressable>
      <ActionButton icon={Heart} label="Like" onPress={handleLike} />
      <ActionButton icon={MessageCircle} label="Message" onPress={handleMessage} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    gap: 14,
  },
  avatarWrap: {
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 0,
  },
  avatar: {
    width: 56,
    height: 56,
    borderRadius: 28,
    borderWidth: 2,
    borderColor: '#FFFFFF',
    backgroundColor: '#2A2A2A',
  },
  followBadge: {
    position: 'absolute',
    bottom: -2,
    width: 22,
    height: 22,
    borderRadius: 11,
    backgroundColor: '#F43F5E',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 2,
    borderColor: '#000000',
  },
  actionButton: {
    alignItems: 'center',
    gap: 6,
  },
  actionButtonBlur: {
    width: 56,
    height: 56,
    borderRadius: 28,
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
    backgroundColor: 'rgba(0,0,0,0.3)',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'rgba(255,255,255,0.16)',
  },
  actionLabel: {
    color: '#FFFFFF',
    fontSize: 10,
    fontFamily: 'Inter-SemiBold',
    letterSpacing: 0.4,
    textTransform: 'uppercase',
  },
});
