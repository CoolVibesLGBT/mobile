import React, { useCallback, useRef } from 'react';
import { View, StyleSheet, StatusBar } from 'react-native';
import { useTheme } from '@react-navigation/native';
import { useRouter } from 'expo-router';

import ChatInput from '@/components/ChatInput';
import { api } from '@/services/apiService';
import { useAppDispatch, useAppSelector } from '@/store/hooks';
import { completePostUpload, enqueuePostUpload, failPostUpload } from '@/store/slice/postUploads';

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
  const dispatch = useAppDispatch();
  const authUser = useAppSelector((state) => state.auth.user);
  const sendingRef = useRef(false);

  const handleSendPost = useCallback(
    (text: string, media: any[] = []) => {
      const trimmed = String(text ?? '').trim();
      const outgoingMedia = Array.isArray(media) ? media : [];
      if (!trimmed && outgoingMedia.length === 0) return;
      if (sendingRef.current) return;

      sendingRef.current = true;
      const uploadId = `post-${Date.now()}`;
      let queued = false;

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

        const descriptionParts: string[] = [];
        if (trimmed) descriptionParts.push(trimmed.slice(0, 80));
        if (imageFiles.length > 0) {
          descriptionParts.push(imageFiles.length === 1 ? '1 gorsel' : `${imageFiles.length} gorsel`);
        }

        dispatch(enqueuePostUpload({
          id: uploadId,
          title: 'Cool post gonderiliyor',
          description: descriptionParts.join(' • '),
        }));
        queued = true;

        if (router.canGoBack()) {
          router.back();
        } else {
          router.replace('/(tabs)');
        }

        void api.createPost(payload)
          .then(() => {
            dispatch(completePostUpload({ id: uploadId }));
          })
          .catch((error: any) => {
            const message = typeof error?.response?.data?.message === 'string'
              ? error.response.data.message
              : typeof error?.message === 'string'
                ? error.message
                : 'Post gonderilemedi';
            dispatch(failPostUpload({ id: uploadId, message }));
          })
          .finally(() => {
            sendingRef.current = false;
          });
      } catch (error: any) {
        sendingRef.current = false;
        const message = typeof error?.message === 'string' ? error.message : 'Post gonderilemedi';
        dispatch(failPostUpload({ id: queued ? uploadId : `post-failed-${Date.now()}`, message }));
      }
    },
    [dispatch, router]
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
});
