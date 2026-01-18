import React, { useState, useRef } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Image,
  Dimensions,
  LayoutAnimation,
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

if (Platform.OS === 'android' && UIManager.setLayoutAnimationEnabledExperimental) {
  UIManager.setLayoutAnimationEnabledExperimental(true);
}

const { width } = Dimensions.get('window');
const POST_ITEM_SIZE = (width - 4) / 3;
const BANNER_HEIGHT = 250;
const HEADER_FADE_START = BANNER_HEIGHT - 100;
const HEADER_FADE_END = BANNER_HEIGHT - 50;


const t = (key: string) => key.split('.').pop()?.replace(/_/g, ' ') ?? key;

// --- DUMMY DATA ---
const USER_ATTRIBUTES = [
    { field: 'gender_identity', label: t('profile.gender_identity'), icon: 'gender-male-female' },
    { field: 'sexual_orientation', label: t('profile.sexual_orientation'), icon: 'rainbow' },
    { field: 'relationship_status', label: t('profile.relationship_status'), icon: 'handshake-outline' },
    { field: 'height', label: t('profile.height'), icon: 'ruler' },
    { field: 'body_type', label: t('profile.body_type'), icon: 'arm-flex-outline' },
    { field: 'zodiac_sign', label: t('profile.zodiac_sign'), icon: 'zodiac-leo' },
    { field: 'smoking', label: t('profile.smoking'), icon: 'smoking' },
    { field: 'drinking', label: t('profile.drinking'), icon: 'glass-wine' },
    { field: 'education', label: t('profile.education_level'), icon: 'school-outline' },
    { field: 'personality', label: t('profile.personality'), icon: 'psychology-outline' },
];
const ABOUT_SECTIONS = [
    { title: 'Identity', icon: 'account-search-outline', attributes: ['gender_identity', 'sexual_orientation', 'relationship_status'] },
    { title: 'Appearance', icon: 'face-man-profile', attributes: ['height', 'body_type',] },
    { title: 'Lifestyle', icon: 'brain', attributes: ['zodiac_sign', 'smoking', 'drinking', 'education', 'personality'] },
];
const user = {
  gender_identity: { name: 'Male' },
  sexual_orientation: { name: 'Straight' },
  relationship_status: 'Single',
  height: { name: '180cm' },
  body_type: { name: 'Athletic' },
  zodiac_sign: { name: 'Leo' },
  smoking: { name: 'No' },
  drinking: { name: 'Socially' },
  education: { name: 'Bachelors' },
  personality: { name: 'ENTJ' },
  interests: [{id: '1', name: 'Photography', emoji: '📷'}, {id: '2', name: 'Gaming', emoji: '🎮'}, {id: '3', name: 'Traveling', emoji: '✈️'}],
  fantasies: [{id: '1', name: 'Being a pilot', emoji: '✈️'}, {id: '2', name: 'Writing a novel', emoji: '✍️'}],
};
const getAttributeValue = (item: any) => {
  const value = (user as any)[item.field];
  if (value) {
    if (typeof value === 'string') return value;
    if (value.name) return value.name;
  }
  return 'Not set';
};
const ATTRIBUTES_MAP = USER_ATTRIBUTES.reduce((acc, attr) => {
  acc[attr.field] = attr;
  return acc;
}, {} as Record<string, typeof USER_ATTRIBUTES[0]>);
const TABS = [
  { key: 'about', title: 'About', icon: 'account-details-outline' },
  { key: 'posts', title: 'Posts', icon: 'grid' },
  { key: 'media', title: 'Media', icon: 'image-multiple-outline' },
  { key: 'comments', title: 'Comments', icon: 'comment-outline' },
];

const AccordionSection = ({ title, icon, children, colors, dark }: any) => {
    const [isOpen, setIsOpen] = useState(false);
    const toggleOpen = () => {
      LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
      setIsOpen(!isOpen);
    };
    const borderColor = dark ? '#2F2F2F' : '#EBEBEB';
    const cardColor = dark ? '#1A1A1A' : '#F6F6F6';
  
    return (
      <View style={[styles.accordionContainer, { backgroundColor: cardColor, borderColor: borderColor }]}>
        <TouchableOpacity onPress={toggleOpen} style={styles.accordionHeader}>
          <View style={{ flexDirection: 'row', alignItems: 'center' }}>
            <MaterialCommunityIcons name={icon} size={20} color={colors.text} style={{ opacity: 0.8 }} />
            <ThemedText style={styles.accordionTitle}>{title}</ThemedText>
          </View>
          <MaterialCommunityIcons name={isOpen ? 'chevron-up' : 'chevron-down'} size={24} color={colors.text} style={{ opacity: 0.6 }} />
        </TouchableOpacity>
        {isOpen && <View style={styles.accordionContent}>{children}</View>}
      </View>
    );
};

const AttributeRow = ({ item, colors }: any) => {
    const displayValue = getAttributeValue(item);
    if (displayValue === 'Not set') return null;
    return (
      <View style={styles.attributeRow}>
        <View style={{ flexDirection: 'row', alignItems: 'center', flex: 1 }}>
          <MaterialCommunityIcons name={item.icon as any} size={20} color={colors.text} style={styles.attributeIcon} />
          <Text style={[styles.attributeLabel, { color: colors.text }]}>{item.label}</Text>
        </View>
        <Text style={[styles.attributeValue, { color: colors.text, opacity: 0.8 }]}>{displayValue}</Text>
      </View>
    );
};

const TagsSection = ({ title, icon, tags, renderTag, cardColor, borderColor, backgroundColor, textColor }: any) => {
    if (!tags || tags.length === 0) return null;
    return (
        <View style={[styles.accordionContainer, { backgroundColor: cardColor, borderColor: borderColor, marginTop: 10 }]}>
            <View style={styles.accordionHeader}>
                <MaterialCommunityIcons name={icon} size={20} color={textColor} style={{ opacity: 0.8 }} />
                <Text style={[styles.accordionTitle, { color: textColor, marginLeft: 12, fontSize: 16, fontWeight: '600' }]}>{title}</Text>
            </View>
            <View style={styles.tagContainer}>
                {tags.map((tag: any, index: number) => (
                    <View key={index} style={[styles.tag, { backgroundColor: backgroundColor }]}>
                        <Text style={[styles.tagText, { color: textColor }]}>{renderTag(tag)}</Text>
                    </View>
                ))}
            </View>
        </View>
    );
};


// --- MAIN SCREEN COMPONENT ---
export function ProfileScreen(): React.JSX.Element {
  const { colors, dark } = useTheme();
  const [activeTab, setActiveTab] = useState(TABS[0].key);
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
        return (
          <View style={styles.aboutContainer}>
            {ABOUT_SECTIONS.map(section => {
                const attributes = section.attributes.map(field => ATTRIBUTES_MAP[field]).filter(Boolean).filter(item => getAttributeValue(item) !== 'Not set');
                if (attributes.length === 0) return null;
                return ( <AccordionSection key={section.title} title={section.title} icon={section.icon as any} colors={colors} dark={dark}>{attributes.map(item => <AttributeRow key={item.field} item={item} colors={colors} />)}</AccordionSection> );
            })}
            <TagsSection title="Interests" icon="star-outline" tags={user.interests} renderTag={(tag: any) => `${tag.emoji} ${tag.name}`} cardColor={dark ? '#1A1A1A' : '#F6F6F6'} borderColor={borderColor} backgroundColor={backgroundColor} textColor={textColor} />
            <TagsSection title="Fantasies" icon="heart-flash-outline" tags={user.fantasies} renderTag={(tag: any) => `${tag.emoji} ${tag.name}`} cardColor={dark ? '#1A1A1A' : '#F6F6F6'} borderColor={borderColor} backgroundColor={backgroundColor} textColor={textColor} />
          </View>
        );
      case 'posts':
        return (
          <View style={styles.postsGrid}>
            {Array.from({ length: 21 }).map((_, index) => (
              <TouchableOpacity key={index} style={styles.postItem}>
                <Image source={{ uri: `https://picsum.photos/id/${index + 10}/300/300` }} style={styles.postImage} />
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
        <Animated.View style={[
          styles.stickyHeader,
          { backgroundColor: backgroundColor, height: insets.top + 50, paddingTop: insets.top, opacity: stickyHeaderOpacity }
        ]}>
          <Animated.View style={[styles.stickyHeaderContent, {transform: [{ translateY: stickyHeaderTranslateY }]}]}>
            <Image
              source={{ uri: 'https://pbs.twimg.com/profile_images/1960662542801625088/ntOOL4M-_400x400.jpg' }}
              style={styles.stickyAvatar}
            />
            <Text style={[styles.stickyHeaderText, { color: textColor }]}>Bifrost</Text>
          </Animated.View>
        </Animated.View>

        <Animated.ScrollView
            onScroll={Animated.event(
                [{ nativeEvent: { contentOffset: { y: scrollY } } }],
                { useNativeDriver: true }
            )}
            contentContainerStyle={{ paddingBottom: insets.bottom }}
            scrollEventThrottle={16}
            showsVerticalScrollIndicator={false}
            bounces={false}
        >
          <View style={styles.bannerContainer}>
              <Image source={{ uri: 'https://pbs.twimg.com/profile_banners/4614357675/1755441597/1500x500' }} style={styles.headerImage}/>
          </View>
          
          <View style={styles.contentContainer}>
              <View style={styles.headerSection}>
                  <View style={[styles.avatarContainer, {borderColor: backgroundColor}]}>
                      <Image 
                          source={{ uri: 'https://pbs.twimg.com/profile_images/1960662542801625088/ntOOL4M-_400x400.jpg' }}
                          style={styles.avatar}
                      />
                  </View>
                  <View style={styles.headerActions}>
                      <TouchableOpacity style={[styles.iconButton, {borderColor: borderColor}]}>
                          <MaterialCommunityIcons name="dots-horizontal" size={20} color={textColor} />
                      </TouchableOpacity>
                      <TouchableOpacity style={[styles.followButton, { backgroundColor: textColor }]}>
                          <Text style={[styles.followButtonText, { color: invertedTextColor }]}>Follow</Text>
                      </TouchableOpacity>
                  </View>
              </View>

              <View style={styles.userInfoSection}>
                  <ThemedText style={styles.name}>Bifrost</ThemedText>
                  <ThemedText style={styles.username}>@bifrost</ThemedText>
                  <ThemedText style={styles.bio}>The best app in the world. Building the future of social media, one line of code at a time.</ThemedText>
                  
                  <View style={styles.metadataSection}>
                      <MaterialCommunityIcons name="map-marker-outline" size={15} color={textColor} style={{opacity: 0.6}} />
                      <ThemedText style={styles.metadataText}>San Francisco, CA</ThemedText>
                      <MaterialCommunityIcons name="calendar-month-outline" size={15} color={textColor} style={{opacity: 0.6, marginLeft: 16}} />
                      <ThemedText style={styles.metadataText}>Joined January 2026</ThemedText>
                  </View>

                  <View style={styles.statsSection}>
                      <TouchableOpacity style={styles.statItem}><Text style={[styles.statNumber, { color: textColor }]}>1,234</Text><ThemedText style={styles.statLabel}>Following</ThemedText></TouchableOpacity>
                      <TouchableOpacity style={styles.statItem}><Text style={[styles.statNumber, { color: textColor }]}>5,678</Text><ThemedText style={styles.statLabel}>Followers</ThemedText></TouchableOpacity>
                  </View>
              </View>
          </View>
          <ProfileTabs />
          {renderContent()}
        </Animated.ScrollView>
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
  followButton: { paddingVertical: 8, paddingHorizontal: 20, borderRadius: 20 },
  followButtonText: { fontWeight: 'bold', fontSize: 14 },
  userInfoSection: { paddingHorizontal: 16, paddingTop: 4, paddingBottom: 16 },
  name: { fontSize: 24, fontWeight: 'bold' },
  username: { fontSize: 16, opacity: 0.6, marginTop: 1 },
  bio: { marginTop: 12, fontSize: 16, lineHeight: 22 },
  metadataSection: { flexDirection: 'row', alignItems: 'center', marginTop: 12 },
  metadataText: { marginLeft: 6, fontSize: 14, opacity: 0.6 },
  statsSection: { flexDirection: 'row', marginTop: 12 },
  statItem: { flexDirection: 'row', alignItems: 'center', marginRight: 16 },
  statNumber: { fontWeight: 'bold', fontSize: 15 },
  statLabel: { marginLeft: 5, fontSize: 15, opacity: 0.6 },
  tabsContainer: { flexDirection: 'row', borderBottomWidth: 1, justifyContent: 'space-around', },
  tab: { alignItems: 'center', paddingVertical: 12, flex: 1 },
  tabIndicator: { position: 'absolute', bottom: 0, height: 2, width: '60%', borderRadius: 2 },
  aboutContainer: { padding: 16 },
  accordionContainer: { borderRadius: 12, marginBottom: 10, borderWidth: 1, overflow: 'hidden' },
  accordionHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', padding: 16 },
  accordionTitle: { fontSize: 16, fontWeight: '600', marginLeft: 12 },
  accordionContent: { paddingBottom: 6 },
  attributeRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingVertical: 12, paddingHorizontal: 16 },
  attributeIcon: { opacity: 0.7, marginRight: 12, width: 24 },
  attributeLabel: { fontSize: 16, },
  attributeValue: { fontSize: 16, fontWeight: '500' },
  tagContainer: { flexDirection: 'row', flexWrap: 'wrap', paddingHorizontal: 16, paddingBottom: 16, paddingTop: 4 },
  tag: { paddingHorizontal: 14, paddingVertical: 8, borderRadius: 18, margin: 4 },
  tagText: { fontSize: 14, fontWeight: '500' },
  postsGrid: { flexDirection: 'row', flexWrap: 'wrap', padding: 1 },
  postItem: { width: POST_ITEM_SIZE, height: POST_ITEM_SIZE, padding: 1 },
  postImage: { width: '100%', height: '100%' },
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