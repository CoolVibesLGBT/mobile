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
  Animated,
} from 'react-native';
import { ThemedView } from '@/components/ThemedView';
import { ThemedText } from '@/components/ThemedText';
import { useTheme } from '@react-navigation/native';
import MaterialCommunityIcons from '@expo/vector-icons/MaterialCommunityIcons';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { MapPin, Calendar, Users, Star, MessageSquare } from 'lucide-react-native';
import ProfileAboutView from './ProfileAboutView';

const { width } = Dimensions.get('window');
const POST_ITEM_SIZE = (width - 4) / 3;
const BANNER_HEIGHT = 220;

type FullProfileViewProps = {
    user: any;
    isMe?: boolean;
    onMessage?: () => void;
    onFollow?: () => void;
};

const TABS = [
  { key: 'about', title: 'About', icon: 'account-details-outline' },
  { key: 'posts', title: 'Posts', icon: 'grid' },
  { key: 'media', title: 'Media', icon: 'image-multiple-outline' },
  { key: 'likes', title: 'Likes', icon: 'heart-outline' },
];

export default function FullProfileView({ user, isMe, onMessage, onFollow }: FullProfileViewProps) {
  const { colors, dark } = useTheme();
  const [activeTab, setActiveTab] = useState(TABS[0].key);
  const scrollY = useRef(new Animated.Value(0)).current;
  const insets = useSafeAreaInsets();

  // Monochrome colors
  const textColor = dark ? '#FFFFFF' : '#000000';
  const backgroundColor = dark ? '#000000' : '#FFFFFF';
  const secondaryText = dark ? '#666666' : '#999999';
  const borderColor = dark ? '#1A1A1A' : '#F0F0F0';

  const ProfileTabs = () => (
    <View style={[styles.tabsContainer, { borderBottomColor: borderColor, backgroundColor: backgroundColor }]}>
      {TABS.map(tab => (
        <TouchableOpacity key={tab.key} onPress={() => setActiveTab(tab.key)} style={styles.tab}>
            <View style={{alignItems: 'center'}}>
                <Text style={{
                    fontFamily: activeTab === tab.key ? 'Inter-Bold' : 'Inter-Medium',
                    color: activeTab === tab.key ? textColor : secondaryText,
                    fontSize: 14,
                    textTransform: 'uppercase',
                    letterSpacing: 1
                }}>{tab.title}</Text>
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
            {Array.from({ length: 9 }).map((_, index) => (
              <TouchableOpacity key={index} style={styles.postItem}>
                <Image source={{ uri: `https://picsum.photos/seed/${index + user.id}/300/300` }} style={styles.postImage} />
              </TouchableOpacity>
            ))}
          </View>
        );
      default:
        return null;
    }
  };

  return (
    <View style={[styles.viewContainer, { backgroundColor: backgroundColor }]}>
        <Animated.ScrollView
            showsVerticalScrollIndicator={false}
            bounces={false}
            onScroll={Animated.event(
                [{ nativeEvent: { contentOffset: { y: scrollY } } }],
                { useNativeDriver: true }
            )}
        >
          <View style={styles.bannerContainer}>
              <Image source={{ uri: user.banner_url || `https://picsum.photos/seed/${user.id}banner/1500/500` }} style={styles.headerImage}/>
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
                      {!isMe ? (
                          <>
                            <TouchableOpacity onPress={onMessage} style={[styles.actionBtn, {backgroundColor: textColor}]}>
                                <MessageSquare size={18} color={backgroundColor} />
                            </TouchableOpacity>
                            <TouchableOpacity onPress={onFollow} style={[styles.actionBtn, {borderColor: textColor, borderWidth: 1}]}>
                                <Text style={[styles.actionBtnText, {color: textColor}]}>Follow</Text>
                            </TouchableOpacity>
                          </>
                      ) : (
                          <TouchableOpacity style={[styles.actionBtn, {borderColor: textColor, borderWidth: 1, paddingHorizontal: 20}]}>
                              <Text style={[styles.actionBtnText, {color: textColor}]}>Edit Profile</Text>
                          </TouchableOpacity>
                      )}
                  </View>
              </View>

              <View style={styles.userInfoSection}>
                  <Text style={[styles.name, { color: textColor }]}>{user.displayname}</Text>
                  <Text style={[styles.username, { color: secondaryText }]}>@{user.username || user.displayname.toLowerCase().replace(/\s/g, '')}</Text>
                  <Text style={[styles.bio, { color: textColor }]}>{user.bio || "No bio yet."}</Text>
                  
                  <View style={styles.metadataSection}>
                      <View style={styles.metaItem}>
                        <MapPin size={14} color={secondaryText} />
                        <Text style={[styles.metadataText, { color: secondaryText }]}>{user.location || "San Francisco, CA"}</Text>
                      </View>
                      <View style={[styles.metaItem, { marginLeft: 16 }]}>
                        <Calendar size={14} color={secondaryText} />
                        <Text style={[styles.metadataText, { color: secondaryText }]}>Joined Feb 2026</Text>
                      </View>
                  </View>

                  <View style={styles.statsSection}>
                      <View style={styles.statItem}>
                        <Text style={[styles.statNumber, { color: textColor }]}>{user.followers_count || 0}</Text>
                        <Text style={[styles.statLabel, { color: secondaryText }]}>Followers</Text>
                      </View>
                      <View style={[styles.statItem, { marginLeft: 24 }]}>
                        <Text style={[styles.statNumber, { color: textColor }]}>{user.following_count || 0}</Text>
                        <Text style={[styles.statLabel, { color: secondaryText }]}>Following</Text>
                      </View>
                  </View>
              </View>
          </View>
          <ProfileTabs />
          {renderContent()}
        </Animated.ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  viewContainer: { flex: 1 },
  bannerContainer: { height: BANNER_HEIGHT, overflow: 'hidden' },
  headerImage: { width: '100%', height: '100%', backgroundColor: '#111' },
  contentContainer: { marginTop: -50, paddingHorizontal: 16 },
  headerSection: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-end' },
  avatarContainer: { width: 100, height: 100, borderRadius: 50, borderWidth: 4, overflow: 'hidden', backgroundColor: '#000' },
  avatar: { width: '100%', height: '100%', borderRadius: 46 },
  headerActions: { flexDirection: 'row', alignItems: 'center', gap: 8, paddingBottom: 4 },
  actionBtn: { height: 40, paddingHorizontal: 12, borderRadius: 20, justifyContent: 'center', alignItems: 'center' },
  actionBtnText: { fontFamily: 'Inter-Bold', fontSize: 13, textTransform: 'uppercase', letterSpacing: 0.5 },
  userInfoSection: { paddingVertical: 16 },
  name: { fontSize: 32, fontFamily: 'Outfit-Black', letterSpacing: -1, textTransform: 'uppercase' },
  username: { fontSize: 15, fontFamily: 'Inter-SemiBold', marginTop: -2 },
  bio: { marginTop: 12, fontSize: 15, lineHeight: 22, fontFamily: 'Inter-Regular', opacity: 0.9 },
  metadataSection: { flexDirection: 'row', alignItems: 'center', marginTop: 16 },
  metaItem: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  metadataText: { fontSize: 13, fontFamily: 'Inter-SemiBold' },
  statsSection: { flexDirection: 'row', marginTop: 20 },
  statItem: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  statNumber: { fontFamily: 'Inter-Bold', fontSize: 16 },
  statLabel: { fontSize: 14, fontFamily: 'Inter-SemiBold', textTransform: 'lowercase' },
  tabsContainer: { flexDirection: 'row', borderBottomWidth: 1, paddingHorizontal: 4 },
  tab: { alignItems: 'center', paddingVertical: 16, flex: 1 },
  tabIndicator: { position: 'absolute', bottom: 0, height: 2, width: '40%', borderRadius: 1 },
  postsGrid: { flexDirection: 'row', flexWrap: 'wrap', padding: 1 },
  postItem: { width: POST_ITEM_SIZE, height: POST_ITEM_SIZE, padding: 1 },
  postImage: { width: '100%', height: '100%' },
  postPlaceholder: { width: '100%', padding: 16, borderBottomWidth: 1 },
  postHeader: { flexDirection: 'row', marginBottom: 12 },
  postAvatar: { width: 34, height: 34, borderRadius: 17, marginRight: 12 },
  postHeaderInfo: { flex: 1, justifyContent: 'center' },
  postLineHeader: { height: 10, borderRadius: 5, marginBottom: 6, width: '50%' },
  postLineSub: { height: 8, borderRadius: 4 },
  postLine: { height: 10, borderRadius: 5, width: '100%' },
});
