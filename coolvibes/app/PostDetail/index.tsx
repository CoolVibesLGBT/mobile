import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { ActivityIndicator, FlatList, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { useTheme } from '@react-navigation/native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useLocalSearchParams } from 'expo-router';
import { Image } from 'expo-image';
import * as Localization from 'expo-localization';

import ChatInput from '@/components/ChatInput';
import { api } from '@/services/apiService';
import { lexicalToPlainText } from '@/helpers/lexicalPlainText';
import { getSafeImageURL, getSafeImageURLEx } from '@/helpers/safeUrl';
import { useAppSelector } from '@/store/hooks';

type CommentItem = {
  id: string;
  user: {
    name: string;
    username: string;
    avatar: string;
  };
  text: string;
  time: string;
  raw?: any;
};

function coerceLocalizedText(value: unknown): string {
  if (typeof value === 'string') return value;
  if (!value || typeof value !== 'object') return '';

  const record = value as Record<string, unknown>;
  const languageCode = Localization.getLocales?.()?.[0]?.languageCode;
  const regionCode = Localization.getLocales?.()?.[0]?.regionCode;

  const candidates = [
    languageCode,
    languageCode && regionCode ? `${languageCode}-${regionCode}` : null,
    'en',
  ].filter(Boolean) as string[];

  for (const key of candidates) {
    const v = record[key];
    if (typeof v === 'string' && v.trim()) return v;
  }

  for (const v of Object.values(record)) {
    if (typeof v === 'string' && v.trim()) return v;
  }

  return '';
}

function normalizePostFetchResponse(response: any): any | null {
  const payload = response?.data ?? response ?? null;
  if (!payload) return null;

  const data = payload?.data ?? payload ?? null;
  const postCandidate =
    data?.post ??
    payload?.post ??
    data?.item ??
    payload?.item ??
    data?.data?.post ??
    payload?.data?.post ??
    null;

  const pick = (value: any) => {
    if (!value || typeof value !== 'object') return null;
    if ('public_id' in value || 'id' in value) return value;
    return null;
  };

  return pick(postCandidate) || pick(data) || pick(payload);
}

function formatRelativeTime(value: unknown): string {
  if (typeof value !== 'string') return '';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '';

  const delta = Date.now() - date.getTime();
  const minutes = Math.floor(delta / 60000);
  const hours = Math.floor(delta / 3600000);
  const days = Math.floor(delta / 86400000);

  if (minutes < 1) return 'just now';
  if (minutes < 60) return `${minutes} min ago`;
  if (hours < 24) return `${hours} hours ago`;
  if (days < 7) return `${days} days ago`;
  return date.toLocaleDateString();
}

function extractFirstImageAltTextFromLexical(input: unknown): string {
  if (typeof input !== 'string') return '';
  const trimmed = input.trim();
  if (!trimmed.startsWith('{')) return '';
  try {
    const parsed = JSON.parse(trimmed) as any;
    const stack: any[] = [parsed?.root ?? parsed];
    let guard = 0;
    while (stack.length && guard < 600) {
      guard += 1;
      const node = stack.pop();
      if (!node || typeof node !== 'object') continue;
      if (node.type === 'image' && typeof node.altText === 'string' && node.altText.trim()) {
        return node.altText.trim();
      }
      const children = node.children;
      if (Array.isArray(children)) {
        for (let i = children.length - 1; i >= 0; i -= 1) stack.push(children[i]);
      }
    }
  } catch {
    // ignore parse errors
  }
  return '';
}

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

export default function PostDetailScreen() {
  const { colors, dark } = useTheme();
  const insets = useSafeAreaInsets();
  const params = useLocalSearchParams();
  const authUser = useAppSelector((state) => state.auth.user);

  const postIdParam = params?.postId;
  const postId = Array.isArray(postIdParam) ? postIdParam[0] : postIdParam;

  const [post, setPost] = useState<any | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const sendingRef = useRef(false);

  const fetchPost = useCallback(
    async ({ refresh = false }: { refresh?: boolean } = {}) => {
      if (!postId) {
        setError('Post not found');
        setLoading(false);
        return;
      }
      try {
        if (refresh) setRefreshing(true);
        else setLoading(true);
        setError(null);

        const response: any = await api.fetchPost(String(postId));
        const normalized = normalizePostFetchResponse(response);
        if (!normalized) {
          setPost(null);
          setError('Failed to load post');
          return;
        }
        setPost(normalized);
      } catch (e) {
        setPost(null);
        setError('Failed to load post');
      } finally {
        setLoading(false);
        setRefreshing(false);
      }
    },
    [postId]
  );

  useEffect(() => {
    void fetchPost();
  }, [fetchPost]);

  const header = useMemo(() => {
    if (!post) return null;
    const author = post?.author ?? post?.user ?? {};
    const seed = author?.public_id || author?.id || post?.author_id || post?.public_id || post?.id;
    const avatar = getSafeImageURLEx(seed, author?.avatar, 'small') || '';
    const attachments = Array.isArray(post?.attachments) ? post.attachments : [];
    const firstAttachment = attachments[0];
    const image =
      getSafeImageURL(firstAttachment, 'original') ||
      getSafeImageURL(firstAttachment, 'large') ||
      getSafeImageURL(firstAttachment, 'medium') ||
      getSafeImageURL(firstAttachment, 'small') ||
      undefined;

    const content = coerceLocalizedText(post?.content);
    const plain = lexicalToPlainText(content);
    const caption = (plain != null && plain.trim())
      ? plain.trim()
      : extractFirstImageAltTextFromLexical(content) || '';

    return {
      user: {
        name: author?.displayname || author?.username || 'User',
        username: author?.username || author?.displayname || 'user',
        avatar,
      },
      image,
      caption,
      time: formatRelativeTime(post?.created_at),
      raw: post,
    };
  }, [post]);

  const comments: CommentItem[] = useMemo(() => {
    const children = Array.isArray(post?.children) ? post.children : [];
    return children
      .map((child: any) => {
        const author = child?.author ?? child?.user ?? {};
        const seed = author?.public_id || author?.id || child?.author_id || child?.public_id || child?.id;
        const avatar = getSafeImageURLEx(seed, author?.avatar, 'icon') || '';
        const content = coerceLocalizedText(child?.content);
        const plain = lexicalToPlainText(content);
        const text =
          (plain != null && plain.trim())
            ? plain.trim()
            : extractFirstImageAltTextFromLexical(content) || '';
        const id = String(child?.public_id ?? child?.id ?? seed ?? Math.random());
        if (!id) return null;
        return {
          id,
          user: {
            name: author?.displayname || author?.username || 'User',
            username: author?.username || author?.displayname || 'user',
            avatar,
          },
          text,
          time: formatRelativeTime(child?.created_at),
          raw: child,
        } as CommentItem;
      })
      .filter(Boolean) as CommentItem[];
  }, [post]);

  const myUser = useMemo(() => {
    const avatar =
      getSafeImageURLEx(authUser?.id ?? authUser?.public_id, authUser?.avatar, 'small') ||
      getSafeImageURLEx(authUser?.id ?? authUser?.public_id, authUser?.avatar_url || authUser?.avatarUrl, 'small') ||
      '';
    return {
      id: authUser?.id || 'me',
      name: authUser?.displayname || authUser?.username || 'Me',
      avatarUrl: avatar,
    };
  }, [authUser]);

  const handleSendComment = useCallback(
    (text: string, media: any[] = []) => {
      if (!postId) return;
      const trimmed = String(text ?? '').trim();
      const outgoingMedia = Array.isArray(media) ? media : [];
      if (!trimmed && outgoingMedia.length === 0) return;
      if (sendingRef.current) return;
      sendingRef.current = true;

      (async () => {
        try {
          const basePayload: Record<string, any> = {
            content: plainTextToLexicalState(trimmed),
            audience: 'public',
            parentPostId: String(postId),
          };

          const imageFiles: any[] = [];
          const videoFiles: any[] = [];

          outgoingMedia.forEach((item: any, index: number) => {
            const uri = typeof item?.uri === 'string' ? item.uri : '';
            if (!uri) return;
            if (item?.type === 'image') {
              imageFiles.push({
                uri,
                name: item?.name || `comment-image-${Date.now()}-${index}.jpg`,
                type: 'image/jpeg',
              });
              return;
            }
            if (item?.type === 'video') {
              videoFiles.push({
                uri,
                name: item?.name || `comment-video-${Date.now()}-${index}.mp4`,
                type: 'video/mp4',
              });
            }
          });

          if (imageFiles.length > 0) basePayload.images = imageFiles;
          if (videoFiles.length > 0) basePayload.videos = videoFiles;

          await api.createPost(basePayload);
          await fetchPost({ refresh: true });
        } catch {
          // apiService already reports; keep UI stable
        } finally {
          sendingRef.current = false;
        }
      })();
    },
    [fetchPost, postId]
  );

  const divider = dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.06)';

  return (
    <View style={[styles.screen, { backgroundColor: colors.background }]}>
      <FlatList
        data={comments}
        keyExtractor={(item) => item.id}
        contentContainerStyle={{
          paddingTop: 60 + insets.top + 12,
          paddingBottom: 220 + Math.max(insets.bottom, 12),
        }}
        onRefresh={() => fetchPost({ refresh: true })}
        refreshing={refreshing}
        showsVerticalScrollIndicator={false}
        ListHeaderComponent={
              header ? (
            <View style={[styles.headerWrap, { borderBottomColor: divider }]}>
              <View style={styles.postHeaderRow}>
                {header.user.avatar ? (
                  <Image source={{ uri: header.user.avatar }} style={styles.avatar} contentFit="cover" />
                ) : (
                  <View style={styles.avatar} />
                )}
                <View style={{ flex: 1 }}>
                  <Text style={[styles.name, { color: colors.text }]} numberOfLines={1}>{header.user.name}</Text>
                  <Text style={[styles.username, { color: dark ? '#8E8E93' : '#666' }]} numberOfLines={1}>@{header.user.username}</Text>
                </View>
                {!!header.time && (
                  <Text style={[styles.time, { color: dark ? '#666' : '#999' }]}>{header.time}</Text>
                )}
              </View>

              {!!header.caption && (
                <Text style={[styles.caption, { color: colors.text }]}>{header.caption}</Text>
              )}

              {header.image ? (
                <Image
                  source={{ uri: header.image }}
                  style={[styles.postImage, { backgroundColor: dark ? '#1C1C1E' : '#F2F2F7' }]}
                  contentFit="cover"
                  transition={250}
                />
              ) : null}

              <View style={[styles.commentsHeaderRow, { borderTopColor: divider }]}>
                <Text style={[styles.commentsTitle, { color: colors.text }]}>
                  Comments
                </Text>
                <Text style={[styles.commentsCount, { color: dark ? '#8E8E93' : '#666' }]}>
                  {comments.length}
                </Text>
              </View>
            </View>
          ) : null
        }
        ListEmptyComponent={
          loading ? (
            <View style={[styles.stateWrap, header && styles.stateWrapTight]}>
              <ActivityIndicator size="small" color={colors.text} />
              <Text style={[styles.stateText, { color: dark ? '#777' : '#888' }]}>Loading post...</Text>
            </View>
          ) : error ? (
            <View style={[styles.stateWrap, header && styles.stateWrapTight]}>
              <Text style={[styles.stateText, { color: dark ? '#f87171' : '#dc2626' }]}>{error}</Text>
              <TouchableOpacity onPress={() => fetchPost()} style={styles.retryBtn} activeOpacity={0.85}>
                <Text style={[styles.retryText, { color: colors.text }]}>Retry</Text>
              </TouchableOpacity>
            </View>
          ) : (
            <View style={[styles.stateWrap, header && styles.stateWrapTight]}>
              <Text style={[styles.stateText, { color: dark ? '#777' : '#888' }]}>No comments yet.</Text>
            </View>
          )
        }
        renderItem={({ item }) => (
          <View style={[styles.commentRow, { borderBottomColor: divider }]}>
            {item.user.avatar ? (
              <Image source={{ uri: item.user.avatar }} style={styles.commentAvatar} contentFit="cover" />
            ) : (
              <View style={styles.commentAvatar} />
            )}
            <View style={{ flex: 1 }}>
              <View style={styles.commentTopRow}>
                <Text style={[styles.commentName, { color: colors.text }]} numberOfLines={1}>{item.user.name}</Text>
                {!!item.time && (
                  <Text style={[styles.commentTime, { color: dark ? '#666' : '#999' }]}>{item.time}</Text>
                )}
              </View>
              <Text style={[styles.commentText, { color: colors.text }]}>{item.text || ''}</Text>
            </View>
          </View>
        )}
      />

      <View style={[styles.inputDock, { paddingBottom: 0 }]}>
        <ChatInput
          kind="comment"
          currentUser={myUser}
          replyingTo={null}
          editingMessage={null}
          onCancelReply={() => {}}
          onCancelEdit={() => {}}
          onSendMessage={(text, media) => handleSendComment(text, media)}
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  headerWrap: {
    paddingHorizontal: 16,
    paddingBottom: 10,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  postHeaderRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingTop: 6,
    paddingBottom: 10,
    gap: 12,
  },
  avatar: { width: 38, height: 38, borderRadius: 19, backgroundColor: '#e5e7eb' },
  name: { fontSize: 15, fontFamily: 'Inter-Bold', letterSpacing: -0.3 },
  username: { fontSize: 12, fontFamily: 'Inter-SemiBold', marginTop: 1 },
  time: { fontSize: 11, fontFamily: 'Inter-Bold', textTransform: 'uppercase', letterSpacing: 0.4 },
  caption: { fontSize: 15, fontFamily: 'Inter-Regular', lineHeight: 20, paddingBottom: 10 },
  postImage: { width: '100%', aspectRatio: 1, borderRadius: 14, overflow: 'hidden' },
  commentsHeaderRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    borderTopWidth: StyleSheet.hairlineWidth,
    paddingTop: 12,
    marginTop: 14,
  },
  commentsTitle: { fontSize: 15, fontFamily: 'Inter-Bold' },
  commentsCount: { fontSize: 13, fontFamily: 'Inter-SemiBold' },
  commentRow: {
    flexDirection: 'row',
    gap: 12,
    paddingHorizontal: 16,
    paddingVertical: 14,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  commentAvatar: { width: 34, height: 34, borderRadius: 17, backgroundColor: '#e5e7eb' },
  commentTopRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 10 },
  commentName: { flex: 1, fontSize: 13, fontFamily: 'Inter-Bold' },
  commentTime: { fontSize: 11, fontFamily: 'Inter-Bold', letterSpacing: 0.3, textTransform: 'uppercase' },
  commentText: { marginTop: 3, fontSize: 14, fontFamily: 'Inter-Regular', lineHeight: 19, opacity: 0.95 },
  stateWrap: { paddingTop: 120, alignItems: 'center', paddingHorizontal: 24 },
  stateWrapTight: { paddingTop: 24 },
  stateText: { marginTop: 10, fontSize: 14, fontFamily: 'Inter-SemiBold', textAlign: 'center' },
  retryBtn: { marginTop: 14, paddingHorizontal: 16, paddingVertical: 10, borderRadius: 14, backgroundColor: 'rgba(127,127,127,0.12)' },
  retryText: { fontSize: 13, fontFamily: 'Inter-Bold' },
  inputDock: { position: 'absolute', left: 0, right: 0, bottom: 0 },
});
