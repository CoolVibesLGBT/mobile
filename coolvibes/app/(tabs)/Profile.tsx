import React, { useState, useRef } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Image,
  Dimensions,
  Platform,
  UIManager,
  StatusBar,
  Animated,
} from 'react-native';
import { ThemedView } from '@/components/ThemedView';
import { ThemedText } from '@/components/ThemedText';
import { useTheme } from '@react-navigation/native';
import MaterialCommunityIcons from '@expo/vector-icons/MaterialCommunityIcons';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import ProfileAboutView from '@/components/ProfileAboutView';
import AuthWizard from '@/components/AuthWizard';

if (Platform.OS === 'android' && UIManager.setLayoutAnimationEnabledExperimental) {
  UIManager.setLayoutAnimationEnabledExperimental(true);
}

const { width } = Dimensions.get('window');
const POST_ITEM_SIZE = (width - 4) / 3;
const BANNER_HEIGHT = 250;
const HEADER_FADE_START = BANNER_HEIGHT - 100;
const HEADER_FADE_END = BANNER_HEIGHT - 50;

// Use mock data structure
const mockUserData = {
    user: {
        username: "coolvibes",
        displayname: "coolvibes",
        bio: "The best app in the world. Building the future of social media, one line of code at a time.",
        avatar_url: "https://pbs.twimg.com/profile_images/1960662542801625088/ntOOL4M-_400x400.jpg",
        banner_url: "https://pbs.twimg.com/profile_banners/4614357675/1755441597/1500x500",
        location: "San Francisco, CA",
        created_at: "2026-02-25T14:48:55.99977+03:00",
        following_count: 2,
        followers_count: 12,
        posts_count: 21,
        // Profile attributes for ProfileAboutView
        gender: "Male",
        sexual_orientation: { name: "Straight" },
        sex_role: { name: "Dominant" },
        relationship_status: "Single",
        height: { name: "180cm" },
        weight: { name: "80kg" },
        body_type: { name: "Athletic" },
        zodiac_sign: { name: "Leo" },
        interests: [
            { id: '1', name: 'Photography', emoji: '📷' }, 
            { id: '2', name: 'Gaming', emoji: '🎮' }, 
            { id: '3', name: 'Traveling', emoji: '✈️' }
        ],
        fantasies: [
            { id: '1', name: 'Being a pilot', emoji: '✈️' }, 
            { id: '2', name: 'Writing a novel', emoji: '✍️' }
        ],
    }
};

const user = mockUserData.user;

const TABS = [
  { key: 'about', title: 'About', icon: 'account-details-outline' },
  { key: 'posts', title: 'Posts', icon: 'grid' },
  { key: 'media', title: 'Media', icon: 'image-multiple-outline' },
  { key: 'comments', title: 'Comments', icon: 'comment-outline' },
  { key: 'likes', title: 'Likes', icon: 'heart-outline' },
];

// --- MAIN SCREEN COMPONENT ---
export function ProfileScreen(): React.JSX.Element {
  const { colors, dark } = useTheme();
  const [activeTab, setActiveTab] = useState(TABS[0].key);
  const [isAuthModalOpen, setIsAuthModalOpen] = useState(false);
  const scrollY = useRef(new Animated.Value(0)).current;
  const insets = useSafeAreaInsets();

  // Monochrome colors
  const textColor = dark ? '#FFFFFF' : '#000000';
  const backgroundColor = dark ? '#000000' : '#FFFFFF';
  const invertedTextColor = dark ? '#000000' : '#FFFFFF';
  const borderColor = dark ? '#2F2F2F' : '#EBEBEB';

  const stickyHeaderOpacity = scrollY.interpolate({
    inputRange: [HEADER_FADE_START, HEADER_FADE_END],
    outputRange: [0, 1],
    extrapolate: 'clamp',
  });

  const stickyHeaderTranslateY = scrollY.interpolate({
    inputRange: [HEADER_FADE_START, HEADER_FADE_END],
    outputRange: [-20, 0],
    extrapolate: 'clamp',
  });

  const ProfileTabs = () => (
    <View style={[styles.tabsContainer, { borderBottomColor: borderColor, backgroundColor: backgroundColor }]}>
      {TABS.map(tab => (
        <TouchableOpacity key={tab.key} onPress={() => setActiveTab(tab.key)} style={styles.tab}>
            <View style={{alignItems: 'center'}}>
                <ThemedText style={{fontWeight: activeTab === tab.key ? 'bold' : 'normal', opacity: activeTab === tab.key ? 1 : 0.6, fontSize: 16}}>{tab.title}</ThemedText>
            </View>
            {activeTab === tab.key && <View style={[styles.tabIndicator, {backgroundColor: textColor}]} />}
        </TouchableOpacity>
      ))}
    </View>
  );

  const renderContent = () => {
    switch (activeTab) {
      case 'about':
        return <ProfileAboutView user={user} />;
      case 'posts':
      case 'comments':
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
                <View style={[styles.postLine, {backgroundColor: borderColor, width: '80%'}]} />
              </View>
            ))}
          </View>
        );
      case 'media':
        return (
          <View style={styles.postsGrid}>
            {Array.from({ length: 12 }).map((_, index) => (
              <TouchableOpacity key={index} style={styles.postItem}>
                <Image source={{ uri: `https://picsum.photos/id/${index + 20}/300/300` }} style={styles.postImage} />
              </TouchableOpacity>
            ))}
          </View>
        );
      default:
        return (
            <ThemedView style={styles.emptyContentContainer}>
              <MaterialCommunityIcons name="compass-off-outline" size={48} color={textColor} style={{ opacity: 0.3 }} />
              <ThemedText style={styles.emptyContent}>No {activeTab} yet.</ThemedText>
            </ThemedView>
        );
    }
  };

  return (
    <View style={[styles.screen, { backgroundColor: backgroundColor }]}>
        <StatusBar translucent backgroundColor="transparent" barStyle={dark ? 'light-content' : 'dark-content'} />
        {/* Sticky Header - REMOVED to avoid clash with GlobalHeader */}
        {/* 
        <Animated.View style={[
          styles.stickyHeader,
          { backgroundColor: backgroundColor, height: insets.top + 50, paddingTop: insets.top, opacity: stickyHeaderOpacity }
        ]}>
          <Animated.View style={[styles.stickyHeaderContent, {transform: [{ translateY: stickyHeaderTranslateY }]}]}>
            <Image
              source={{ uri: user.avatar_url }}
              style={styles.stickyAvatar}
            />
            <Text style={[styles.stickyHeaderText, { color: textColor }]}>{user.displayname}</Text>
          </Animated.View>
        </Animated.View>
        */}

        <Animated.ScrollView
            onScroll={Animated.event(
                [{ nativeEvent: { contentOffset: { y: scrollY } } }],
                { useNativeDriver: true }
            )}
            contentContainerStyle={{ paddingBottom: insets.bottom + 100, paddingTop: 60 + insets.top }} 
            scrollEventThrottle={16}
            showsVerticalScrollIndicator={false}
            bounces={false}
        >
          <View style={styles.bannerContainer}>
              <Image source={{ uri: user.banner_url }} style={styles.headerImage}/>
          </View>
          
          <View style={styles.contentContainer}>
              <View style={styles.headerSection}>
                  <View style={[styles.avatarContainer, {borderColor: backgroundColor}]}>
                      <Image 
                          source={{ uri: user.avatar_url }}
                          style={styles.avatar}
                      />
                  </View>
                  <View style={styles.headerActions}>
                      <TouchableOpacity style={[styles.iconButton, {borderColor: borderColor}]}>
                          <MaterialCommunityIcons name="dots-horizontal" size={20} color={textColor} />
                      </TouchableOpacity>
                      <TouchableOpacity 
                        style={[styles.editButton, { borderColor: borderColor }]}
                        onPress={() => setIsAuthModalOpen(true)}
                      >
                          <Text style={[styles.editButtonText, { color: textColor }]}>Edit Profile</Text>
                      </TouchableOpacity>
                  </View>
              </View>

              <View style={styles.userInfoSection}>
                  <ThemedText style={styles.name}>{user.displayname}</ThemedText>
                  <ThemedText style={styles.username}>@{user.username}</ThemedText>
                  <ThemedText style={styles.bio}>{user.bio}</ThemedText>
                  
                  <View style={styles.metadataSection}>
                      <MaterialCommunityIcons name="map-marker-outline" size={15} color={textColor} style={{opacity: 0.6}} />
                      <ThemedText style={styles.metadataText}>{user.location}</ThemedText>
                      <MaterialCommunityIcons name="calendar-month-outline" size={15} color={textColor} style={{opacity: 0.6, marginLeft: 16}} />
                      <ThemedText style={styles.metadataText}>Joined February 2026</ThemedText>
                  </View>

                  <View style={styles.statsSection}>
                      <TouchableOpacity style={styles.statItem}><Text style={[styles.statNumber, { color: textColor }]}>{user.following_count}</Text><ThemedText style={styles.statLabel}>Following</ThemedText></TouchableOpacity>
                      <TouchableOpacity style={styles.statItem}><Text style={[styles.statNumber, { color: textColor }]}>{user.followers_count}</Text><ThemedText style={styles.statLabel}>Followers</ThemedText></TouchableOpacity>
                  </View>
              </View>
          </View>
          <ProfileTabs />
          {renderContent()}
        </Animated.ScrollView>

        <AuthWizard 
          isOpen={isAuthModalOpen}
          onClose={() => setIsAuthModalOpen(false)}
        />
    </View>
  );
}

// --- STYLES ---
const styles = StyleSheet.create({
  screen: { flex: 1 },
  bannerContainer: { height: BANNER_HEIGHT, overflow: 'hidden', alignItems: 'center' },
  headerImage: { width: '100%', height: '100%', backgroundColor: '#ccc' },
  contentContainer: { backgroundColor: 'transparent', zIndex: 1, },
  headerSection: { marginTop: -40, paddingHorizontal: 16, paddingBottom: 12, flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-end',},
  avatarContainer: { width: 90, height: 90, borderRadius: 45, borderWidth: 4, shadowColor: '#000', shadowOffset: { width: 0, height: 2 }, shadowOpacity: 0.3, shadowRadius: 4, elevation: 8, backgroundColor: '#000' },
  avatar: { width: '100%', height: '100%', borderRadius: 41 },
  headerActions: { flexDirection: 'row', alignItems: 'center' },
  iconButton: { width: 36, height: 36, borderRadius: 18, borderWidth: 1, justifyContent: 'center', alignItems: 'center', marginRight: 10 },
  editButton: { paddingVertical: 10, paddingHorizontal: 20, borderRadius: 25, borderWidth: 1.5 },
  editButtonText: { fontFamily: 'Inter-Bold', fontSize: 13, textTransform: 'uppercase', letterSpacing: 0.5 },
  followButton: { paddingVertical: 10, paddingHorizontal: 24, borderRadius: 25 },
  followButtonText: { fontFamily: 'Inter-Bold', fontSize: 13 },
  userInfoSection: { paddingHorizontal: 20, paddingTop: 10, paddingBottom: 20 },
  name: { fontSize: 32, fontFamily: 'Outfit-Black', letterSpacing: -1, textTransform: 'uppercase' },
  username: { fontSize: 15, opacity: 0.5, marginTop: -2, fontFamily: 'Inter-SemiBold' },
  bio: { marginTop: 16, fontSize: 15, lineHeight: 22, fontFamily: 'Inter-Regular', opacity: 0.8 },
  metadataSection: { flexDirection: 'row', alignItems: 'center', marginTop: 16 },
  metadataText: { marginLeft: 6, fontSize: 13, opacity: 0.5, fontFamily: 'Inter-SemiBold' },
  statsSection: { flexDirection: 'row', marginTop: 20, gap: 24 },
  statItem: { flexDirection: 'row', alignItems: 'center' },
  statNumber: { fontFamily: 'Inter-Bold', fontSize: 16, letterSpacing: -0.5 },
  statLabel: { marginLeft: 6, fontSize: 14, opacity: 0.5, fontFamily: 'Inter-SemiBold', textTransform: 'lowercase' },
  tabsContainer: { flexDirection: 'row', borderBottomWidth: 1, justifyContent: 'space-around', },
  tab: { alignItems: 'center', paddingVertical: 12, flex: 1 },
  tabIndicator: { position: 'absolute', bottom: 0, height: 2, width: '60%', borderRadius: 2 },
  postsGrid: { flexDirection: 'row', flexWrap: 'wrap', padding: 1 },
  postItem: { width: POST_ITEM_SIZE, height: POST_ITEM_SIZE, padding: 1 },
  postImage: { width: '100%', height: '100%' },
  postPlaceholder: { width: '100%', padding: 16, borderBottomWidth: 1 },
  postHeader: { flexDirection: 'row', marginBottom: 12 },
  postAvatar: { width: 40, height: 40, borderRadius: 20, marginRight: 12 },
  postHeaderInfo: { flex: 1, justifyContent: 'center' },
  postLineHeader: { height: 12, borderRadius: 6, marginBottom: 8, width: '60%' },
  postLineSub: { height: 10, borderRadius: 5 },
  postLine: { height: 12, borderRadius: 6, marginBottom: 8 },
  emptyContentContainer: { alignItems: 'center', justifyContent: 'center', padding: 48, minHeight: 200 },
  emptyContent: { textAlign: 'center', marginTop: 16, fontSize: 16, opacity: 0.6 },
  stickyHeader: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    zIndex: 10,
    justifyContent: 'center',
    alignItems: 'center',
    borderBottomWidth: 1,
    borderColor: 'rgba(0,0,0,0.1)',
  },
  stickyHeaderContent: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  stickyAvatar: {
    width: 36,
    height: 36,
    borderRadius: 18,
    marginRight: 12,
  },
  stickyHeaderText: {
    fontSize: 18,
    fontWeight: '600',
  },
});

export default ProfileScreen;