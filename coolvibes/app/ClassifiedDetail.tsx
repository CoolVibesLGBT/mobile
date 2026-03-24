import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  ActivityIndicator,
  FlatList,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import { useTheme } from '@react-navigation/native';
import { useLocalSearchParams } from 'expo-router';
import { Image } from 'expo-image';

import ChatInput from '@/components/ChatInput';
import {
  extractClassifiedDetailResponse,
  formatRelativeTime,
  kindToClassifiedTab,
  normalizeClassifiedPost,
} from '@/helpers/classifieds';
import { lexicalToPlainText } from '@/helpers/lexicalPlainText';
import { plainTextToLexicalState } from '@/helpers/plainTextToLexicalState';
import { getSafeImageURLEx } from '@/helpers/safeUrl';
import { api } from '@/services/apiService';
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
};

function coerceCommentText(value: unknown): string {
  if (typeof value === 'string') {
    const plain = lexicalToPlainText(value);
    return plain?.trim() || value;
  }

  if (value && typeof value === 'object') {
    const record = value as Record<string, unknown>;
    for (const localized of Object.values(record)) {
      if (typeof localized === 'string') {
        const plain = lexicalToPlainText(localized);
        if (plain?.trim()) return plain.trim();
        if (localized.trim()) return localized.trim();
      }
    }
  }

  return '';
}

export default function ClassifiedDetailScreen() {
  const { colors, dark } = useTheme();
  const params = useLocalSearchParams<{ postId?: string }>();
  const authUser = useAppSelector((state) => state.auth.user);
  const sendingRef = useRef(false);

  const postIdParam = Array.isArray(params.postId) ? params.postId[0] : params.postId;

  const [post, setPost] = useState<any | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState('');

  const borderColor = dark ? 'rgba(255,255,255,0.08)' : 'rgba(15,23,42,0.08)';
  const mutedText = dark ? 'rgba(255,255,255,0.58)' : 'rgba(15,23,42,0.58)';
  const cardBackground = dark ? 'rgba(255,255,255,0.04)' : '#FFFFFF';
  const surfaceBackground = dark ? 'rgba(255,255,255,0.06)' : '#F8FAFC';

  const fetchDetail = useCallback(
    async ({ refresh = false }: { refresh?: boolean } = {}) => {
      if (!postIdParam) {
        setError('Listing not found.');
        setLoading(false);
        return;
      }

      try {
        if (refresh) setRefreshing(true);
        else setLoading(true);

        setError('');
        const response = await api.fetchClassified(String(postIdParam));
        const resolved = extractClassifiedDetailResponse(response);
        if (!resolved) {
          setPost(null);
          setError('Listing could not be loaded.');
          return;
        }

        setPost(resolved);
      } catch {
        setPost(null);
        setError('Listing could not be loaded.');
      } finally {
        setLoading(false);
        setRefreshing(false);
      }
    },
    [postIdParam]
  );

  useEffect(() => {
    void fetchDetail();
  }, [fetchDetail]);

  const classified = useMemo(() => normalizeClassifiedPost(post), [post]);

  const comments = useMemo<CommentItem[]>(() => {
    const children = Array.isArray(post?.children) ? post.children : [];

    return children
      .map((child: any) => {
        const author = child?.author ?? child?.user ?? {};
        const seed = author?.public_id || author?.id || child?.author_id || child?.public_id || child?.id;
        const id = String(child?.public_id ?? child?.id ?? '');
        if (!id) return null;

        return {
          id,
          user: {
            name: author?.displayname || author?.username || 'User',
            username: author?.username || author?.displayname || 'user',
            avatar: getSafeImageURLEx(seed, author?.avatar, 'icon') || '',
          },
          text: coerceCommentText(child?.content),
          time: formatRelativeTime(child?.created_at),
        };
      })
      .filter(Boolean) as CommentItem[];
  }, [post]);

  const currentUser = useMemo(() => ({
    id: authUser?.id || 'me',
    name: authUser?.displayname || authUser?.username || 'Me',
    avatarUrl: getSafeImageURLEx(authUser?.id ?? authUser?.public_id, authUser?.avatar, 'small') || '',
  }), [authUser]);

  const handleSendComment = useCallback(
    (text: string, media: any[] = []) => {
      if (!postIdParam || sendingRef.current) return;

      const trimmed = String(text ?? '').trim();
      const outgoingMedia = Array.isArray(media) ? media : [];
      if (!trimmed && outgoingMedia.length === 0) return;

      sendingRef.current = true;

      const payload: Record<string, any> = {
        content: plainTextToLexicalState(trimmed),
        audience: 'public',
        parentPostId: String(postIdParam),
      };

      const imageFiles: any[] = [];
      const videoFiles: any[] = [];

      outgoingMedia.forEach((item: any, index: number) => {
        const uri = typeof item?.uri === 'string' ? item.uri : '';
        if (!uri) return;

        if (item?.type === 'image') {
          imageFiles.push({
            uri,
            name: item?.name || `classified-comment-image-${Date.now()}-${index}.jpg`,
            type: item?.mimeType || 'image/jpeg',
          });
          return;
        }

        if (item?.type === 'video') {
          videoFiles.push({
            uri,
            name: item?.name || `classified-comment-video-${Date.now()}-${index}.mp4`,
            type: item?.mimeType || 'video/mp4',
          });
        }
      });

      if (imageFiles.length > 0) payload['images[]'] = imageFiles;
      if (videoFiles.length > 0) payload['videos[]'] = videoFiles;

      void api.createPost(payload)
        .then(() => fetchDetail({ refresh: true }))
        .finally(() => {
          sendingRef.current = false;
        });
    },
    [fetchDetail, postIdParam]
  );

  return (
    <View style={[styles.container, { backgroundColor: colors.background }]}>
      <FlatList
        data={comments}
        keyExtractor={(item) => item.id}
        showsVerticalScrollIndicator={false}
        refreshing={refreshing}
        onRefresh={() => {
          void fetchDetail({ refresh: true });
        }}
        contentContainerStyle={styles.listContent}
        ListHeaderComponent={
          classified ? (
            <View style={styles.headerSection}>
              <View style={[styles.heroCard, { backgroundColor: cardBackground, borderColor }]}>
                <View style={styles.heroTopRow}>
                  <View
                    style={[
                      styles.kindBadge,
                      {
                        backgroundColor: kindToClassifiedTab(classified.kind) === 'seeking' ? '#E0F2FE' : '#DCFCE7',
                      },
                    ]}
                  >
                    <Text
                      style={[
                        styles.kindBadgeText,
                        {
                          color: kindToClassifiedTab(classified.kind) === 'seeking' ? '#0369A1' : '#166534',
                        },
                      ]}
                    >
                      {kindToClassifiedTab(classified.kind) === 'seeking' ? 'Seeking' : 'Hiring'}
                    </Text>
                  </View>
                  {!!classified.time && (
                    <Text style={[styles.timeText, { color: mutedText }]}>{classified.time}</Text>
                  )}
                </View>

                <Text style={[styles.title, { color: colors.text }]}>{classified.title}</Text>

                <View style={styles.authorRow}>
                  {classified.author.avatar ? (
                    <Image source={{ uri: classified.author.avatar }} style={styles.authorAvatar} contentFit="cover" />
                  ) : (
                    <View style={[styles.authorAvatar, { backgroundColor: surfaceBackground }]} />
                  )}
                  <View style={{ flex: 1 }}>
                    <Text style={[styles.authorName, { color: colors.text }]} numberOfLines={1}>
                      {classified.author.name}
                    </Text>
                    <Text style={[styles.authorUsername, { color: mutedText }]} numberOfLines={1}>
                      @{classified.author.username}
                    </Text>
                  </View>
                </View>

                {!!classified.excerpt && (
                  <Text style={[styles.excerpt, { color: colors.text }]}>{classified.excerpt}</Text>
                )}

                {classified.image ? (
                  <Image source={{ uri: classified.image }} style={styles.heroImage} contentFit="cover" transition={180} />
                ) : null}
              </View>

              {classified.metadata.length > 0 ? (
                <View style={[styles.metadataSection, { backgroundColor: cardBackground, borderColor }]}>
                  <Text style={[styles.metadataTitle, { color: colors.text }]}>Details</Text>
                  <View style={styles.metadataList}>
                    {classified.metadata.map((entry, index) => (
                      <View
                        key={`${classified.id}-${entry.key}-${index}`}
                        style={[
                          styles.metadataRow,
                          {
                            borderBottomColor: borderColor,
                            borderBottomWidth: index < classified.metadata.length - 1 ? StyleSheet.hairlineWidth : 0,
                          },
                        ]}
                      >
                        <Text style={[styles.metadataRowKey, { color: mutedText }]}>{entry.key}</Text>
                        <Text style={[styles.metadataRowValue, { color: colors.text }]}>{entry.value}</Text>
                      </View>
                    ))}
                  </View>
                </View>
              ) : null}

              <View style={styles.commentsHeader}>
                <Text style={[styles.commentsTitle, { color: colors.text }]}>Comments</Text>
                <Text style={[styles.commentsCount, { color: mutedText }]}>{comments.length}</Text>
              </View>
            </View>
          ) : null
        }
        ListEmptyComponent={
          loading ? (
            <View style={styles.stateWrap}>
              <ActivityIndicator size="small" color={colors.text} />
              <Text style={[styles.stateText, { color: mutedText }]}>Loading listing...</Text>
            </View>
          ) : error ? (
            <View style={[styles.errorCard, { backgroundColor: cardBackground, borderColor }]}>
              <Text style={[styles.errorText, { color: dark ? '#FCA5A5' : '#B91C1C' }]}>{error}</Text>
              <TouchableOpacity style={[styles.retryButton, { borderColor }]} onPress={() => fetchDetail()} activeOpacity={0.85}>
                <Text style={[styles.retryText, { color: colors.text }]}>Retry</Text>
              </TouchableOpacity>
            </View>
          ) : (
            <View style={styles.stateWrap}>
              <Text style={[styles.stateText, { color: mutedText }]}>No comments yet.</Text>
            </View>
          )
        }
        renderItem={({ item }) => (
          <View style={[styles.commentCard, { backgroundColor: cardBackground, borderColor }]}>
            {item.user.avatar ? (
              <Image source={{ uri: item.user.avatar }} style={styles.commentAvatar} contentFit="cover" />
            ) : (
              <View style={[styles.commentAvatar, { backgroundColor: surfaceBackground }]} />
            )}
            <View style={{ flex: 1 }}>
              <View style={styles.commentTopRow}>
                <Text style={[styles.commentName, { color: colors.text }]} numberOfLines={1}>
                  {item.user.name}
                </Text>
                {!!item.time && (
                  <Text style={[styles.commentTime, { color: mutedText }]}>{item.time}</Text>
                )}
              </View>
              <Text style={[styles.commentUsername, { color: mutedText }]} numberOfLines={1}>
                @{item.user.username}
              </Text>
              <Text style={[styles.commentText, { color: colors.text }]}>{item.text || ''}</Text>
            </View>
          </View>
        )}
      />

      <View style={styles.inputDock}>
        <ChatInput
          kind="comment"
          currentUser={currentUser}
          replyingTo={null}
          editingMessage={null}
          onCancelReply={() => null}
          onCancelEdit={() => null}
          onSendMessage={handleSendComment}
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  listContent: {
    paddingHorizontal: 20,
    paddingTop: 20,
    paddingBottom: 220,
    gap: 14,
  },
  headerSection: {
    gap: 16,
    paddingBottom: 6,
  },
  heroCard: {
    borderWidth: 1,
    borderRadius: 26,
    padding: 18,
    gap: 14,
  },
  heroTopRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 12,
  },
  kindBadge: {
    paddingHorizontal: 12,
    height: 30,
    borderRadius: 15,
    alignItems: 'center',
    justifyContent: 'center',
  },
  kindBadgeText: {
    fontSize: 12,
    fontFamily: 'Inter-Bold',
  },
  timeText: {
    fontSize: 11,
    fontFamily: 'Inter-Bold',
    textTransform: 'uppercase',
    letterSpacing: 0.7,
  },
  title: {
    fontSize: 28,
    lineHeight: 32,
    fontFamily: 'Outfit-Bold',
    letterSpacing: -0.7,
  },
  authorRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  authorAvatar: {
    width: 44,
    height: 44,
    borderRadius: 22,
  },
  authorName: {
    fontSize: 15,
    fontFamily: 'Inter-Bold',
  },
  authorUsername: {
    marginTop: 2,
    fontSize: 13,
    fontFamily: 'Inter-Medium',
  },
  excerpt: {
    fontSize: 15,
    lineHeight: 22,
    fontFamily: 'Inter-Regular',
  },
  heroImage: {
    width: '100%',
    aspectRatio: 1.25,
    borderRadius: 22,
    backgroundColor: '#E5E7EB',
  },
  metadataSection: {
    borderWidth: 1,
    borderRadius: 24,
    padding: 18,
  },
  metadataTitle: {
    fontSize: 18,
    fontFamily: 'Outfit-Bold',
    marginBottom: 10,
  },
  metadataList: {
    gap: 0,
  },
  metadataRow: {
    paddingVertical: 12,
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: 18,
  },
  metadataRowKey: {
    flex: 1,
    fontSize: 13,
    fontFamily: 'Inter-Bold',
    textTransform: 'uppercase',
    letterSpacing: 0.7,
  },
  metadataRowValue: {
    flex: 1,
    fontSize: 14,
    lineHeight: 19,
    textAlign: 'right',
    fontFamily: 'Inter-SemiBold',
  },
  commentsHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 4,
  },
  commentsTitle: {
    fontSize: 20,
    fontFamily: 'Outfit-Bold',
  },
  commentsCount: {
    fontSize: 13,
    fontFamily: 'Inter-Bold',
  },
  commentCard: {
    borderWidth: 1,
    borderRadius: 22,
    padding: 14,
    flexDirection: 'row',
    gap: 12,
  },
  commentAvatar: {
    width: 38,
    height: 38,
    borderRadius: 19,
  },
  commentTopRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 10,
  },
  commentName: {
    flex: 1,
    fontSize: 14,
    fontFamily: 'Inter-Bold',
  },
  commentTime: {
    fontSize: 11,
    fontFamily: 'Inter-Bold',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  commentUsername: {
    marginTop: 2,
    fontSize: 12,
    fontFamily: 'Inter-Medium',
  },
  commentText: {
    marginTop: 8,
    fontSize: 14,
    lineHeight: 20,
    fontFamily: 'Inter-Regular',
  },
  stateWrap: {
    paddingTop: 100,
    alignItems: 'center',
    gap: 12,
  },
  stateText: {
    fontSize: 14,
    fontFamily: 'Inter-SemiBold',
    textAlign: 'center',
  },
  errorCard: {
    borderWidth: 1,
    borderRadius: 24,
    padding: 18,
    alignItems: 'center',
    gap: 12,
  },
  errorText: {
    fontSize: 14,
    lineHeight: 20,
    fontFamily: 'Inter-SemiBold',
    textAlign: 'center',
  },
  retryButton: {
    minHeight: 42,
    paddingHorizontal: 16,
    borderRadius: 14,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  retryText: {
    fontSize: 13,
    fontFamily: 'Inter-Bold',
  },
  inputDock: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 0,
  },
});
