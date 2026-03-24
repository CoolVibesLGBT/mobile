import React, { useEffect, useMemo, useState } from 'react';
import { View, Text, StyleSheet, ScrollView, ActivityIndicator, StatusBar } from 'react-native';
import { useLocalSearchParams } from 'expo-router';
import { useTheme } from '@react-navigation/native';
import { Image } from 'expo-image';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useAppSelector } from '@/store/hooks';
import { normalizeProfileUser } from '@/helpers/profile';
import { getSafeImageURLEx } from '@/helpers/safeUrl';
import {
  buildProfileMetrics,
  formatMetricCount,
  resolveProfileMetricItems,
} from '@/helpers/profile-metrics';
import { api } from '@/services/apiService';

const INVALID_ENGAGEMENT_KIND_PATTERN =
  /invalid\s+engag(?:e)?ment(?:\s+kind|_?kind|_?type)?|unsupported\s+engag(?:e)?ment/i;

const engagementTypeAliasesByMetricKey: Record<string, string[]> = {
  followers: ['follower', 'followers'],
  following: ['following', 'followings'],
  matches: ['matched', 'matches', 'match'],
  blocked: ['blocking', 'block'],
  'likes-given': ['like_given', 'like', 'liked'],
  'likes-received': ['like_received', 'liked_by', 'liked'],
  'dislikes-given': ['dislike_given', 'dislike', 'disliked'],
  'dislikes-received': ['dislike_received', 'disliked_by', 'dislike', 'disliked', 'dislike_recieved'],
  'views-given': ['view_given', 'view', 'profile_view', 'profile_views'],
  'views-received': ['view_received', 'view', 'profile_view', 'profile_views'],
};

const isInvalidEngagementKind = (error: any) => {
  const message =
    error?.response?.data?.message ||
    error?.response?.data?.error ||
    error?.message ||
    '';

  return INVALID_ENGAGEMENT_KIND_PATTERN.test(String(message));
};

export default function ProfileMetricDetailScreen() {
  const { dark } = useTheme();
  const insets = useSafeAreaInsets();
  const params = useLocalSearchParams<{ metricKey?: string; metricLabel?: string }>();
  const authUser = useAppSelector((state) => state.auth.user);
  const language = useAppSelector((state) => state.system.language) || 'en';
  const [engagementPayload, setEngagementPayload] = useState<any | null>(null);
  const [engagementLoading, setEngagementLoading] = useState(true);
  const metricKey = Array.isArray(params.metricKey) ? params.metricKey[0] : params.metricKey;
  const metricLabelParam = Array.isArray(params.metricLabel) ? params.metricLabel[0] : params.metricLabel;

  const normalizedUser = useMemo(
    () => (authUser ? normalizeProfileUser(authUser, undefined, { language }) : null),
    [authUser, language]
  );

  const profileUser = useMemo(
    () => (
      authUser
        ? {
            ...authUser,
            ...normalizedUser,
            avatar_url: getSafeImageURLEx(authUser.id, authUser.avatar, 'large') || normalizedUser?.avatar_url,
          }
        : null
    ),
    [authUser, normalizedUser]
  );

  useEffect(() => {
    let isActive = true;

    const loadEngagements = async () => {
      if (!authUser || !metricKey) {
        if (isActive) setEngagementLoading(false);
        return;
      }

      const aliases = engagementTypeAliasesByMetricKey[metricKey] ?? [];
      const requestBody: Record<string, string | number> = {};

      if (profileUser?.public_id !== undefined && profileUser?.public_id !== null && String(profileUser.public_id).trim() !== '') {
        requestBody.user_id = profileUser.public_id;
      } else if (typeof profileUser?.username === 'string' && profileUser.username.trim().length > 0) {
        requestBody.nickname = profileUser.username.trim();
      }

      if (aliases.length === 0 || Object.keys(requestBody).length === 0) {
        if (isActive) setEngagementLoading(false);
        return;
      }

      try {
        let response: any = null;
        let lastError: any = null;

        for (const engagementType of aliases) {
          try {
            const nextResponse = await api.fetchUserEngagements({
              ...requestBody,
              engagement_type: engagementType,
            });

            const responseMessage =
              (typeof nextResponse?.message === 'string' ? nextResponse.message : '') ||
              (typeof nextResponse?.error === 'string' ? nextResponse.error : '');

            if (nextResponse?.success === false && INVALID_ENGAGEMENT_KIND_PATTERN.test(responseMessage)) {
              throw new Error(responseMessage);
            }

            response = nextResponse;
            break;
          } catch (error) {
            lastError = error;
            if (!isInvalidEngagementKind(error)) {
              throw error;
            }
          }
        }

        if (!response && lastError && !isInvalidEngagementKind(lastError)) {
          throw lastError;
        }

        if (isActive && response && typeof response === 'object') {
          setEngagementPayload(response);
        }
      } catch {
        // Fallback to auth user payload when engagement fetch is unavailable.
      } finally {
        if (isActive) setEngagementLoading(false);
      }
    };

    loadEngagements();

    return () => {
      isActive = false;
    };
  }, [authUser, metricKey, profileUser?.public_id, profileUser?.username]);

  const detailSourceUser = useMemo(() => {
    if (!profileUser) return null;
    if (!engagementPayload || typeof engagementPayload !== 'object') return profileUser;

    const payloadUser =
      engagementPayload?.user ||
      engagementPayload?.data?.user ||
      engagementPayload?.profile ||
      engagementPayload?.data?.profile ||
      null;

    const mergedPayload = payloadUser && typeof payloadUser === 'object'
      ? payloadUser
      : engagementPayload;
    const payloadEngagementArray =
      Array.isArray(engagementPayload?.engagements) ? engagementPayload.engagements
      : Array.isArray(engagementPayload?.data?.engagements) ? engagementPayload.data.engagements
      : Array.isArray(mergedPayload?.engagements) ? mergedPayload.engagements
      : Array.isArray(mergedPayload?.engagement_details) ? mergedPayload.engagement_details
      : [];
    const mergedEngagements =
      payloadEngagementArray.length > 0
        ? {
            ...(profileUser?.engagements && typeof profileUser.engagements === 'object' && !Array.isArray(profileUser.engagements)
              ? profileUser.engagements
              : {}),
            ...(mergedPayload?.engagements && typeof mergedPayload.engagements === 'object' && !Array.isArray(mergedPayload.engagements)
              ? mergedPayload.engagements
              : {}),
            engagement_details: payloadEngagementArray,
          }
        : (
            mergedPayload?.engagements ??
            engagementPayload?.engagements ??
            engagementPayload?.data?.engagements ??
            profileUser.engagements
          );

    return {
      ...profileUser,
      ...mergedPayload,
      engagements: mergedEngagements,
      followers:
        mergedPayload?.followers ??
        engagementPayload?.followers ??
        engagementPayload?.data?.followers ??
        profileUser.followers,
      following:
        mergedPayload?.following ??
        engagementPayload?.following ??
        engagementPayload?.data?.following ??
        profileUser.following,
      blocked_users:
        mergedPayload?.blocked_users ??
        engagementPayload?.blocked_users ??
        engagementPayload?.data?.blocked_users ??
        profileUser.blocked_users,
      blocking:
        mergedPayload?.blocking ??
        engagementPayload?.blocking ??
        engagementPayload?.data?.blocking ??
        profileUser.blocking,
      matches:
        mergedPayload?.matches ??
        engagementPayload?.matches ??
        engagementPayload?.data?.matches ??
        profileUser.matches,
    };
  }, [engagementPayload, profileUser]);

  const stats = useMemo(() => (detailSourceUser ? buildProfileMetrics(detailSourceUser) : []), [detailSourceUser]);
  const metric = useMemo(() => stats.find((item) => item.key === metricKey) || null, [metricKey, stats]);
  const items = useMemo(
    () => (metric && detailSourceUser ? resolveProfileMetricItems(detailSourceUser, metric.key) : []),
    [detailSourceUser, metric]
  );

  if (!authUser) {
    return (
      <View style={[styles.screen, { backgroundColor: dark ? '#000' : '#FFF' }]}>
        <StatusBar translucent backgroundColor="transparent" barStyle={dark ? 'light-content' : 'dark-content'} />
        <View style={[styles.loaderWrap, { paddingBottom: insets.bottom }]}>
          <ActivityIndicator size="small" color={dark ? '#FFF' : '#000'} />
        </View>
      </View>
    );
  }

  const title = metric?.label || String(metricLabelParam || 'Engagement');
  const count = metric ? formatMetricCount(metric.value, language) : '0';
  const backgroundColor = dark ? '#000000' : '#FFFFFF';
  const cardColor = dark ? '#0F0F0F' : '#F9F9F9';
  const textColor = dark ? '#FFFFFF' : '#000000';
  const secondaryText = dark ? '#888888' : '#666666';
  const borderColor = dark ? '#1A1A1A' : '#F0F0F0';

  return (
    <View style={[styles.screen, { backgroundColor }]}>
      <StatusBar translucent backgroundColor="transparent" barStyle={dark ? 'light-content' : 'dark-content'} />
      <ScrollView
        showsVerticalScrollIndicator={false}
        contentContainerStyle={[styles.content, { paddingBottom: insets.bottom + 24 }]}
      >
        <View style={[styles.summaryCard, { backgroundColor: cardColor, borderColor }]}>
          <Text style={[styles.summaryEyebrow, { color: secondaryText }]}>Engagement Detail</Text>
          <View style={styles.summaryRow}>
            <View style={styles.summaryText}>
              <Text style={[styles.summaryTitle, { color: textColor }]}>{title}</Text>
              <Text style={[styles.summaryDescription, { color: secondaryText }]}>
                {metric?.description || 'Profiles related to this metric.'}
              </Text>
            </View>
            <Text style={[styles.summaryCount, { color: textColor }]}>{count}</Text>
          </View>
        </View>

        <View style={styles.section}>
          <Text style={[styles.sectionTitle, { color: textColor }]}>Profiles</Text>
          {engagementLoading ? (
            <View style={[styles.loadingCard, { backgroundColor: cardColor, borderColor }]}>
              <ActivityIndicator size="small" color={textColor} />
            </View>
          ) : items.length > 0 ? (
            items.map((item) => {
              const fallbackInitial = (item.name || item.username || '?').trim().charAt(0).toUpperCase() || '?';
              return (
                <View
                  key={`${metric?.key || 'metric'}-${item.id}`}
                  style={[styles.listRow, { backgroundColor: cardColor, borderColor }]}
                >
                  {item.avatar ? (
                    <Image source={{ uri: item.avatar }} style={styles.avatar} contentFit="cover" />
                  ) : (
                    <View style={[styles.avatarFallback, { backgroundColor: dark ? '#161616' : '#F1F1F1' }]}>
                      <Text style={[styles.avatarInitial, { color: textColor }]}>{fallbackInitial}</Text>
                    </View>
                  )}

                  <View style={styles.listText}>
                    <Text style={[styles.listName, { color: textColor }]} numberOfLines={1}>
                      {item.name}
                    </Text>
                    {!!item.username && (
                      <Text style={[styles.listUsername, { color: secondaryText }]} numberOfLines={1}>
                        @{item.username}
                      </Text>
                    )}
                  </View>

                  <Text style={[styles.listBadge, { color: secondaryText }]}>{item.subtitle}</Text>
                </View>
              );
            })
          ) : (
            <View style={[styles.emptyCard, { backgroundColor: cardColor, borderColor }]}>
              <Text style={[styles.emptyTitle, { color: textColor }]}>No profiles to show</Text>
              <Text style={[styles.emptyText, { color: secondaryText }]}>
                This metric does not currently expose a detailed profile list.
              </Text>
            </View>
          )}
        </View>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  loaderWrap: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  content: { paddingHorizontal: 16, paddingTop: 16, gap: 16 },
  summaryCard: {
    borderWidth: 1,
    borderRadius: 22,
    paddingHorizontal: 16,
    paddingVertical: 16,
  },
  summaryEyebrow: {
    fontSize: 11,
    lineHeight: 14,
    fontFamily: 'Inter-SemiBold',
    textTransform: 'uppercase',
    letterSpacing: 0.6,
    marginBottom: 10,
  },
  summaryRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    justifyContent: 'space-between',
    gap: 16,
  },
  summaryText: {
    flex: 1,
  },
  summaryTitle: {
    fontSize: 24,
    lineHeight: 28,
    fontFamily: 'Outfit-Bold',
    letterSpacing: -0.5,
  },
  summaryDescription: {
    fontSize: 13,
    lineHeight: 18,
    fontFamily: 'Inter-Regular',
    marginTop: 6,
  },
  summaryCount: {
    fontSize: 28,
    lineHeight: 32,
    fontFamily: 'Outfit-Black',
    letterSpacing: -0.6,
  },
  section: {
    gap: 10,
  },
  sectionTitle: {
    fontSize: 18,
    lineHeight: 22,
    fontFamily: 'Outfit-Bold',
    letterSpacing: -0.3,
  },
  listRow: {
    borderWidth: 1,
    borderRadius: 18,
    paddingHorizontal: 12,
    paddingVertical: 12,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  loadingCard: {
    borderWidth: 1,
    borderRadius: 18,
    paddingVertical: 20,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatar: {
    width: 50,
    height: 50,
    borderRadius: 25,
  },
  avatarFallback: {
    width: 50,
    height: 50,
    borderRadius: 25,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarInitial: {
    fontSize: 18,
    lineHeight: 20,
    fontFamily: 'Outfit-Bold',
  },
  listText: {
    flex: 1,
    minWidth: 0,
  },
  listName: {
    fontSize: 15,
    lineHeight: 19,
    fontFamily: 'Inter-SemiBold',
  },
  listUsername: {
    fontSize: 12,
    lineHeight: 16,
    fontFamily: 'Inter-Regular',
    marginTop: 2,
  },
  listBadge: {
    fontSize: 11,
    lineHeight: 14,
    fontFamily: 'Inter-SemiBold',
    textTransform: 'uppercase',
    letterSpacing: 0.4,
  },
  emptyCard: {
    borderWidth: 1,
    borderRadius: 18,
    paddingHorizontal: 14,
    paddingVertical: 18,
  },
  emptyTitle: {
    fontSize: 15,
    lineHeight: 20,
    fontFamily: 'Outfit-Bold',
    letterSpacing: -0.2,
  },
  emptyText: {
    fontSize: 13,
    lineHeight: 18,
    fontFamily: 'Inter-Regular',
    marginTop: 6,
  },
});
