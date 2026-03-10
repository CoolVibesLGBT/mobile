import React, { useEffect, useMemo, useState, useRef, useCallback } from 'react';
import { StyleSheet, View, Dimensions, FlatList, StatusBar, Pressable, TouchableOpacity, ScrollView } from 'react-native';
import { FlashList } from '@shopify/flash-list';
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
};

const PINNED_MOCK: PinnedItem[] = [
  { id: 'pin-1', name: 'Ayla', avatar: 'https://picsum.photos/seed/match1/200', online: true },
  { id: 'pin-2', name: 'Mert', avatar: 'https://picsum.photos/seed/match2/200', online: true },
  { id: 'pin-3', name: 'Lina', avatar: 'https://picsum.photos/seed/match3/200', online: false },
  { id: 'pin-4', name: 'Cem', avatar: 'https://picsum.photos/seed/match4/200', online: false },
  { id: 'pin-5', name: 'Deniz', avatar: 'https://picsum.photos/seed/match5/200', online: true },
];

const MOCK_CONVERSATIONS: ConversationItem[] = [
  {
    id: 'chat-1',
    name: 'Ayla Demir',
    preview: 'Roof bar plan still on for tonight?',
    timestamp: '09:24',
    unreadCount: 3,
    pinned: true,
    online: true,
    avatar: 'https://picsum.photos/seed/chat1/200',
    status: 'Typing...',
  },
  {
    id: 'chat-2',
    name: 'Mert K.',
    preview: 'I shared the place pin. Check the route when free.',
    timestamp: '08:10',
    unreadCount: 0,
    pinned: true,
    online: false,
    avatar: 'https://picsum.photos/seed/chat2/200',
    status: 'Seen 12m ago',
  },
  {
    id: 'chat-3',
    name: 'Lina',
    preview: 'Your last photo set looks sharp.',
    timestamp: 'Yesterday',
    unreadCount: 1,
    pinned: false,
    online: true,
    avatar: 'https://picsum.photos/seed/chat3/200',
    status: 'Online',
  },
];

function normalizeChat(chat: any, index: number): ConversationItem {
  const counterpart =
    chat?.other_user ||
    chat?.user ||
    chat?.participant ||
    chat?.match ||
    chat?.receiver ||
    chat?.sender ||
    {};

  const fallback = MOCK_CONVERSATIONS[index % MOCK_CONVERSATIONS.length];
  const name =
    counterpart?.displayname ||
    counterpart?.display_name ||
    counterpart?.username ||
    chat?.name ||
    fallback.name;
  const preview =
    chat?.last_message?.text ||
    chat?.last_message_text ||
    chat?.message ||
    fallback.preview;
  const timestampSource =
    chat?.last_message_timestamp ||
    chat?.updated_at ||
    chat?.timestamp ||
    fallback.timestamp;

  return {
    id: String(chat?.id ?? fallback.id),
    name,
    preview,
    timestamp: typeof timestampSource === 'string' ? timestampSource.slice(0, 16) : fallback.timestamp,
    unreadCount: Number(chat?.unread_count ?? chat?.unread ?? fallback.unreadCount),
    pinned: Boolean(chat?.is_pinned ?? fallback.pinned),
    online: Boolean(counterpart?.online ?? fallback.online),
    avatar: counterpart?.avatar_url || counterpart?.avatarUrl || fallback.avatar,
    status: counterpart?.online ? 'Online' : fallback.status,
  };
}

export default function ChatScreen() {
  const { colors, dark } = useTheme();
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const dispatch = useAppDispatch();
  const { chats, loading, cursor } = useAppSelector((state) => state.chat);

  const [activeFilter, setActiveFilter] = useState<FilterKey>('all');
  const [pinnedIds, setPinnedIds] = useState<Record<string, boolean>>({});
  const [deletedIds, setDeletedIds] = useState<Record<string, boolean>>({});
  const [selectedChat, setSelectedChat] = useState<ConversationItem | null>(null);

  const bottomSheetModalRef = useRef<BottomSheetModal>(null);

  useEffect(() => {
    dispatch(resetChats());
    dispatch(fetchChats({ limit: 20 }));
  }, [dispatch]);

  const conversations = useMemo(() => {
    const base = chats.length > 0 ? chats.map(normalizeChat) : MOCK_CONVERSATIONS;

    return base.filter((item) => {
      if (deletedIds[item.id]) return false;
      const isPinned = pinnedIds[item.id] || item.pinned;
      const matchesFilter =
        activeFilter === 'all' ||
        (activeFilter === 'unread' && item.unreadCount > 0) ||
        (activeFilter === 'pinned' && isPinned);

      return matchesFilter;
    }).map(item => ({...item, pinned: pinnedIds[item.id] || item.pinned}));
  }, [activeFilter, chats, deletedIds, pinnedIds]);

  const favorites = useMemo(() => {
    const pinned = conversations.filter(c => c.pinned);
    return pinned.length > 0 
      ? pinned.map(c => ({ id: c.id, name: c.name, avatar: c.avatar, online: c.online }))
      : PINNED_MOCK;
  }, [conversations]);

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
        avatar: item.avatar,
        status: item.status,
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
      
      <FlashList
        data={conversations}
        // @ts-ignore
        estimatedItemSize={84}
        keyExtractor={(item) => item.id}
        onEndReached={() => {
          if (!loading && cursor) {
            dispatch(fetchChats({ limit: 20, cursor }));
          }
        }}
        onEndReachedThreshold={0.45}
        contentContainerStyle={{
          paddingTop: headerHeight,
          paddingBottom: insets.bottom + 100,
        }}
        ListHeaderComponent={
          <View>
             {/* Favorites Section */}
             <View style={styles.sectionTitleRow}>
                <ThemedText style={styles.sectionTitle}>Favorites</ThemedText>
                <Pressable onPress={() => { dispatch(resetChats()); dispatch(fetchChats({ limit: 20 })); }}>
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
                        params: { chatId: item.id, name: item.name, avatar: item.avatar, status: 'Online' },
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
