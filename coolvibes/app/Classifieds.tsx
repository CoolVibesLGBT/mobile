import React, { useCallback, useEffect, useMemo, useState } from 'react';
import {
  ActivityIndicator,
  FlatList,
  Pressable,
  RefreshControl,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from 'react-native';
import { useTheme } from '@react-navigation/native';
import { useRouter } from 'expo-router';
import { Image } from 'expo-image';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import MaterialCommunityIcons from '@expo/vector-icons/MaterialCommunityIcons';
import Animated, { FadeIn } from 'react-native-reanimated';

import {
  ClassifiedCardItem,
  extractClassifiedListResponse,
  kindToClassifiedTab,
  normalizeClassifiedList,
  searchClassifieds,
} from '@/helpers/classifieds';
import { api } from '@/services/apiService';
import { useAppDispatch, useAppSelector } from '@/store/hooks';
import { clearPostUploadNotice } from '@/store/slice/postUploads';

type ClassifiedTab = 'hiring' | 'seeking';

type TemplateCard = {
  id: string;
  icon: keyof typeof MaterialCommunityIcons.glyphMap;
  title: string;
  description: string;
  tab?: ClassifiedTab;
};

const TEMPLATE_CARDS: TemplateCard[] = [
  {
    id: 'roommate',
    icon: 'home-outline',
    title: 'Roommate',
    description: 'Housing, shared flats and living arrangements.',
  },
  {
    id: 'employers',
    icon: 'office-building-outline',
    title: 'Hiring',
    description: 'Create a listing when you are looking for people.',
    tab: 'hiring',
  },
  {
    id: 'job-seekers',
    icon: 'account-search-outline',
    title: 'Job seekers',
    description: 'Post your skills and the role you are looking for.',
    tab: 'seeking',
  },
  {
    id: 'tutors',
    icon: 'school-outline',
    title: 'Tutors',
    description: 'Offer classes, coaching or consulting work.',
  },
  {
    id: 'animals',
    icon: 'paw-outline',
    title: 'Pets',
    description: 'Share pet-related listings and community needs.',
  },
];

export default function ClassifiedsScreen() {
  const { colors, dark } = useTheme();
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const dispatch = useAppDispatch();
  const notice = useAppSelector((state) => state.postUploads.notice);
  const completedVersion = useAppSelector((state) => state.postUploads.completedVersion);

  const [activeTab, setActiveTab] = useState<ClassifiedTab>('hiring');
  const [searchQuery, setSearchQuery] = useState('');
  const [items, setItems] = useState<ClassifiedCardItem[]>([]);
  const [cursor, setCursor] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState('');

  const mutedText = dark ? 'rgba(255,255,255,0.58)' : 'rgba(15,23,42,0.58)';
  const borderColor = dark ? 'rgba(255,255,255,0.08)' : 'rgba(15,23,42,0.08)';
  const cardBackground = dark ? 'rgba(255,255,255,0.04)' : '#FFFFFF';
  const subduedBackground = dark ? 'rgba(255,255,255,0.06)' : '#F8FAFC';

  const filteredItems = useMemo(() => searchClassifieds(items, searchQuery), [items, searchQuery]);
  const activeCountText = `${filteredItems.length} active listing${filteredItems.length === 1 ? '' : 's'}`;

  const fetchClassifieds = useCallback(
    async ({ refresh = false, append = false, cursorArg }: { refresh?: boolean; append?: boolean; cursorArg?: string | null } = {}) => {
      try {
        if (append) setLoadingMore(true);
        else if (refresh) setRefreshing(true);
        else setLoading(true);

        setError('');

        const response =
          activeTab === 'hiring'
            ? await api.fetchJobOffers({ limit: 20, cursor: append ? cursorArg : undefined })
            : await api.fetchJobSearches({ limit: 20, cursor: append ? cursorArg : undefined });

        const payload = extractClassifiedListResponse(response);
        const normalized = normalizeClassifiedList(payload.posts);

        setItems((current) => {
          if (!append) return normalized;

          const existingIds = new Set(current.map((item) => item.id));
          const next = normalized.filter((item) => !existingIds.has(item.id));
          return next.length > 0 ? [...current, ...next] : current;
        });
        setCursor(payload.cursor);
      } catch {
        setError('Classifieds could not be loaded.');
      } finally {
        setLoading(false);
        setRefreshing(false);
        setLoadingMore(false);
      }
    },
    [activeTab]
  );

  useEffect(() => {
    void fetchClassifieds();
  }, [fetchClassifieds]);

  useEffect(() => {
    if (!notice || notice.kind === 'uploading') return;
    const timer = setTimeout(() => {
      dispatch(clearPostUploadNotice());
    }, 4200);
    return () => clearTimeout(timer);
  }, [dispatch, notice]);

  useEffect(() => {
    if (completedVersion === 0) return;
    void fetchClassifieds({ refresh: true });
  }, [completedVersion, fetchClassifieds]);

  const openCreate = useCallback((options?: { tab?: ClassifiedTab; title?: string }) => {
    router.push({
      pathname: '/ClassifiedCreate',
      params: {
        ...(options?.tab ? { tab: options.tab } : { tab: activeTab }),
        ...(options?.title ? { title: options.title } : {}),
      },
    });
  }, [activeTab, router]);

  const renderTemplateCard = useCallback((template: TemplateCard) => (
    <TouchableOpacity
      key={template.id}
      style={[styles.templateCard, { backgroundColor: subduedBackground, borderColor }]}
      activeOpacity={0.88}
      onPress={() => openCreate({ tab: template.tab ?? activeTab, title: template.title })}
    >
      <View style={[styles.templateIconWrap, { backgroundColor: dark ? 'rgba(255,255,255,0.08)' : 'rgba(15,23,42,0.06)' }]}>
        <MaterialCommunityIcons name={template.icon} size={20} color={colors.text} />
      </View>
      <Text style={[styles.templateTitle, { color: colors.text }]} numberOfLines={1}>
        {template.title}
      </Text>
      <Text style={[styles.templateDescription, { color: mutedText }]} numberOfLines={2}>
        {template.description}
      </Text>
    </TouchableOpacity>
  ), [activeTab, borderColor, colors.text, dark, mutedText, openCreate, subduedBackground]);

  const renderItem = useCallback(({ item }: { item: ClassifiedCardItem }) => {
    const isSeeking = kindToClassifiedTab(item.kind) === 'seeking';

    return (
      <Pressable
        style={({ pressed }) => [
          styles.listingCard,
          {
            backgroundColor: cardBackground,
            borderColor,
            opacity: pressed ? 0.94 : 1,
            transform: [{ scale: pressed ? 0.992 : 1 }],
          },
        ]}
        onPress={() => router.push({ pathname: '/ClassifiedDetail', params: { postId: item.id } })}
      >
        <View style={styles.listingHeader}>
          <View style={styles.listingBadgeRow}>
            <View
              style={[
                styles.listingBadge,
                { backgroundColor: isSeeking ? '#E0F2FE' : '#DCFCE7' },
              ]}
            >
              <MaterialCommunityIcons
                name={isSeeking ? 'account-search-outline' : 'briefcase-outline'}
                size={14}
                color={isSeeking ? '#0369A1' : '#166534'}
              />
              <Text
                style={[
                  styles.listingBadgeText,
                  { color: isSeeking ? '#0369A1' : '#166534' },
                ]}
              >
                {isSeeking ? 'Seeking' : 'Hiring'}
              </Text>
            </View>
            {!!item.time && (
              <Text style={[styles.listingTime, { color: mutedText }]}>{item.time}</Text>
            )}
          </View>
          <MaterialCommunityIcons name="chevron-right" size={20} color={colors.text} />
        </View>

        <View style={styles.listingBody}>
          <View style={{ flex: 1 }}>
            <Text style={[styles.listingTitle, { color: colors.text }]} numberOfLines={2}>
              {item.title}
            </Text>
            {!!item.excerpt && (
              <Text style={[styles.listingExcerpt, { color: mutedText }]} numberOfLines={3}>
                {item.excerpt}
              </Text>
            )}
          </View>

          {item.image ? (
            <View style={[styles.listingThumbWrap, { borderColor }]}>
              <Image source={{ uri: item.image }} style={styles.listingThumb} contentFit="cover" transition={160} />
            </View>
          ) : null}
        </View>

        {item.metadata.length > 0 ? (
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            contentContainerStyle={styles.metadataRow}
          >
            {item.metadata.map((meta) => (
              <View
                key={`${item.id}-${meta.key}`}
                style={[styles.metadataChip, { backgroundColor: subduedBackground, borderColor }]}
              >
                <Text style={[styles.metadataChipKey, { color: mutedText }]}>{meta.key}</Text>
                <Text style={[styles.metadataChipValue, { color: colors.text }]} numberOfLines={1}>
                  {meta.value}
                </Text>
              </View>
            ))}
          </ScrollView>
        ) : null}

        <View style={styles.footerRow}>
          <View style={[styles.authorAvatarFallback, { backgroundColor: subduedBackground, borderColor }]}>
            {item.author.avatar ? (
              <Image source={{ uri: item.author.avatar }} style={styles.authorAvatar} contentFit="cover" transition={120} />
            ) : (
              <MaterialCommunityIcons name="account-outline" size={18} color={colors.text} />
            )}
          </View>
          <View style={{ flex: 1 }}>
            <Text style={[styles.authorName, { color: colors.text }]} numberOfLines={1}>
              {item.author.name}
            </Text>
            <Text style={[styles.authorUsername, { color: mutedText }]} numberOfLines={1}>
              @{item.author.username}
            </Text>
          </View>
        </View>
      </Pressable>
    );
  }, [borderColor, cardBackground, colors.text, mutedText, router, subduedBackground]);

  const headerComponent = useMemo(() => (
    <View style={styles.headerContent}>
      <View style={[styles.controlCard, { backgroundColor: cardBackground, borderColor }]}>
        <View style={styles.segmentHeaderRow}>
          <View style={[styles.segmentWrap, { backgroundColor: subduedBackground, borderColor }]}>
            {(['hiring', 'seeking'] as ClassifiedTab[]).map((tab) => {
              const selected = tab === activeTab;
              return (
                <TouchableOpacity
                  key={tab}
                  style={[
                    styles.segmentButton,
                    selected && { backgroundColor: dark ? '#FFFFFF' : '#0F172A' },
                  ]}
                  activeOpacity={0.86}
                  onPress={() => setActiveTab(tab)}
                >
                  <Text
                    style={[
                      styles.segmentButtonText,
                      { color: selected ? (dark ? '#0B0B0B' : '#FFFFFF') : colors.text },
                    ]}
                  >
                    {tab === 'hiring' ? 'Hire' : 'Jobs'}
                  </Text>
                </TouchableOpacity>
              );
            })}
          </View>
          <Text style={[styles.listingCount, { color: mutedText }]}>{activeCountText}</Text>
        </View>

        <View style={[styles.searchWrap, { backgroundColor: subduedBackground, borderColor }]}>
          <MaterialCommunityIcons name="magnify" size={18} color={mutedText} />
          <TextInput
            value={searchQuery}
            onChangeText={setSearchQuery}
            placeholder={activeTab === 'hiring' ? 'Search listings...' : 'Search job seekers...'}
            placeholderTextColor={mutedText}
            style={[styles.searchInput, { color: colors.text }]}
          />
          {searchQuery.trim().length > 0 ? (
            <TouchableOpacity onPress={() => setSearchQuery('')} activeOpacity={0.8}>
              <MaterialCommunityIcons name="close" size={18} color={colors.text} />
            </TouchableOpacity>
          ) : null}
        </View>
      </View>

      <View style={styles.templatesSection}>
        <View style={styles.templatesHeader}>
          <Text style={[styles.templatesTitle, { color: colors.text }]}>Listing ideas</Text>
          <TouchableOpacity onPress={() => openCreate()} activeOpacity={0.82}>
            <Text style={[styles.templatesAction, { color: colors.text }]}>New listing</Text>
          </TouchableOpacity>
        </View>

        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.templatesRow}>
          {TEMPLATE_CARDS.map(renderTemplateCard)}
        </ScrollView>
      </View>

      {error ? (
        <View style={[styles.stateCard, { backgroundColor: cardBackground, borderColor }]}>
          <Text style={[styles.errorText, { color: dark ? '#FCA5A5' : '#B91C1C' }]}>{error}</Text>
          <TouchableOpacity style={[styles.retryButton, { borderColor }]} onPress={() => fetchClassifieds()} activeOpacity={0.85}>
            <Text style={[styles.retryText, { color: colors.text }]}>Retry</Text>
          </TouchableOpacity>
        </View>
      ) : null}
    </View>
  ), [activeCountText, activeTab, borderColor, cardBackground, colors.text, dark, error, fetchClassifieds, mutedText, openCreate, renderTemplateCard, searchQuery, subduedBackground]);

  return (
    <View style={[styles.container, { backgroundColor: colors.background }]}>
      <FlatList
        data={filteredItems}
        keyExtractor={(item) => item.id}
        renderItem={renderItem}
        ListHeaderComponent={headerComponent}
        contentContainerStyle={{
          paddingHorizontal: 20,
          paddingTop: 20,
          paddingBottom: 32 + insets.bottom + (notice ? 72 : 0),
          gap: 14,
        }}
        ItemSeparatorComponent={() => <View style={{ height: 14 }} />}
        onEndReachedThreshold={0.3}
        onEndReached={() => {
          if (cursor && !loadingMore && !loading && !refreshing) {
            void fetchClassifieds({ append: true, cursorArg: cursor });
          }
        }}
        ListEmptyComponent={
          loading ? (
            <View style={styles.emptyState}>
              <ActivityIndicator size="small" color={colors.text} />
              <Text style={[styles.emptyText, { color: mutedText }]}>Loading listings...</Text>
            </View>
          ) : (
            <View style={[styles.stateCard, { backgroundColor: cardBackground, borderColor }]}>
              <MaterialCommunityIcons name="briefcase-search-outline" size={24} color={colors.text} />
              <Text style={[styles.emptyTitle, { color: colors.text }]}>No listings found</Text>
              <Text style={[styles.emptyText, { color: mutedText }]}>
                Try another search or publish a new listing.
              </Text>
              {searchQuery.trim().length > 0 ? (
                <TouchableOpacity style={[styles.retryButton, { borderColor }]} onPress={() => setSearchQuery('')} activeOpacity={0.85}>
                  <Text style={[styles.retryText, { color: colors.text }]}>Clear search</Text>
                </TouchableOpacity>
              ) : (
                <TouchableOpacity style={[styles.retryButton, { borderColor }]} onPress={() => openCreate()} activeOpacity={0.85}>
                  <Text style={[styles.retryText, { color: colors.text }]}>Create listing</Text>
                </TouchableOpacity>
              )}
            </View>
          )
        }
        ListFooterComponent={
          loadingMore ? (
            <View style={styles.footerLoader}>
              <ActivityIndicator size="small" color={colors.text} />
            </View>
          ) : null
        }
        refreshControl={
          <RefreshControl
            refreshing={refreshing}
            onRefresh={() => {
              void fetchClassifieds({ refresh: true });
            }}
            tintColor={colors.text}
          />
        }
        showsVerticalScrollIndicator={false}
      />

      {notice ? (
        <View
          pointerEvents="none"
          style={[
            styles.noticeWrap,
            {
              bottom: 20 + insets.bottom,
            },
          ]}
        >
          <Animated.View
            entering={FadeIn.duration(180)}
            style={[
              styles.noticeCard,
              {
                backgroundColor: notice.kind === 'error' ? '#7F1D1D' : '#111827',
              },
            ]}
          >
            {notice.kind === 'uploading' ? (
              <ActivityIndicator size="small" color="#FFFFFF" />
            ) : (
              <MaterialCommunityIcons
                name={notice.kind === 'success' ? 'check-circle-outline' : 'alert-circle-outline'}
                size={18}
                color="#FFFFFF"
              />
            )}
            <Text style={styles.noticeText} numberOfLines={2}>
              {notice.text}
            </Text>
          </Animated.View>
        </View>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  headerContent: {
    gap: 16,
    paddingBottom: 6,
  },
  controlCard: {
    borderWidth: 1,
    borderRadius: 24,
    padding: 16,
    gap: 14,
  },
  segmentHeaderRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  segmentWrap: {
    flex: 1,
    borderWidth: 1,
    borderRadius: 18,
    padding: 4,
    flexDirection: 'row',
  },
  segmentButton: {
    flex: 1,
    height: 40,
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
  },
  segmentButtonText: {
    fontSize: 13,
    fontFamily: 'Inter-Bold',
  },
  listingCount: {
    fontSize: 11,
    fontFamily: 'Inter-Bold',
    textTransform: 'uppercase',
    letterSpacing: 0.8,
  },
  searchWrap: {
    minHeight: 48,
    borderWidth: 1,
    borderRadius: 16,
    paddingHorizontal: 14,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  searchInput: {
    flex: 1,
    fontSize: 14,
    fontFamily: 'Inter-Medium',
  },
  templatesSection: {
    gap: 12,
  },
  templatesHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  templatesTitle: {
    fontSize: 20,
    fontFamily: 'Outfit-Bold',
    letterSpacing: -0.4,
  },
  templatesAction: {
    fontSize: 13,
    fontFamily: 'Inter-Bold',
  },
  templatesRow: {
    gap: 12,
    paddingRight: 20,
  },
  templateCard: {
    width: 190,
    borderRadius: 22,
    borderWidth: 1,
    padding: 16,
    gap: 12,
  },
  templateIconWrap: {
    width: 42,
    height: 42,
    borderRadius: 21,
    alignItems: 'center',
    justifyContent: 'center',
  },
  templateTitle: {
    fontSize: 16,
    fontFamily: 'Inter-Bold',
  },
  templateDescription: {
    fontSize: 13,
    lineHeight: 18,
    fontFamily: 'Inter-Regular',
  },
  listingCard: {
    borderWidth: 1,
    borderRadius: 24,
    padding: 16,
    gap: 14,
  },
  listingHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  listingBadgeRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    flex: 1,
  },
  listingBadge: {
    paddingHorizontal: 10,
    height: 30,
    borderRadius: 15,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  listingBadgeText: {
    fontSize: 12,
    fontFamily: 'Inter-Bold',
  },
  listingTime: {
    fontSize: 11,
    fontFamily: 'Inter-Bold',
    textTransform: 'uppercase',
    letterSpacing: 0.6,
  },
  listingBody: {
    flexDirection: 'row',
    gap: 14,
  },
  listingTitle: {
    fontSize: 18,
    lineHeight: 23,
    fontFamily: 'Outfit-Bold',
    letterSpacing: -0.4,
  },
  listingExcerpt: {
    marginTop: 8,
    fontSize: 14,
    lineHeight: 20,
    fontFamily: 'Inter-Regular',
  },
  listingThumbWrap: {
    width: 88,
    height: 88,
    borderRadius: 20,
    overflow: 'hidden',
    borderWidth: 1,
  },
  listingThumb: {
    width: '100%',
    height: '100%',
  },
  metadataRow: {
    gap: 8,
  },
  metadataChip: {
    minWidth: 110,
    maxWidth: 180,
    paddingHorizontal: 12,
    paddingVertical: 10,
    borderRadius: 16,
    borderWidth: 1,
  },
  metadataChipKey: {
    fontSize: 10,
    fontFamily: 'Inter-Bold',
    textTransform: 'uppercase',
    letterSpacing: 0.8,
  },
  metadataChipValue: {
    marginTop: 4,
    fontSize: 13,
    fontFamily: 'Inter-SemiBold',
  },
  footerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  authorAvatarFallback: {
    width: 38,
    height: 38,
    borderRadius: 19,
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
    borderWidth: 1,
  },
  authorAvatar: {
    width: '100%',
    height: '100%',
  },
  authorName: {
    fontSize: 14,
    fontFamily: 'Inter-Bold',
  },
  authorUsername: {
    marginTop: 2,
    fontSize: 12,
    fontFamily: 'Inter-Medium',
  },
  stateCard: {
    borderWidth: 1,
    borderRadius: 24,
    padding: 20,
    alignItems: 'center',
    gap: 10,
  },
  emptyState: {
    paddingVertical: 80,
    alignItems: 'center',
    gap: 12,
  },
  emptyTitle: {
    fontSize: 18,
    fontFamily: 'Outfit-Bold',
  },
  emptyText: {
    fontSize: 14,
    lineHeight: 20,
    fontFamily: 'Inter-Regular',
    textAlign: 'center',
  },
  errorText: {
    fontSize: 14,
    lineHeight: 20,
    fontFamily: 'Inter-SemiBold',
    textAlign: 'center',
  },
  retryButton: {
    marginTop: 4,
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
  footerLoader: {
    paddingVertical: 18,
    alignItems: 'center',
  },
  noticeWrap: {
    position: 'absolute',
    left: 20,
    right: 20,
  },
  noticeCard: {
    minHeight: 48,
    borderRadius: 18,
    paddingHorizontal: 14,
    paddingVertical: 12,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  noticeText: {
    flex: 1,
    color: '#FFFFFF',
    fontSize: 13,
    lineHeight: 18,
    fontFamily: 'Inter-SemiBold',
  },
});
