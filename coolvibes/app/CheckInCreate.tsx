import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { ActivityIndicator, View, Text, StyleSheet, KeyboardAvoidingView, Platform, StatusBar } from 'react-native';
import { useTheme } from '@react-navigation/native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';

import { CheckInRadar } from '@/components/CheckInBar';
import ChatInput from '@/components/ChatInput';
import { useAppSelector } from '@/store/hooks';
import { getCurrentLocation } from '@/utils/location';
import { LocalizedStringToString } from '@/utils/utils';
import { getSafeImageURLEx } from '@/helpers/safeUrl';
import { getTagGradient } from '@/helpers/colors';
import { composeLexicalState } from '@/helpers/plainTextToLexicalState';
import { applyComposerMediaToPayload } from '@/helpers/postComposer';
import { api } from '@/services/apiService';

const DEFAULT_COORDS = { latitude: 41.0082, longitude: 28.9784 };
const GLOBAL_HEADER_HEIGHT = 60;

type DraftCheckinItem = {
  id: string;
  user: {
    name: string;
    username: string;
    avatar: string;
  };
  image?: string;
  caption: string;
  likes: number;
  comments: number;
  time: string;
  tags: string[];
  latitude?: number;
  longitude?: number;
};

const encodeDraftCheckin = (value: DraftCheckinItem) => {
  try {
    return encodeURIComponent(JSON.stringify(value));
  } catch {
    return undefined;
  }
};

const getCreatedCheckinPost = (response: any) => {
  const body = response?.data ?? response ?? {};
  return body?.post ?? body?.checkin ?? body?.data?.post ?? body?.data?.checkin ?? null;
};

export default function CheckInCreateScreen() {
  const { colors, dark } = useTheme();
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const authUser = useAppSelector((state) => state.auth.user);
  const systemData = useAppSelector((state) => state.system.data);
  const language = useAppSelector((state) => state.system.language) || authUser?.default_language || 'en';
  const [selectedTags, setSelectedTags] = useState<string[]>([]);
  const [userLocation, setUserLocation] = useState(DEFAULT_COORDS);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);
  const sendingRef = useRef(false);

  useEffect(() => {
    let active = true;

    const loadLocation = async () => {
      try {
        const coords = await getCurrentLocation();
        if (active) setUserLocation(coords);
      } catch {
        if (active) setUserLocation(DEFAULT_COORDS);
      }
    };

    loadLocation();

    return () => {
      active = false;
    };
  }, []);

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
    return selectedTags.map((tagKey) => {
      const tag = tagMap.get(tagKey);
      const label = tag?.name ? LocalizedStringToString(tag.name, language) : tagKey;
      const gradient = getTagGradient(tag?.tag ?? tagKey);

      return {
        type: 'tag' as const,
        name: label,
        icon: tag?.icon,
        gradient,
        data: { tag: tagKey, label, gradient },
      };
    });
  }, [selectedTags, tagMap, language]);

  const handleRemoveTagAttachment = useCallback((media: any) => {
    const tagKey = media?.data?.tag || media?.name;
    if (!tagKey) return;
    setSelectedTags((prev) => prev.filter((item) => item !== tagKey));
  }, []);

  const handleSelectTag = useCallback((tag: string) => {
    setSelectedTags((prev) => (
      prev.includes(tag) ? prev.filter((item) => item !== tag) : [...prev, tag]
    ));
  }, []);

  const handleClearTags = useCallback(() => {
    setSelectedTags([]);
  }, []);

  const handleSendMessage = useCallback(async (text: string, media: any[]) => {
    if (sendingRef.current) return;
    const trimmed = text?.trim?.() ?? '';
    const outgoingMedia = Array.isArray(media) ? media : [];
    const mediaImage = outgoingMedia.find((item: any) => item?.type === 'image' && item?.uri)?.uri;
    const hasTags = selectedTags.length > 0;

    if (!trimmed && !mediaImage && !hasTags) return;

    sendingRef.current = true;
    setIsSubmitting(true);
    setSubmitError(null);

    const name = authUser?.displayname || authUser?.username || 'You';
    const username = authUser?.username || 'you';
    const avatar =
      getSafeImageURLEx(authUser?.public_id ?? authUser?.id ?? username, authUser?.avatar, 'small') ||
      `https://i.pravatar.cc/150?u=${username}`;

    const payload: Record<string, any> = {
      content: composeLexicalState(trimmed || 'Check-in', outgoingMedia),
      audience: 'public',
      tags: selectedTags,
      extras: { tags: selectedTags },
      lat: userLocation.latitude,
      lng: userLocation.longitude,
      latitude: userLocation.latitude,
      longitude: userLocation.longitude,
    };
    applyComposerMediaToPayload(payload, outgoingMedia, 'checkin');

    try {
      const response: any = await api.createCheckIn(payload);
      const body = response?.data ?? response ?? {};
      if (response?.success === false || body?.success === false) {
        throw new Error(response?.message || body?.message || 'Check-in gonderilemedi');
      }

      const createdPost = getCreatedCheckinPost(response);
      const draftItem: DraftCheckinItem = {
        id: String(createdPost?.public_id ?? createdPost?.id ?? Date.now()),
        user: { name, username, avatar },
        image: mediaImage,
        caption: trimmed || 'Check-in',
        likes: 0,
        comments: 0,
        time: 'Just now',
        tags: [...selectedTags],
        latitude: userLocation.latitude,
        longitude: userLocation.longitude,
      };

      const encodedDraft = encodeDraftCheckin(draftItem);

      router.replace({
        pathname: '/(tabs)/CheckIn',
        params: encodedDraft ? { draft_checkin: encodedDraft } : undefined,
      });
    } catch (error) {
      console.error('Failed to create check-in', error);
      setSubmitError('Check-in gonderilemedi. Lutfen tekrar dene.');
    } finally {
      sendingRef.current = false;
      setIsSubmitting(false);
    }
  }, [authUser, router, selectedTags, userLocation.latitude, userLocation.longitude]);

  return (
    <View style={[styles.container, { backgroundColor: colors.background }]}>
      <StatusBar barStyle={dark ? 'light-content' : 'dark-content'} />

      <View style={[styles.header, { paddingTop: GLOBAL_HEADER_HEIGHT + insets.top + 10 }]}>
        <Text style={[styles.title, { color: colors.text }]}>Check-in</Text>
        <Text style={[styles.subtitle, { color: dark ? '#666' : '#888' }]}>
          Durumunu sec ve paylas
        </Text>
      </View>

      {(isSubmitting || submitError) ? (
        <View
          style={[
            styles.submitBanner,
            {
              backgroundColor: dark ? 'rgba(255,255,255,0.06)' : 'rgba(15,23,42,0.06)',
              borderColor: dark ? 'rgba(255,255,255,0.10)' : 'rgba(15,23,42,0.08)',
            },
          ]}
        >
          {isSubmitting ? <ActivityIndicator size="small" color={colors.text} /> : null}
          <Text style={[styles.submitBannerText, { color: submitError ? '#EF4444' : colors.text }]}>
            {submitError || 'Check-in gonderiliyor...'}
          </Text>
        </View>
      ) : null}

      <View style={styles.honeycombWrap}>
        <CheckInRadar
          selectedTags={selectedTags}
          onSelectTag={handleSelectTag}
          onClearTags={handleClearTags}
          centerOffsetY={-24}
        />
        <View style={[styles.hintPill, { backgroundColor: dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.06)' }]}>
          <Text style={[styles.hintText, { color: dark ? '#777' : '#888' }]}>SURUKLE & SEC</Text>
        </View>
      </View>

      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        keyboardVerticalOffset={Platform.OS === 'ios' ? 90 : 0}
        style={[styles.inputWrap, { paddingBottom: insets.bottom + 12 }]}
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
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    paddingHorizontal: 20,
    paddingBottom: 10,
  },
  title: {
    fontSize: 18,
    fontFamily: 'Outfit-Black',
    letterSpacing: 0.2,
  },
  subtitle: {
    marginTop: 4,
    fontSize: 12,
    fontFamily: 'Inter-Medium',
  },
  submitBanner: {
    marginHorizontal: 20,
    marginBottom: 8,
    minHeight: 40,
    borderRadius: 14,
    borderWidth: StyleSheet.hairlineWidth,
    paddingHorizontal: 12,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  submitBannerText: {
    flex: 1,
    fontSize: 12,
    lineHeight: 16,
    fontFamily: 'Inter-SemiBold',
  },
  honeycombWrap: {
    flex: 1,
    justifyContent: 'center',
  },
  hintPill: {
    position: 'absolute',
    bottom: 16,
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
  inputWrap: {
    width: '100%',
  },
});
