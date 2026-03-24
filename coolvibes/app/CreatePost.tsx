import React, { useCallback, useRef, useState } from 'react';
import { View, Text, StyleSheet, StatusBar, ActivityIndicator } from 'react-native';
import { useTheme } from '@react-navigation/native';
import { useRouter } from 'expo-router';

import ChatInput from '@/components/ChatInput';
import { api } from '@/services/apiService';
import { useAppSelector } from '@/store/hooks';

function plainTextToLexicalState(text: string): string {
  const safe = String(text ?? '').replace(/\r\n/g, '\n');
  const lines = safe.split('\n');

  const paragraphs = lines.map((line) => ({
    children: line
      ? [
          {
            detail: 0,
            format: 0,
            mode: 'normal',
            style: '',
            text: line,
            type: 'text',
            version: 1,
          },
        ]
      : [],
    direction: null,
    format: '',
    indent: 0,
    type: 'paragraph',
    version: 1,
    textFormat: 0,
    textStyle: '',
  }));

  return JSON.stringify({
    root: {
      children: paragraphs,
      direction: null,
      format: '',
      indent: 0,
      type: 'root',
      version: 1,
    },
  });
}

export default function CreatePostScreen() {
  const { colors, dark } = useTheme();
  const router = useRouter();
  const authUser = useAppSelector((state) => state.auth.user);
  const sendingRef = useRef(false);
  const [sending, setSending] = useState(false);

  const handleSendPost = useCallback(
    async (text: string, media: any[] = []) => {
      const trimmed = String(text ?? '').trim();
      const outgoingMedia = Array.isArray(media) ? media : [];
      if (!trimmed && outgoingMedia.length === 0) return;
      if (sendingRef.current) return;

      sendingRef.current = true;
      setSending(true);

      try {
        const payload: Record<string, any> = {
          content: plainTextToLexicalState(trimmed),
          audience: 'public',
        };

        const imageFiles: any[] = [];

        outgoingMedia.forEach((item: any, index: number) => {
          const uri = typeof item?.uri === 'string' ? item.uri : '';
          if (!uri) return;

          if (item?.type === 'image') {
            imageFiles.push({
              uri,
              name: item?.name || `post-image-${Date.now()}-${index}.jpg`,
              type: item?.mimeType || 'image/jpeg',
            });
          }
        });

        if (imageFiles.length > 0) payload['images[]'] = imageFiles;

        await api.createPost(payload);

        router.replace({
          pathname: '/(tabs)',
          params: { refresh_cool: String(Date.now()) },
        });
      } catch {
        // apiService already reports the error globally.
      } finally {
        sendingRef.current = false;
        setSending(false);
      }
    },
    [router]
  );

  return (
    <View style={[styles.container, { backgroundColor: colors.background }]}>
      <StatusBar barStyle={dark ? 'light-content' : 'dark-content'} />

      <View style={styles.spacer} />

      <View style={styles.inputWrap}>
        <ChatInput
          kind="post"
          autoFocus
          currentUser={authUser}
          replyingTo={null}
          editingMessage={null}
          onCancelReply={() => null}
          onCancelEdit={() => null}
          onSendMessage={handleSendPost}
        />
      </View>

      {sending && (
        <View style={[styles.loadingOverlay, { backgroundColor: dark ? 'rgba(0,0,0,0.32)' : 'rgba(255,255,255,0.42)' }]}>
          <View style={[styles.loadingCard, { backgroundColor: dark ? '#0F0F0F' : '#FFFFFF' }]}>
            <ActivityIndicator size="small" color={colors.text} />
            <Text style={[styles.loadingText, { color: colors.text }]}>Posting...</Text>
          </View>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  spacer: {
    flex: 1,
  },
  inputWrap: {
    width: '100%',
  },
  loadingOverlay: {
    ...StyleSheet.absoluteFillObject,
    alignItems: 'center',
    justifyContent: 'center',
  },
  loadingCard: {
    minWidth: 120,
    borderRadius: 18,
    paddingHorizontal: 18,
    paddingVertical: 16,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 10,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.12,
    shadowRadius: 16,
    elevation: 6,
  },
  loadingText: {
    fontSize: 13,
    fontFamily: 'Inter-SemiBold',
  },
});
