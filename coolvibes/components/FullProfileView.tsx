import React, { useState, useRef } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Dimensions,
  Animated,
  RefreshControlProps,
  useWindowDimensions,
} from 'react-native';
import { Image } from 'expo-image';
import { useTheme } from '@react-navigation/native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { MapPin, Calendar, MessageSquare, Plus, Edit2, Wallet } from 'lucide-react-native';
import MaterialCommunityIcons from '@expo/vector-icons/MaterialCommunityIcons';
import ProfileAboutView from './ProfileAboutView';
import RenderHTML from 'react-native-render-html';
import { BottomSheetScrollView } from '@gorhom/bottom-sheet';

const { width } = Dimensions.get('window');
const POST_ITEM_SIZE = (width - 2) / 3;
const BANNER_HEIGHT = 200;

type FullProfileViewProps = {
    user: any;
    isMe?: boolean;
    onMessage?: () => void;
    onFollow?: () => void;
    onEdit?: () => void;
    onWallet?: () => void;
    refreshControl?: React.ReactElement<RefreshControlProps>;
    useBottomSheetScroll?: boolean;
};

const TABS = [
  { key: 'about', title: 'About' },
  { key: 'posts', title: 'Posts' },
  { key: 'media', title: 'Media' },
  { key: 'likes', title: 'Likes' },
];

export default function FullProfileView({ user, isMe, onMessage, onFollow, onEdit, onWallet, refreshControl, useBottomSheetScroll }: FullProfileViewProps) {
  const { dark } = useTheme();
  const [activeTab, setActiveTab] = useState(TABS[0].key);
  const insets = useSafeAreaInsets();
  const scrollY = useRef(new Animated.Value(0)).current;
  const { width: windowWidth } = useWindowDimensions();

  // Monochrome colors
  const textColor = dark ? '#FFFFFF' : '#000000';
  const backgroundColor = dark ? '#000000' : '#FFFFFF';
  const secondaryText = dark ? '#888888' : '#666666';
  const borderColor = dark ? '#1A1A1A' : '#F0F0F0';
  const cardColor = dark ? '#0F0F0F' : '#F9F9F9';

  const getJoinedDate = () => {
    if (!user.created_at) return 'Recently';
    try {
      const date = new Date(user.created_at);
      return `Joined ${date.toLocaleString('en-US', { month: 'short', year: 'numeric' })}`;
    } catch {
      return 'Recently';
    }
  };

  const renderTabContent = () => {
    switch (activeTab) {
      case 'about':
        return <ProfileAboutView user={user} />;
      case 'posts':
      case 'likes':
        return (
          <View style={styles.postsGrid}>
            {Array.from({ length: 6 }).map((_, index) => (
              <View key={index} style={[styles.postPlaceholder, { borderBottomColor: borderColor }]}>
                <View style={styles.postHeader}>
                    <View style={[styles.postAvatar, {backgroundColor: borderColor}]} />
                    <View style={styles.postHeaderInfo}>
                        <View style={[styles.postLineHeader, {backgroundColor: borderColor}]} />
                        <View style={[styles.postLineSub, {backgroundColor: borderColor, width: '40%'}]} />
                    </View>
                </View>
                <View style={[styles.postLine, {backgroundColor: borderColor}]} />
              </View>
            ))}
          </View>
        );
      case 'media':
        return (
          <View style={styles.postsGrid}>
            {Array.from({ length: 12 }).map((_, index) => (
              <TouchableOpacity key={index} style={styles.postItem}>
                <Image 
                    source={{ uri: `https://picsum.photos/seed/${index + user.id}/300/300` }} 
                    style={styles.postImage}
                    contentFit="cover"
                    transition={200}
                />
              </TouchableOpacity>
            ))}
          </View>
        );
      default:
        return null;
    }
  };

  const content = (
    <>
        {/* Banner */}
        <Animated.View style={styles.bannerContainer}>
          <Image
            source={{ uri: user.banner_url || `https://picsum.photos/seed/${user.id}banner/1500/500` }}
            style={styles.banner}
            contentFit="cover"
          />
          <View style={[styles.bannerOverlay, { backgroundColor: 'rgba(0,0,0,0.1)' }]} />
        </Animated.View>

        {/* Profile Info Header */}
        <View style={styles.headerInfo}>
          <View style={styles.avatarRow}>
            <View style={[styles.avatarContainer, { borderColor: backgroundColor, backgroundColor }]}>
              <Image source={{ uri: user.avatar_url }} style={styles.avatar} contentFit="cover" />
            </View>
            
            <View style={styles.actionButtons}>
              {isMe ? (
                <View style={styles.btnRow}>
                  <TouchableOpacity onPress={onWallet} style={[styles.circleBtn, { borderColor, backgroundColor: cardColor }]}>
                    <Wallet size={18} color={textColor} />
                  </TouchableOpacity>
                  <TouchableOpacity onPress={onEdit} style={[styles.actionBtn, { borderColor, backgroundColor: cardColor }]}>
                    <Edit2 size={16} color={textColor} />
                    <Text style={[styles.btnText, { color: textColor }]}>Edit</Text>
                  </TouchableOpacity>
                </View>
              ) : (
                <View style={styles.btnRow}>
                  <TouchableOpacity onPress={onMessage} style={[styles.circleBtn, { borderColor, backgroundColor: cardColor }]}>
                    <MessageSquare size={18} color={textColor} />
                  </TouchableOpacity>
                  <TouchableOpacity onPress={onFollow} style={[styles.actionBtn, { backgroundColor: textColor }]}>
                    <Plus size={16} color={backgroundColor} />
                    <Text style={[styles.btnText, { color: backgroundColor }]}>Follow</Text>
                  </TouchableOpacity>
                </View>
              )}
            </View>
          </View>

          <View style={styles.userInfo}>
            <View style={styles.nameRow}>
                <Text style={[styles.displayName, { color: textColor }]}>{user.displayname}</Text>
                {user.is_verified && (
                    <MaterialCommunityIcons name="check-decagram" size={20} color="#00BAFF" style={{ marginLeft: 8, marginTop: 4 }} />
                )}
            </View>
            <Text style={[styles.username, { color: secondaryText }]}>@{user.username || user.displayname?.toLowerCase().replace(/\s+/g, '')}</Text>
            
            {!!user.bioHtml ? (
              <RenderHTML
                contentWidth={Math.max(0, windowWidth - 32)}
                source={{ html: user.bioHtml }}
                baseStyle={[styles.bio, { color: textColor }]}
                defaultTextProps={{ selectable: false }}
              />
            ) : user.bio ? (
              <Text style={[styles.bio, { color: textColor }]}>{user.bio}</Text>
            ) : null}

            <View style={styles.metaRow}>
              <View style={styles.metaItem}>
                <MapPin size={14} color={secondaryText} />
                <Text style={[styles.metaText, { color: secondaryText }]}>{user.location || "Earth"}</Text>
              </View>
              <View style={[styles.metaItem, { marginLeft: 16 }]}>
                <Calendar size={14} color={secondaryText} />
                <Text style={[styles.metaText, { color: secondaryText }]}>{getJoinedDate()}</Text>
              </View>
            </View>

            <View style={styles.statsRow}>
              <TouchableOpacity style={styles.statItem}>
                <Text style={[styles.statValue, { color: textColor }]}>{user.followers_count || 0}</Text>
                <Text style={[styles.statLabel, { color: secondaryText }]}>Followers</Text>
              </TouchableOpacity>
              <TouchableOpacity style={[styles.statItem, { marginLeft: 24 }]}>
                <Text style={[styles.statValue, { color: textColor }]}>{user.following_count || 0}</Text>
                <Text style={[styles.statLabel, { color: secondaryText }]}>Following</Text>
              </TouchableOpacity>
              {user.posts_count > 0 && (
                <TouchableOpacity style={[styles.statItem, { marginLeft: 24 }]}>
                    <Text style={[styles.statValue, { color: textColor }]}>{user.posts_count}</Text>
                    <Text style={[styles.statLabel, { color: secondaryText }]}>Posts</Text>
                </TouchableOpacity>
              )}
            </View>
          </View>
        </View>

        {/* Tabs */}
        <View style={[styles.tabsWrapper, { backgroundColor, borderBottomColor: borderColor }]}>
          <View style={styles.tabsInner}>
            {TABS.map((tab) => (
              <TouchableOpacity
                key={tab.key}
                onPress={() => setActiveTab(tab.key)}
                style={styles.tabItem}
              >
                <Text style={[
                  styles.tabText,
                  { color: activeTab === tab.key ? textColor : secondaryText },
                  activeTab === tab.key && styles.tabTextActive
                ]}>
                  {tab.title}
                </Text>
                {activeTab === tab.key && (
                  <View style={[styles.tabIndicator, { backgroundColor: textColor }]} />
                )}
              </TouchableOpacity>
            ))}
          </View>
        </View>

        {/* Tab Content */}
        <View style={styles.contentArea}>
          {renderTabContent()}
        </View>
    </>
  );

  return (
    <View style={[styles.container, { backgroundColor }]}>
      {useBottomSheetScroll ? (
        <BottomSheetScrollView
          showsVerticalScrollIndicator={false}
          stickyHeaderIndices={[2]}
          contentContainerStyle={{ paddingBottom: insets.bottom + 100 }}
          scrollEventThrottle={16}
          refreshControl={refreshControl}
        >
          {content}
        </BottomSheetScrollView>
      ) : (
        <Animated.ScrollView
          showsVerticalScrollIndicator={false}
          stickyHeaderIndices={[2]} // Sticky Tabs
          contentContainerStyle={{ paddingBottom: insets.bottom + 100 }}
          scrollEventThrottle={16}
          refreshControl={refreshControl}
          onScroll={Animated.event(
            [{ nativeEvent: { contentOffset: { y: scrollY } } }],
            { useNativeDriver: false }
          )}
        >
          {content}
        </Animated.ScrollView>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  bannerContainer: { height: BANNER_HEIGHT, width: '100%', overflow: 'hidden' },
  banner: { width: '100%', height: '100%' },
  bannerOverlay: { ...StyleSheet.absoluteFillObject },
  headerInfo: { paddingHorizontal: 16, marginTop: -50 },
  avatarRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: 12 },
  avatarContainer: {
    width: 100,
    height: 100,
    borderRadius: 50,
    borderWidth: 4,
    overflow: 'hidden',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.1,
    shadowRadius: 10,
    elevation: 5,
  },
  avatar: { width: '100%', height: '100%' },
  actionButtons: { paddingBottom: 6 },
  btnRow: { flexDirection: 'row', gap: 8 },
  circleBtn: {
    width: 40,
    height: 40,
    borderRadius: 20,
    borderWidth: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  actionBtn: {
    height: 40,
    paddingHorizontal: 16,
    borderRadius: 20,
    borderWidth: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  btnText: { fontFamily: 'Inter-Bold', fontSize: 13, textTransform: 'uppercase', letterSpacing: 0.5 },
  userInfo: { marginTop: 4 },
  nameRow: { flexDirection: 'row', alignItems: 'center' },
  displayName: { fontSize: 28, fontFamily: 'Outfit-Black', letterSpacing: -0.5, textTransform: 'uppercase' },
  username: { fontSize: 15, fontFamily: 'Inter-Medium', marginTop: -2 },
  bio: { fontSize: 15, fontFamily: 'Inter-Regular', marginTop: 12, lineHeight: 22, opacity: 0.9 },
  metaRow: { flexDirection: 'row', alignItems: 'center', marginTop: 16 },
  metaItem: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  metaText: { fontSize: 13, fontFamily: 'Inter-SemiBold' },
  statsRow: { flexDirection: 'row', marginTop: 20, marginBottom: 10 },
  statItem: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  statValue: { fontSize: 16, fontFamily: 'Inter-Bold' },
  statLabel: { fontSize: 14, fontFamily: 'Inter-Medium', textTransform: 'lowercase' },
  
  tabsWrapper: { borderBottomWidth: 1 },
  tabsInner: { flexDirection: 'row', paddingHorizontal: 4 },
  tabItem: { flex: 1, paddingVertical: 18, alignItems: 'center' },
  tabText: { fontSize: 12, fontFamily: 'Inter-Bold', textTransform: 'uppercase', letterSpacing: 1 },
  tabTextActive: { opacity: 1 },
  tabIndicator: { position: 'absolute', bottom: 0, height: 2, width: '40%', borderRadius: 1 },
  
  contentArea: { flex: 1 },
  postsGrid: { flexDirection: 'row', flexWrap: 'wrap' },
  postItem: { width: POST_ITEM_SIZE, height: POST_ITEM_SIZE, margin: 0.3 },
  postImage: { width: '100%', height: '100%' },
  postPlaceholder: { width: '100%', padding: 16, borderBottomWidth: 1 },
  postHeader: { flexDirection: 'row', marginBottom: 12 },
  postAvatar: { width: 34, height: 34, borderRadius: 17, marginRight: 12 },
  postHeaderInfo: { flex: 1, justifyContent: 'center' },
  postLineHeader: { height: 10, borderRadius: 5, marginBottom: 6, width: '50%' },
  postLineSub: { height: 8, borderRadius: 4 },
  postLine: { height: 10, borderRadius: 5, width: '100%' },
});
