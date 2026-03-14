import React, { useEffect, useMemo, useState, useRef, useCallback } from 'react';
import { StyleSheet, View, Dimensions, FlatList, StatusBar, Pressable, TouchableOpacity, ScrollView } from 'react-native';
import { Image } from 'expo-image';
import MaterialCommunityIcons from '@expo/vector-icons/MaterialCommunityIcons';
import { useRouter } from 'expo-router';
import { useTheme } from '@react-navigation/native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Animated, { FadeIn, FadeInDown } from 'react-native-reanimated';
import { RefreshCcw, Trash2, Pin, Eraser, X, MessageSquare, CircleDot } from 'lucide-react-native';
import { BottomSheetBackdrop, BottomSheetView, BottomSheetModal } from '@gorhom/bottom-sheet';

import { ThemedText } from '@/components/ThemedText';
import { useAppDispatch, useAppSelector } from '@/store/hooks';
import { fetchChats, resetChats } from '@/store/slice/chat';
import BaseBottomSheetModal from '@/components/BaseBottomSheetModal';
import { getSafeImageURLEx } from '@/helpers/safeUrl';
import { encodeProfileParam } from '@/helpers/profile';

const { width: SCREEN_WIDTH } = Dimensions.get('window');

type FilterKey = 'all' | 'unread' | 'pinned';

type PinnedItem = {
  id: string;
  name: string;
  avatar: string;
  online: boolean;
};

type ConversationItem = {
  id: string;
  name: string;
  preview: string;
  timestamp: string;
  unreadCount: number;
  pinned: boolean;
  online: boolean;
  avatar: string;
  status: string;
  profile?: any;
};

function getLocalizedText(value: any, language: string) {
  if (!value) return '';
  if (typeof value === 'string') return value;
  if (typeof value === 'number') return String(value);
  if (typeof value === 'object') {
    return value[language] || value.en || Object.values(value)[0] || '';
  }
  return '';
}

function normalizeChat(chat: any, index: number, authUserId: string | null, language: string): ConversationItem {
  const participants = Array.isArray(chat?.participants) ? chat.participants : [];
  const selfParticipant = participants.find((p: any) => p?.user_id === authUserId || p?.user?.id === authUserId);
  const otherParticipant = participants.find((p: any) => p?.user_id !== authUserId && p?.user?.id !== authUserId) || participants[0];
  const counterpart =
    otherParticipant?.user ||
    chat?.other_user ||
    chat?.user ||
    chat?.participant ||
    chat?.match ||
    chat?.receiver ||
    chat?.sender ||
    {};

  const name =
    counterpart?.displayname ||
    counterpart?.display_name ||
    counterpart?.username ||
    getLocalizedText(chat?.title, language) ||
    chat?.name ||
    'Unknown';

  const preview =
    getLocalizedText(chat?.last_message?.content, language) ||
    chat?.last_message?.text ||
    chat?.last_message_text ||
    chat?.message ||
    '';

  const timestampSource =
    chat?.last_message_timestamp ||
    chat?.last_message?.created_at ||
    chat?.updated_at ||
    chat?.timestamp ||
    '';

  const avatar = getSafeImageURLEx(
    counterpart?.public_id ?? counterpart?.id ?? chat?.id,
    counterpart?.avatar || counterpart?.avatar_url || counterpart?.avatarUrl,
    'small'
  );

  return {
    id: String(chat?.id ?? chat?.chat_id ?? chat?.public_id ?? counterpart?.id ?? `chat-${index}`),
    name,
    preview,
    timestamp: typeof timestampSource === 'string' && timestampSource ? timestampSource.slice(0, 16) : '',
    unreadCount: Number(selfParticipant?.unread_count ?? chat?.unread_count ?? chat?.unread ?? 0),
    pinned: Boolean(chat?.is_pinned ?? false),
    online: Boolean(counterpart?.is_online ?? counterpart?.online ?? false),
    avatar: avatar || counterpart?.avatar_url || counterpart?.avatarUrl || '',
    status: counterpart?.is_online || counterpart?.online ? 'Online' : '',
    profile: counterpart || null,
  };
}

export default function ChatScreen() {
  const { colors, dark } = useTheme();
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const dispatch = useAppDispatch();
  const { chats, loading, cursor } = useAppSelector((state) => state.chat);
  const authUserId = useAppSelector((state) => state.auth.user?.id ?? null);
  const authUser = useAppSelector((state) => state.auth.user);
  const language = useAppSelector((state) => state.system.language) || 'en';
  const lastChatsRef = useRef<any[]>([]);
  const lastConversationsRef = useRef<ConversationItem[]>([]);
  const initialLoadRef = useRef(false);
  const lastLoadMoreCursorRef = useRef<string | null>(null);

  const [activeFilter, setActiveFilter] = useState<FilterKey>('all');
  const [pinnedIds, setPinnedIds] = useState<Record<string, boolean>>({});
  const [deletedIds, setDeletedIds] = useState<Record<string, boolean>>({});
  const [selectedChat, setSelectedChat] = useState<ConversationItem | null>(null);

  const bottomSheetModalRef = useRef<BottomSheetModal>(null);

  useEffect(() => {
    if (initialLoadRef.current) return;
    initialLoadRef.current = true;
    dispatch(fetchChats({ limit: 20 }));
  }, [dispatch]);

  useEffect(() => {
    if (chats.length > 0) {
      lastChatsRef.current = chats;
    }
  }, [chats]);

  const conversations = useMemo(() => {
    const sourceChats = chats.length > 0 ? chats : lastChatsRef.current;
    const base = sourceChats.length > 0 ? sourceChats.map((chat, index) => normalizeChat(chat, index, authUserId, language)) : [];

    return base.filter((item) => {
      if (deletedIds[item.id]) return false;
      const isPinned = pinnedIds[item.id] || item.pinned;
      const matchesFilter =
        activeFilter === 'all' ||
        (activeFilter === 'unread' && item.unreadCount > 0) ||
        (activeFilter === 'pinned' && isPinned);

      return matchesFilter;
    }).map(item => ({...item, pinned: pinnedIds[item.id] || item.pinned}));
  }, [activeFilter, chats, deletedIds, pinnedIds, authUserId, language]);

  useEffect(() => {
    if (conversations.length > 0) {
      lastConversationsRef.current = conversations;
    }
  }, [conversations]);

  useEffect(() => {
    console.log('[ChatScreen] chats:', chats.length, 'conversations:', conversations.length, 'loading:', loading);
  }, [chats.length, conversations.length, loading]);

  const listData =
    conversations.length > 0
      ? conversations
      : loading
        ? lastConversationsRef.current
        : activeFilter === 'all'
          ? lastConversationsRef.current
          : [];

  const favorites = useMemo(() => {
    const details = authUser?.engagements?.engagement_details || [];
    const authPublicId = authUser?.public_id ?? null;
    const isBlocking = (detail: any) => {
      const kind = detail?.kind || detail?.engagement_kind || detail?.type;
      const normalized = String(kind || '').toLowerCase();
      return normalized === 'blocking' || normalized === 'blocked' || normalized.includes('block');
    };
    const getUserId = (user: any) => user?.id || user?.public_id;
    const isSelf = (user: any) => {
      const id = user?.id;
      const publicId = user?.public_id;
      if (authUserId && id && String(id) === String(authUserId)) return true;
      if (authPublicId && publicId && String(publicId) === String(authPublicId)) return true;
      return false;
    };
    const getOtherUser = (detail: any) => {
      const engager = detail?.engager || detail?.user;
      const engagee = detail?.engagee;
      if (engager && !isSelf(engager)) return engager;
      if (engagee && !isSelf(engagee)) return engagee;
      return engager || engagee || null;
    };

    const blockedIds = new Set(
      details
        .filter(isBlocking)
        .map((detail: any) => getUserId(getOtherUser(detail)))
        .filter(Boolean)
    );

    const unique = new Map<string, { id: string; name: string; avatar: string; online: boolean }>();
    details.forEach((detail: any) => {
      if (isBlocking(detail)) return;
      const user = getOtherUser(detail);
      if (!user || isSelf(user)) return;
      const id = getUserId(user);
      if (!id || blockedIds.has(id)) return;
      const avatar = getSafeImageURLEx(user?.public_id ?? id, user?.avatar, 'small') || '';
      const name = user?.displayname || user?.display_name || user?.username || 'User';
      if (!unique.has(String(id))) {
        unique.set(String(id), { id: String(id), name, avatar, online: Boolean(user?.is_online ?? user?.online) });
      }
    });

    return Array.from(unique.values());
  }, [authUser, authUserId]);

  const handleTogglePin = (id: string, isCurrentlyPinned: boolean) => {
    setPinnedIds((prev) => ({ ...prev, [id]: !isCurrentlyPinned }));
    bottomSheetModalRef.current?.dismiss();
  };

  const handleDelete = (id: string) => {
    setDeletedIds((prev) => ({ ...prev, [id]: true }));
    bottomSheetModalRef.current?.dismiss();
  };

  const handleLongPress = (item: ConversationItem) => {
    setSelectedChat(item);
    bottomSheetModalRef.current?.present();
  };

  const handleRowPress = (item: ConversationItem) => {
    router.push({
      pathname: '/ChatDetail',
      params: {
        chatId: item.id,
        name: item.name,
        username: item.profile?.username || item.name,
        avatar: item.avatar,
        status: item.status,
        profile: encodeProfileParam(item.profile || {
          id: item.id,
          displayname: item.name,
          username: item.name,
          avatar_url: item.avatar,
        }),
      },
    });
  };

  const renderBackdrop = useCallback(
    (props: any) => <BottomSheetBackdrop {...props} disappearsOnIndex={-1} appearsOnIndex={0} />,
    []
  );

  const borderColor = dark ? '#1A1A1A' : '#F0F0F0';
  const textColor = dark ? '#FFFFFF' : '#000000';
  const secondaryTextColor = dark ? '#666666' : '#999999';
  const tabItemBg = dark ? '#0A0A0A' : '#F9F9F9';
  const headerHeight = 60 + insets.top;

  const FILTER_TABS = [
    { id: 'all', label: 'All', icon: MessageSquare },
    { id: 'unread', label: 'Unread', icon: CircleDot },
    { id: 'pinned', label: 'Pinned', icon: Pin },
  ];

  return (
    <View style={[styles.container, { backgroundColor: colors.background }]}>
      <StatusBar barStyle={dark ? 'light-content' : 'dark-content'} />
      
      <FlatList
        style={{ flex: 1 }}
        data={listData}
        keyExtractor={(item) => item.id}
        onEndReached={() => {
          if (!loading && cursor && cursor !== lastLoadMoreCursorRef.current) {
            lastLoadMoreCursorRef.current = cursor;
            dispatch(fetchChats({ limit: 20, cursor }));
          }
        }}
        onEndReachedThreshold={0.45}
        contentContainerStyle={{
          paddingTop: headerHeight,
          paddingBottom: insets.bottom + 100,
          flexGrow: 1,
        }}
        ListHeaderComponent={
          <View>
             {/* Favorites Section */}
             <View style={styles.sectionTitleRow}>
                <ThemedText style={styles.sectionTitle}>Favorites</ThemedText>
                <Pressable onPress={() => { lastChatsRef.current = []; lastConversationsRef.current = []; lastLoadMoreCursorRef.current = null; dispatch(resetChats()); dispatch(fetchChats({ limit: 20 })); }}>
                    <RefreshCcw size={14} color={secondaryTextColor} />
                </Pressable>
             </View>
             
             <FlatList
               horizontal
               data={favorites}
               showsHorizontalScrollIndicator={false}
               keyExtractor={(item) => item.id}
               contentContainerStyle={styles.favoritesList}
               renderItem={({ item, index }) => (
                 <Animated.View entering={FadeInDown.delay(index * 50)} style={styles.favoriteItem}>
                   <Pressable 
                    onPress={() => router.push({
                        pathname: '/ChatDetail',
                        params: {
                          chatId: item.id,
                          name: item.name,
                          username: item.name,
                          avatar: item.avatar,
                          status: 'Online',
                          profile: encodeProfileParam({
                            id: item.id,
                            displayname: item.name,
                            username: item.name,
                            avatar_url: item.avatar,
                          }),
                        },
                      })}
                    style={styles.favoritePress}>
                     <View style={[styles.favoriteAvatarContainer, { borderColor: borderColor }]}>
                        <Image source={{ uri: item.avatar }} style={styles.favoriteAvatar} contentFit="cover" />
                        {item.online && <View style={[styles.statusDot, { backgroundColor: textColor, borderColor: colors.background }]} />}
                     </View>
                     <ThemedText numberOfLines={1} style={[styles.favoriteName, { color: textColor }]}>
                       {item.name}
                     </ThemedText>
                   </Pressable>
                 </Animated.View>
               )}
             />

             {/* Premium Capsule filter tabs matching Activity screen */}
             <View style={styles.filterContainer}>
                <ScrollView 
                    horizontal 
                    showsHorizontalScrollIndicator={false}
                    contentContainerStyle={styles.tabScrollContent}
                >
                    {FILTER_TABS.map((tab) => {
                        const isActive = activeFilter === tab.id;
                        return (
                            <TouchableOpacity 
                                key={tab.id}
                                onPress={() => setActiveFilter(tab.id as any)}
                                style={[
                                    styles.premiumTab,
                                    { 
                                        backgroundColor: isActive ? (dark ? '#FFF' : '#000') : tabItemBg,
                                        borderColor: isActive ? (dark ? '#FFF' : '#000') : borderColor,
                                    }
                                ]}
                                activeOpacity={0.8}
                            >
                                <tab.icon 
                                    size={14} 
                                    color={isActive ? (dark ? '#000' : '#FFF') : (dark ? '#444' : '#AAA')} 
                                    strokeWidth={isActive ? 2.5 : 2} 
                                />
                                <ThemedText style={[
                                    styles.premiumTabText,
                                    { 
                                        color: isActive ? (dark ? '#000' : '#FFF') : (dark ? '#666' : '#888'),
                                    }
                                ]}>
                                    {tab.label}
                                </ThemedText>
                            </TouchableOpacity>
                        );
                    })}
                </ScrollView>
             </View>
          </View>
        }
        renderItem={({ item, index }) => (
          <Animated.View entering={FadeIn.delay(50 + index * 15)}>
            <Pressable
              onPress={() => handleRowPress(item)}
              onLongPress={() => handleLongPress(item)}
              delayLongPress={200}
              style={({ pressed }) => [
                styles.chatRow,
                { borderBottomColor: borderColor, opacity: pressed ? 0.5 : 1 }
              ]}>
              <View style={styles.avatarWrap}>
                <Image source={{ uri: item.avatar }} style={[styles.avatar, { borderColor: borderColor }]} contentFit="cover" />
                {item.online && <View style={[styles.rowStatusDot, { backgroundColor: textColor, borderColor: colors.background }]} />}
              </View>

              <View style={styles.rowBody}>
                <View style={styles.rowTop}>
                  <View style={styles.rowNameContainer}>
                    {item.pinned && <MaterialCommunityIcons name="pin" size={12} color={textColor} style={{ marginRight: 4 }} />}
                    <ThemedText numberOfLines={1} style={[styles.rowName, { color: textColor }, item.unreadCount > 0 && { fontFamily: 'Inter-Bold' }]}>
                        {item.name}
                    </ThemedText>
                  </View>
                  <ThemedText style={[styles.rowTime, { color: secondaryTextColor }]}>
                    {item.timestamp}
                  </ThemedText>
                </View>
                <View style={styles.rowBottom}>
                  <ThemedText
                    numberOfLines={1}
                    style={[
                      styles.rowPreview,
                      { color: item.unreadCount > 0 ? textColor : secondaryTextColor },
                      item.unreadCount > 0 && { fontFamily: 'Inter-SemiBold' }
                    ]}>
                    {item.preview}
                  </ThemedText>
                  {item.unreadCount > 0 && (
                    <View style={[styles.unreadMark, { backgroundColor: textColor }]}>
                      <ThemedText style={[styles.unreadText, { color: colors.background }]}>
                        {item.unreadCount}
                      </ThemedText>
                    </View>
                  )}
                </View>
              </View>
            </Pressable>
          </Animated.View>
        )}
        ListEmptyComponent={
          !loading && listData.length === 0 ? (
            <View style={{ paddingTop: 80, alignItems: 'center' }}>
              <ThemedText style={{ color: secondaryTextColor }}>No conversations yet.</ThemedText>
            </View>
          ) : null
        }
        ListFooterComponent={
          loading ? (
            <View style={{ paddingVertical: 20, alignItems: 'center' }}>
              <ThemedText style={{ color: secondaryTextColor }}>Loading…</ThemedText>
            </View>
          ) : null
        }
      />

      {/* Modern B&W Bottom Sheet Modal */}
      <BaseBottomSheetModal
        ref={bottomSheetModalRef}
        backdropComponent={renderBackdrop}
        backgroundStyle={{ backgroundColor: dark ? '#000' : '#FFF' }}
      >
        <BottomSheetView style={styles.sheetContent}>
            <View style={styles.sheetHeader}>
                <View style={styles.sheetAvatarContainer}>
                    <Image source={{ uri: selectedChat?.avatar }} style={styles.sheetAvatar} />
                </View>
                <View style={{ flex: 1, marginLeft: 12 }}>
                    <ThemedText style={styles.sheetTitle}>{selectedChat?.name}</ThemedText>
                    <ThemedText style={[styles.sheetSub, { color: secondaryTextColor }]}>Conversation options</ThemedText>
                </View>
                <TouchableOpacity onPress={() => bottomSheetModalRef.current?.dismiss()} style={styles.closeBtn}>
                   <X size={20} color={textColor} />
                </TouchableOpacity>
            </View>

            <View style={styles.sheetOptions}>
                <OptionItem 
                    icon={<Pin size={20} color={textColor} />} 
                    label={selectedChat?.pinned ? "Unpin Chat" : "Pin"} 
                    onPress={() => selectedChat && handleTogglePin(selectedChat.id, selectedChat.pinned)}
                    textColor={textColor}
                />
                <View style={[styles.separator, { backgroundColor: borderColor }]} />
                
                <OptionItem 
                    icon={<Trash2 size={20} color={textColor} />} 
                    label="Delete For Me" 
                    onPress={() => selectedChat && handleDelete(selectedChat.id)}
                    textColor={textColor}
                />
                <OptionItem 
                    icon={<Trash2 size={20} color="#FF453A" />} 
                    label="Delete For All" 
                    onPress={() => selectedChat && handleDelete(selectedChat.id)}
                    textColor="#FF453A"
                />
                <View style={[styles.separator, { backgroundColor: borderColor }]} />
                
                <OptionItem 
                    icon={<Eraser size={20} color={textColor} />} 
                    label="Clear Chat History for Me" 
                    onPress={() => bottomSheetModalRef.current?.dismiss()}
                    textColor={textColor}
                />
                <OptionItem 
                    icon={<Eraser size={20} color="#FF453A" />} 
                    label="Clear Chat History For All" 
                    onPress={() => bottomSheetModalRef.current?.dismiss()}
                    textColor="#FF453A"
                />
            </View>
            <View style={{ height: insets.bottom + 20 }} />
        </BottomSheetView>
      </BaseBottomSheetModal>
    </View>
  );
}

function OptionItem({ icon, label, onPress, textColor }: any) {
    return (
        <TouchableOpacity onPress={onPress} style={styles.optionItem}>
            <View style={styles.optionIcon}>{icon}</View>
            <ThemedText style={[styles.optionLabel, { color: textColor }]}>{label}</ThemedText>
        </TouchableOpacity>
    );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  sectionTitleRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 20,
    marginTop: 20,
    marginBottom: 16,
  },
  sectionTitle: {
    fontSize: 13,
    fontFamily: 'Inter-Bold',
    textTransform: 'uppercase',
    letterSpacing: 1.2,
    opacity: 0.7,
  },
  favoritesList: {
    paddingLeft: 20,
    paddingRight: 10,
    marginBottom: 24,
  },
  favoriteItem: {
    width: 68,
    marginRight: 12,
  },
  favoritePress: {
    alignItems: 'center',
    gap: 8,
  },
  favoriteAvatarContainer: {
    width: 60,
    height: 60,
    borderRadius: 30,
    borderWidth: 1.5,
    padding: 3,
  },
  favoriteAvatar: {
    width: '100%',
    height: '100%',
    borderRadius: 27,
  },
  statusDot: {
    position: 'absolute',
    bottom: -1,
    right: -1,
    width: 15,
    height: 15,
    borderRadius: 7.5,
    borderWidth: 3,
  },
  favoriteName: {
    fontSize: 11,
    fontFamily: 'Inter-Bold',
    textAlign: 'center',
    opacity: 0.8,
  },
  filterContainer: {
    width: '100%',
    paddingVertical: 12,
    zIndex: 10,
  },
  tabScrollContent: {
    paddingHorizontal: 20,
    gap: 8,
  },
  premiumTab: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 24,
    borderWidth: 1,
    gap: 8,
  },
  premiumTabText: {
    fontSize: 12,
    fontFamily: 'Inter-Bold',
    letterSpacing: -0.2,
  },
  chatRow: {
    flexDirection: 'row',
    paddingHorizontal: 20,
    paddingVertical: 16,
    borderBottomWidth: 0.5,
    alignItems: 'center',
    gap: 16,
  },
  avatarWrap: {
    width: 56,
    height: 56,
  },
  avatar: {
    width: 56,
    height: 56,
    borderRadius: 28,
    borderWidth: 0.5,
  },
  rowStatusDot: {
    position: 'absolute',
    bottom: 0,
    right: 0,
    width: 14,
    height: 14,
    borderRadius: 7,
    borderWidth: 3,
  },
  rowBody: {
    flex: 1,
    gap: 4,
  },
  rowTop: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  rowNameContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  rowName: {
    fontSize: 16,
    fontFamily: 'Inter-SemiBold',
  },
  rowTime: {
    fontSize: 11,
    fontFamily: 'Inter-Medium',
  },
  rowBottom: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  rowPreview: {
    flex: 1,
    fontSize: 13,
    lineHeight: 18,
    opacity: 0.7,
  },
  unreadMark: {
    minWidth: 18,
    height: 18,
    borderRadius: 9,
    alignItems: 'center',
    justifyContent: 'center',
    marginLeft: 8,
    paddingTop: 1,
  },
  unreadText: {
    fontSize: 10,
    fontFamily: 'Inter-Bold',
    lineHeight: 12,
    textAlign: 'center',
  },
  sheetContent: {
    padding: 24,
  },
  sheetHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 32,
  },
  sheetAvatarContainer: {
    width: 50,
    height: 50,
    borderRadius: 25,
    overflow: 'hidden',
    backgroundColor: '#333',
  },
  sheetAvatar: {
    width: '100%',
    height: '100%',
  },
  sheetTitle: {
    fontSize: 20,
    fontFamily: 'Outfit-Bold',
  },
  sheetSub: {
    fontSize: 13,
    fontFamily: 'Inter-Medium',
  },
  closeBtn: {
    padding: 8,
    borderRadius: 20,
    backgroundColor: 'rgba(150,150,150,0.1)',
  },
  sheetOptions: {
    gap: 4,
  },
  optionItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 16,
    paddingHorizontal: 12,
  },
  optionIcon: {
    width: 32,
    alignItems: 'center',
  },
  optionLabel: {
    fontSize: 16,
    fontFamily: 'Inter-SemiBold',
    marginLeft: 16,
  },
  separator: {
    height: 1,
    marginVertical: 8,
    opacity: 0.5,
  },
});
