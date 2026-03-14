import React, { useState, useRef, useMemo } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Dimensions,
  Animated,
  RefreshControlProps,
  useWindowDimensions,
  ActivityIndicator,
} from 'react-native';
import { Image } from 'expo-image';
import { useTheme } from '@react-navigation/native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { MapPin, Calendar, MessageSquare, Plus, Edit2, Wallet } from 'lucide-react-native';
import MaterialCommunityIcons from '@expo/vector-icons/MaterialCommunityIcons';
import RenderHTML from 'react-native-render-html';
import { BottomSheetScrollView } from '@gorhom/bottom-sheet';
import { api } from '@/services/apiService';
import { useAppSelector } from '@/store/hooks';
import { USER_ATTRIBUTES } from '@/constants/profile-data';
import { parsePreferencesFlags, isBitSet } from '@/helpers/bitfield';

const { width } = Dimensions.get('window');
const POST_ITEM_SIZE = (width - 2) / 3;
const BANNER_HEIGHT = 200;

type FullProfileViewProps = {
    user: any;
    isMe?: boolean;
    showActions?: boolean;
    onMessage?: () => void;
    onFollow?: () => void;
    onBlock?: () => void;
    onEdit?: () => void;
    onWallet?: () => void;
    refreshControl?: React.ReactElement<RefreshControlProps>;
    useBottomSheetScroll?: boolean;
    hideHeader?: boolean;
    hideTabs?: boolean;
    defaultTab?: string;
    showCover?: boolean;
};

const TABS = [
  { key: 'about', title: 'About' },
  { key: 'posts', title: 'Posts' },
  { key: 'media', title: 'Media' },
  { key: 'likes', title: 'Likes' },
];

export default function FullProfileView({ user, isMe, showActions = true, onMessage, onFollow, onBlock, onEdit, onWallet, refreshControl, useBottomSheetScroll, hideHeader = false, hideTabs = false, defaultTab, showCover = true }: FullProfileViewProps) {
  const { dark } = useTheme();
  const systemData = useAppSelector(state => state.system.data);
  const language = useAppSelector(state => state.system.language) || 'en';
  const fontSize = useAppSelector(state => state.system.fontSize);
  const [activeTab, setActiveTab] = useState(defaultTab ?? TABS[0].key);
  const [blockLoading, setBlockLoading] = useState(false);
  const insets = useSafeAreaInsets();
  const scrollY = useRef(new Animated.Value(0)).current;
  const { width: windowWidth } = useWindowDimensions();

  // Monochrome colors
  const textColor = dark ? '#FFFFFF' : '#000000';
  const backgroundColor = dark ? '#000000' : '#FFFFFF';
  const secondaryText = dark ? '#888888' : '#666666';
  const borderColor = dark ? '#1A1A1A' : '#F0F0F0';
  const cardColor = dark ? '#0F0F0F' : '#F9F9F9';
  const dangerColor = '#EF4444';
  const flags = parsePreferencesFlags(user?.preferences_flags);
  const fontScale = fontSize === 'small' ? 0.9 : fontSize === 'large' ? 1.15 : 1;
  const baseSizes = {
    attrHint: 11,
    attrHintLine: 14,
    valueChip: 12,
    valuePill: 12,
    attrValue: 12,
    tagText: 13,
  };
  const locationText = typeof user?.location === 'string' ? user.location.trim() : '';
  const showLocation = !!locationText;
  const bioHtml = typeof user?.bioHtml === 'string' ? user.bioHtml : '';
  const bioHtmlText = bioHtml ? bioHtml.replace(/<[^>]*>/g, '').trim() : '';
  const showBioHtml = !!bioHtmlText;

  const getJoinedDate = () => {
    if (!user.created_at) return 'Recently';
    try {
      const date = new Date(user.created_at);
      return `Joined ${date.toLocaleString('en-US', { month: 'short', year: 'numeric' })}`;
    } catch {
      return 'Recently';
    }
  };

  const getLocalizedText = (value: any, fallback = '') => {
    if (!value) return fallback;
    if (typeof value === 'string') return value;
    if (typeof value === 'number') return String(value);
    if (typeof value === 'object') {
      return (value as any)[language] || (value as any).en || Object.values(value as any)[0] || fallback;
    }
    return fallback;
  };

  const getNameFromEntity = (entity: any) => {
    if (!entity) return '';
    if (typeof entity === 'string' || typeof entity === 'number') return String(entity);
    if (entity.name) return getLocalizedText(entity.name);
    if (entity.title) return getLocalizedText(entity.title);
    return '';
  };

  const renderAboutTab = () => {
    const styles = aboutStyles;
    const fieldOptions: Record<string, { id: string; name: string; bit_index?: number }[]> = {};
    const fieldAllowMultiple: Record<string, boolean> = {};
    const fieldLabels: Record<string, string> = {};
    const fieldDescriptions: Record<string, string> = {};

    const preferencesRoot = (systemData as any)?.data?.preferences || (systemData as any)?.preferences;
    const legacyRoot = (systemData as any)?.data || systemData;
    const preferencesAttributes = preferencesRoot?.attributes;
    if (Array.isArray(preferencesAttributes)) {
      preferencesAttributes.forEach((attr: any) => {
        const tag = attr.tag || attr.slug;
        const allowMultiple = attr.allow_multiple || false;
        fieldAllowMultiple[tag] = allowMultiple;
        fieldLabels[tag] = getLocalizedText(attr.title, tag);
        fieldDescriptions[tag] = getLocalizedText(attr.description, '');

        if (Array.isArray(attr.items)) {
          const sortedItems = [...attr.items].sort((a: any, b: any) => (a.display_order || 0) - (b.display_order || 0));
          fieldOptions[tag] = sortedItems.map((item: any) => ({
            id: item.id,
            name: getLocalizedText(item.title) || item.slug || '',
            bit_index: item.bit_index,
          }));
        }
      });
    } else {
      const legacy = legacyRoot as any;
      if (Array.isArray(legacy?.attributes)) {
        legacy.attributes.forEach((group: any) => {
          const sortedAttributes = [...(group.attributes || [])].sort((a: any, b: any) => (a.display_order || 0) - (b.display_order || 0));
          fieldOptions[group.category] = sortedAttributes.map((attr: any) => ({
            id: attr.id,
            name: getLocalizedText(attr.name),
          }));
        });
      }

      if (Array.isArray(legacy?.gender_identities)) {
        const sortedGenderIdentities = [...legacy.gender_identities].sort((a: any, b: any) => (a.display_order || 0) - (b.display_order || 0));
        fieldOptions['gender_identity'] = sortedGenderIdentities.map((item: any) => ({
          id: item.id,
          name: getLocalizedText(item.name),
        }));
      }

      if (Array.isArray(legacy?.sexual_orientations)) {
        const sortedSexualOrientations = [...legacy.sexual_orientations].sort((a: any, b: any) => (a.display_order || 0) - (b.display_order || 0));
        fieldOptions['sexual_orientation'] = sortedSexualOrientations.map((item: any) => ({
          id: item.id,
          name: getLocalizedText(item.name),
        }));
      }

      if (Array.isArray(legacy?.sexual_roles)) {
        const sortedSexualRoles = [...legacy.sexual_roles].sort((a: any, b: any) => (a.display_order || 0) - (b.display_order || 0));
        fieldOptions['sex_role'] = sortedSexualRoles.map((item: any) => ({
          id: item.id,
          name: getLocalizedText(item.name),
        }));
      }
    }

    const getAttributeValue = (item: any) => {
      const options = fieldOptions[item.field] || [];
      const allowMultiple = fieldAllowMultiple[item.field] || false;
      const usePreferencesFlags = options.some(opt => opt.bit_index !== undefined);

      if (usePreferencesFlags) {
        const selectedOptions = options.filter(opt => opt.bit_index !== undefined && isBitSet(flags, opt.bit_index));
        if (selectedOptions.length > 0) {
          const selectedNames = selectedOptions.map(opt => opt.name).filter(Boolean);
          return {
            value: allowMultiple ? selectedNames.join(', ') : selectedOptions[0].name,
            selectedOptions: selectedNames,
            allowMultiple,
            hasValue: true,
          };
        }
        return { value: null, selectedOptions: [], allowMultiple, hasValue: false };
      }

      if (item.field === 'gender_identity') {
        const genderIdentities = (user as any)?.gender_identities || (user as any)?.sexual_identities?.gender_identities;
        const identityList = Array.isArray(genderIdentities) ? genderIdentities : (genderIdentities ? [genderIdentities] : []);
        const names = identityList.map(getNameFromEntity).filter(Boolean);
        if (names.length > 0) {
          return {
            value: allowMultiple ? names.join(', ') : names[0],
            selectedOptions: allowMultiple ? names : [names[0]],
            allowMultiple,
            hasValue: true,
          };
        }

        const genderIdentity = (user as any)?.gender_identity;
        const name = getNameFromEntity(genderIdentity);
        if (name) return { value: name, selectedOptions: [name], allowMultiple, hasValue: true };
      }

      if (item.field === 'sexual_orientation') {
        const sexualOrientations = (user as any)?.sexual_orientations || (user as any)?.sexual_identities?.sexual_orientations;
        const orientationList = Array.isArray(sexualOrientations) ? sexualOrientations : (sexualOrientations ? [sexualOrientations] : []);
        const names = orientationList.map(getNameFromEntity).filter(Boolean);
        if (names.length > 0) {
          return {
            value: allowMultiple ? names.join(', ') : names[0],
            selectedOptions: allowMultiple ? names : [names[0]],
            allowMultiple,
            hasValue: true,
          };
        }

        const sexualOrientation = (user as any)?.sexual_orientation;
        const name = getNameFromEntity(sexualOrientation);
        if (name) return { value: name, selectedOptions: [name], allowMultiple, hasValue: true };
      }

      if (item.field === 'sex_role') {
        const sexRole = (user as any)?.sexual_role || (user as any)?.sex_role || (user as any)?.sexual_identities?.sex_role;
        const name = getNameFromEntity(sexRole);
        if (name) return { value: name, selectedOptions: [name], allowMultiple, hasValue: true };
      }

      const topLevelValue = (user as any)?.[item.field];
      if (topLevelValue) {
        const name = getNameFromEntity(topLevelValue);
        if (name) return { value: name, selectedOptions: [name], allowMultiple, hasValue: true };
      }

      if (Array.isArray((user as any)?.user_attributes)) {
        const attr = (user as any).user_attributes.find((ua: any) => ua.category_type === item.field);
        if (attr?.attribute?.name) {
          const name = getLocalizedText(attr.attribute.name);
          if (name) return { value: name, selectedOptions: [name], allowMultiple, hasValue: true };
        }
      }

      if (item.field === 'relationship_status' && (user as any)?.relationship_status) {
        return { value: String((user as any).relationship_status), selectedOptions: [String((user as any).relationship_status)], allowMultiple, hasValue: true };
      }

      return { value: null, selectedOptions: [], allowMultiple, hasValue: false };
    };

    const getInterestsByCategory = (): Record<string, { title: string; items: Array<{ name: string; emoji?: string }> }> => {
      const categorized: Record<string, { title: string; items: Array<{ name: string; emoji?: string }> }> = {};
      const preferencesInterests = preferencesRoot?.interests;

      if (Array.isArray(preferencesInterests)) {
        preferencesInterests.forEach((cat: any) => {
          const catTitle = getLocalizedText(cat.title, cat.id);
          const items: Array<{ name: string; emoji?: string }> = [];
          if (Array.isArray(cat.items)) {
            cat.items.forEach((item: any) => {
              if (item.bit_index !== undefined && isBitSet(flags, item.bit_index)) {
                items.push({
                  name: getLocalizedText(item.title, item.slug),
                  emoji: item.icon || '✨',
                });
              }
            });
          }
          if (items.length > 0) {
            categorized[cat.id] = { title: catTitle, items };
          }
        });
      }

      if (Object.keys(categorized).length > 0) return categorized;

      const interestsSource = (user as any)?.interests;
      if (Array.isArray(interestsSource)) {
        interestsSource.forEach((userInterest: any) => {
          if (typeof userInterest === 'object' && userInterest !== null && userInterest.interest_item) {
            const interestItem = userInterest.interest_item;
            const categoryId = interestItem.interest_id || interestItem.interest?.id || 'other';
            const categoryName = getLocalizedText(interestItem.interest?.name, 'Other');
            if (!categorized[categoryId]) {
              categorized[categoryId] = { title: categoryName, items: [] };
            }
            categorized[categoryId].items.push({
              name: getLocalizedText(interestItem.title || interestItem.name, interestItem.slug),
              emoji: interestItem.icon || '✨',
            });
          } else if (typeof userInterest === 'string') {
            if (!categorized.other) categorized.other = { title: 'Other', items: [] };
            categorized.other.items.push({ name: userInterest });
          }
        });
      }

      return categorized;
    };

    const getFantasiesByCategory = (): Record<string, { title: string; items: Array<{ name: string }> }> => {
      const categorized: Record<string, { title: string; items: Array<{ name: string }> }> = {};
      const preferencesFantasies = preferencesRoot?.fantasies;

      if (Array.isArray(preferencesFantasies)) {
        preferencesFantasies.forEach((cat: any) => {
          const catTitle = getLocalizedText(cat.title, cat.id);
          const items: Array<{ name: string }> = [];
          if (Array.isArray(cat.items)) {
            cat.items.forEach((item: any) => {
              if (item.bit_index !== undefined && isBitSet(flags, item.bit_index)) {
                items.push({
                  name: getLocalizedText(item.title, item.slug),
                });
              }
            });
          }
          if (items.length > 0) {
            categorized[cat.id] = { title: catTitle, items };
          }
        });
      }

      if (Object.keys(categorized).length > 0) return categorized;

      const fantasiesSource = (user as any)?.fantasies;
      const legacyFantasies = (legacyRoot as any)?.fantasies;
      if (Array.isArray(fantasiesSource)) {
        fantasiesSource.forEach((userFantasy: any) => {
          if (typeof userFantasy === 'string') {
            if (!categorized.other) categorized.other = { title: 'Other', items: [] };
            categorized.other.items.push({ name: userFantasy });
            return;
          }

          if (typeof userFantasy === 'object' && userFantasy !== null) {
            const fantasy = userFantasy.fantasy || userFantasy.fantasy_item || userFantasy.fantasyItem;
            if (fantasy) {
              const categoryId = fantasy.category_id || fantasy.category?.id || fantasy.category || 'other';
              const categoryName = getLocalizedText(fantasy.category?.title || fantasy.category?.name || fantasy.category, categoryId);
              if (!categorized[categoryId]) {
                categorized[categoryId] = { title: categoryName, items: [] };
              }
              categorized[categoryId].items.push({
                name: getLocalizedText(fantasy.label || fantasy.title, String(fantasy.id || userFantasy.fantasy_id || '')),
              });
              return;
            }

            const fantasyId = userFantasy.fantasy_id || userFantasy.id;
            if (fantasyId && Array.isArray(legacyFantasies)) {
              const fallbackFantasy = legacyFantasies.find((f: any) => f.id === fantasyId);
              if (fallbackFantasy) {
                const categoryId = fallbackFantasy.slug || 'other';
                const categoryName = getLocalizedText(fallbackFantasy.category, categoryId);
                if (!categorized[categoryId]) {
                  categorized[categoryId] = { title: categoryName, items: [] };
                }
                categorized[categoryId].items.push({
                  name: getLocalizedText(fallbackFantasy.label, String(fantasyId)),
                });
              }
            }
          }
        });
      }

      return categorized;
    };

    const attributesData = USER_ATTRIBUTES.map((attr: any) => {
      const resolved = getAttributeValue(attr);
      return {
        ...attr,
        label: fieldLabels[attr.field] || attr.label,
        description: fieldDescriptions[attr.field] || '',
        value: resolved.value,
        hasValue: resolved.hasValue,
        selectedOptions: resolved.selectedOptions,
        allowMultiple: resolved.allowMultiple,
      };
    });

    const filledCount = attributesData.filter((a: any) => a.hasValue).length;
    const totalCount = USER_ATTRIBUTES.length;

    const categorizedInterests = getInterestsByCategory();
    const categorizedFantasies = getFantasiesByCategory();

    return (
      <View style={styles.container}>
        <View style={styles.section}>
          <View style={styles.sectionHeader}>
            <Text style={[styles.sectionTitle, { color: textColor }]}>Attributes</Text>
            <Text style={[styles.sectionCount, { color: secondaryText }]}>{filledCount} / {totalCount}</Text>
          </View>
          <View style={[styles.card, { borderColor, backgroundColor: dark ? 'rgba(255,255,255,0.03)' : 'rgba(0,0,0,0.02)' }]}>
            {attributesData.map((item: any, index: number) => {
              const isLast = index === attributesData.length - 1;
              const isMulti = item.allowMultiple && Array.isArray(item.selectedOptions) && item.selectedOptions.length > 1;
              return (
                <View
                  key={item.field}
                  style={[
                    styles.attrRow,
                    !isLast && { borderBottomWidth: 1, borderBottomColor: borderColor },
                  ]}
                >
                  <View style={styles.attrHeader}>
                    <View style={[styles.iconContainer, { backgroundColor: dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.04)' }]}>
                      <MaterialCommunityIcons name={item.icon as any} size={22} color={textColor} />
                    </View>
                    <View style={styles.attrLabelStack}>
                      <Text style={[styles.attrLabel, { color: textColor }]} numberOfLines={2}>{item.label}</Text>
                      {!!item.description && (
                        <Text style={[styles.attrHint, { color: secondaryText, fontSize: baseSizes.attrHint * fontScale, lineHeight: baseSizes.attrHintLine * fontScale }]} numberOfLines={3}>{item.description}</Text>
                      )}
                    </View>
                  </View>
                  <View style={styles.attrValueBlock}>
                    {isMulti ? (
                      <View style={styles.attrValueWrap}>
                        {item.selectedOptions.map((opt: string, optIndex: number) => (
                          <View key={`${item.field}-opt-${optIndex}`} style={[styles.valueChip, { backgroundColor: dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.04)', borderColor }]}>
                            <Text style={[styles.valueChipText, { color: secondaryText, fontSize: baseSizes.valueChip * fontScale }]} numberOfLines={2}>{opt}</Text>
                          </View>
                        ))}
                      </View>
                    ) : (
                      <View style={styles.attrValueSingle}>
                        {!item.value && <View style={styles.dot} />}
                        {item.value ? (
                          <View style={[styles.valuePill, { backgroundColor: dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.04)', borderColor }]}>
                            <Text style={[styles.valuePillText, { color: secondaryText, fontSize: baseSizes.valuePill * fontScale }]} numberOfLines={2}>
                              {item.value}
                            </Text>
                          </View>
                        ) : (
                          <Text style={[styles.attrValue, { color: secondaryText, fontSize: baseSizes.attrValue * fontScale }]} numberOfLines={2}>
                            -
                          </Text>
                        )}
                      </View>
                    )}
                  </View>
                </View>
              );
            })}
          </View>
        </View>

        <View style={styles.section}>
          <View style={styles.sectionHeader}>
            <Text style={[styles.sectionTitle, { color: textColor }]}>Fantasies</Text>
            <Text style={[styles.sectionCount, { color: secondaryText }]}>
              {Object.values(categorizedFantasies).reduce((acc, cat) => acc + cat.items.length, 0)}
            </Text>
          </View>
          {Object.keys(categorizedFantasies).length > 0 ? (
            Object.entries(categorizedFantasies).map(([slug, cat]) => (
              <View key={slug} style={[styles.categoryCard, { borderColor, backgroundColor: dark ? 'rgba(255,255,255,0.03)' : 'rgba(0,0,0,0.02)' }]}>
                <View style={[styles.categoryHeader, { borderBottomColor: borderColor }]}>
                  <Text style={[styles.categoryTitle, { color: secondaryText }]}>{cat.title.toUpperCase()}</Text>
                </View>
                <View style={styles.tagGrid}>
                  {cat.items.map((item, idx) => (
                    <View key={idx} style={[styles.tag, { backgroundColor: dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.04)', borderColor }]}>
                      <Text style={[styles.tagText, { color: textColor, fontSize: baseSizes.tagText * fontScale }]}>{item.name}</Text>
                    </View>
                  ))}
                </View>
              </View>
            ))
          ) : (
            <View style={[styles.emptySection, { borderColor, backgroundColor: dark ? 'rgba(255,255,255,0.03)' : 'rgba(0,0,0,0.02)' }]}>
              <View style={[styles.emptyIconWrap, { backgroundColor: dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.04)' }]}>
                <MaterialCommunityIcons name="star-four-points-outline" size={22} color={secondaryText} />
              </View>
              <Text style={[styles.emptySectionText, { color: secondaryText }]}>No fantasies added yet.</Text>
            </View>
          )}
        </View>

        <View style={styles.section}>
          <View style={styles.sectionHeader}>
            <Text style={[styles.sectionTitle, { color: textColor }]}>Interests</Text>
            <Text style={[styles.sectionCount, { color: secondaryText }]}>
              {Object.values(categorizedInterests).reduce((acc, cat) => acc + cat.items.length, 0)}
            </Text>
          </View>
          {Object.keys(categorizedInterests).length > 0 ? (
            Object.entries(categorizedInterests).map(([id, cat]) => (
              <View key={id} style={[styles.categoryCard, { borderColor, backgroundColor: dark ? 'rgba(255,255,255,0.03)' : 'rgba(0,0,0,0.02)' }]}>
                <View style={[styles.categoryHeader, { borderBottomColor: borderColor }]}>
                  <Text style={[styles.categoryTitle, { color: secondaryText }]}>{cat.title.toUpperCase()}</Text>
                </View>
                <View style={styles.tagGrid}>
                  {cat.items.map((item, idx) => (
                    <View key={idx} style={[styles.tag, { backgroundColor: dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.04)', borderColor }]}>
                      <Text style={[styles.tagText, { color: textColor }]}>
                        {item.emoji && <Text style={{ fontSize: 16 }}>{item.emoji}</Text>} {item.name}
                      </Text>
                    </View>
                  ))}
                </View>
              </View>
            ))
          ) : (
            <View style={[styles.emptySection, { borderColor, backgroundColor: dark ? 'rgba(255,255,255,0.03)' : 'rgba(0,0,0,0.02)' }]}>
              <View style={[styles.emptyIconWrap, { backgroundColor: dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.04)' }]}>
                <MaterialCommunityIcons name="heart-outline" size={22} color={secondaryText} />
              </View>
              <Text style={[styles.emptySectionText, { color: secondaryText }]}>No interests added yet.</Text>
            </View>
          )}
        </View>
      </View>
    );
  };

  const handleBlockPress = async () => {
    if (blockLoading) return;
    const targetId = user?.id || user?.public_id;
    if (!targetId && !onBlock) return;
    setBlockLoading(true);
    try {
      if (onBlock) {
        await onBlock();
      } else if (targetId) {
        await api.toggleBlockUser(String(targetId));
      }
    } catch (error) {
      console.warn('Block user failed', error);
    } finally {
      setBlockLoading(false);
    }
  };

  const renderTabContent = () => {
    switch (activeTab) {
      case 'about':
        return renderAboutTab();
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
        {showCover && (
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
        </>
        )}

        {!hideHeader && (
        <>
        {/* Profile Info Header */}
        <View style={styles.headerInfo}>
          <View style={styles.avatarRow}>
            <View style={[styles.avatarContainer, { borderColor: backgroundColor, backgroundColor }]}>
              <Image source={{ uri: user.avatar_url }} style={styles.avatar} contentFit="cover" />
            </View>
          </View>
          
          {showActions && (
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
                  <TouchableOpacity
                    onPress={onMessage}
                    disabled={!onMessage}
                    style={[styles.circleBtn, { borderColor, backgroundColor: cardColor, opacity: onMessage ? 1 : 0.5 }]}
                  >
                    <MessageSquare size={18} color={textColor} />
                  </TouchableOpacity>
                  <TouchableOpacity
                    onPress={onFollow}
                    disabled={!onFollow}
                    style={[styles.actionBtn, styles.followBtn, { backgroundColor: textColor, borderColor: textColor, opacity: onFollow ? 1 : 0.6 }]}
                  >
                    <Plus size={16} color={backgroundColor} />
                    <Text style={[styles.btnText, { color: backgroundColor }]}>Follow</Text>
                  </TouchableOpacity>
                  <TouchableOpacity
                    onPress={handleBlockPress}
                    disabled={blockLoading}
                    style={[
                      styles.actionBtn,
                      styles.blockBtn,
                      { borderColor: `${dangerColor}55`, backgroundColor: dark ? 'rgba(239,68,68,0.12)' : 'rgba(239,68,68,0.08)' },
                    ]}
                  >
                    {blockLoading ? (
                      <ActivityIndicator size="small" color={dangerColor} />
                    ) : (
                      <>
                        <MaterialCommunityIcons name="block-helper" size={16} color={dangerColor} />
                        <Text style={[styles.btnText, styles.blockText, { color: dangerColor }]}>Block</Text>
                      </>
                    )}
                  </TouchableOpacity>
                </View>
              )}
            </View>
          )}

          <View style={styles.userInfo}>
            <View style={styles.nameRow}>
                <Text style={[styles.displayName, { color: textColor }]}>{user.displayname}</Text>
                {user.is_verified && (
                    <MaterialCommunityIcons name="check-decagram" size={20} color="#00BAFF" style={{ marginLeft: 8, marginTop: 4 }} />
                )}
            </View>
            <Text style={[styles.username, { color: secondaryText }]}>@{user.username || user.displayname?.toLowerCase().replace(/\s+/g, '')}</Text>
            
            {showBioHtml ? (
              <RenderHTML
                contentWidth={Math.max(0, windowWidth - 32)}
                source={{ html: bioHtml }}
                baseStyle={[styles.bio, { color: textColor }]}
                defaultTextProps={{ selectable: false }}
              />
            ) : user.bio ? (
              <Text style={[styles.bio, { color: textColor }]}>{user.bio}</Text>
            ) : null}

            <View style={styles.metaRow}>
              {showLocation && (
                <View style={styles.metaItem}>
                  <MapPin size={14} color={secondaryText} />
                  <Text style={[styles.metaText, { color: secondaryText }]}>{locationText}</Text>
                </View>
              )}
              <View style={[styles.metaItem, showLocation && { marginLeft: 16 }]}>
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
        </>
        )}

        {!hideTabs && (
        <>
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
        </>
        )}

        {/* Tab Content */}
        <View style={styles.contentArea}>
          {renderTabContent()}
        </View>
    </>
  );

  const stickyHeaderIndices = useMemo(() => {
    if (hideTabs) return undefined;
    let index = 0;
    if (showCover) index += 1;
    if (!hideHeader) index += 1;
    return [index];
  }, [hideTabs, showCover, hideHeader]);

  return (
    <View style={[styles.container, { backgroundColor }]}>
      {useBottomSheetScroll ? (
        <BottomSheetScrollView
          showsVerticalScrollIndicator={false}
          stickyHeaderIndices={stickyHeaderIndices}
          contentContainerStyle={{ paddingBottom: insets.bottom + 100 }}
          scrollEventThrottle={16}
          refreshControl={refreshControl}
        >
          {content}
        </BottomSheetScrollView>
      ) : (
        <Animated.ScrollView
          showsVerticalScrollIndicator={false}
          stickyHeaderIndices={stickyHeaderIndices} // Sticky Tabs
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
  avatarRow: { alignItems: 'center', justifyContent: 'center', marginBottom: 10 },
  avatarContainer: {
    width: 110,
    height: 110,
    borderRadius: 55,
    borderWidth: 4,
    overflow: 'hidden',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.16,
    shadowRadius: 12,
    elevation: 6,
  },
  avatar: { width: '100%', height: '100%' },
  actionButtons: { paddingBottom: 8, marginTop: 12, alignItems: 'center', width: '100%' },
  btnRow: { flexDirection: 'row', alignItems: 'center', gap: 10, flexWrap: 'wrap', rowGap: 10, justifyContent: 'center' },
  circleBtn: {
    width: 42,
    height: 42,
    borderRadius: 14,
    borderWidth: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  actionBtn: {
    height: 42,
    paddingHorizontal: 14,
    borderRadius: 14,
    borderWidth: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  followBtn: {
    minWidth: 104,
    justifyContent: 'center',
    shadowColor: '#000',
    shadowOpacity: 0.18,
    shadowRadius: 10,
    shadowOffset: { width: 0, height: 6 },
    elevation: 4,
  },
  blockBtn: {
    minWidth: 90,
    justifyContent: 'center',
  },
  btnText: { fontFamily: 'Inter-SemiBold', fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4 },
  blockText: { letterSpacing: 0.2 },
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

const aboutStyles = StyleSheet.create({
  container: { padding: 16 },
  section: { marginBottom: 32 },
  sectionHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 },
  sectionTitle: { fontSize: 22, fontFamily: 'Outfit-Bold', letterSpacing: -0.5 },
  sectionCount: { fontSize: 13, fontFamily: 'Inter-SemiBold' },
  card: { borderRadius: 18, borderWidth: 1, overflow: 'hidden' },
  attrRow: { paddingHorizontal: 16, paddingVertical: 14, rowGap: 10 },
  attrHeader: { flexDirection: 'row', alignItems: 'flex-start' },
  iconContainer: { width: 32, height: 32, borderRadius: 10, alignItems: 'center', justifyContent: 'center', marginRight: 12 },
  attrLabelStack: { flex: 1, minWidth: 0 },
  attrLabel: { fontSize: 15, fontFamily: 'Inter-Medium', flexShrink: 1 },
  attrHint: { fontSize: 11, fontFamily: 'Inter-Regular', marginTop: 4, lineHeight: 14 },
  attrValueBlock: { marginLeft: 44 },
  attrValueSingle: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  attrValue: { fontSize: 12, fontFamily: 'Inter-Medium' },
  attrValueWrap: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  valueChip: { paddingHorizontal: 10, paddingVertical: 6, borderRadius: 14, borderWidth: 1 },
  valueChipText: { fontSize: 12, fontFamily: 'Inter-Medium' },
  valuePill: { paddingHorizontal: 10, paddingVertical: 6, borderRadius: 14, borderWidth: 1, alignSelf: 'flex-start' },
  valuePillText: { fontSize: 12, fontFamily: 'Inter-SemiBold' },
  dot: { width: 6, height: 6, borderRadius: 3, backgroundColor: '#FFD700' },
  categoryCard: { borderRadius: 18, borderWidth: 1, overflow: 'hidden', marginBottom: 12 },
  categoryHeader: { paddingHorizontal: 16, paddingVertical: 10, borderBottomWidth: 1 },
  categoryTitle: { fontSize: 11, fontFamily: 'Inter-Bold', letterSpacing: 0.8 },
  tagGrid: { flexDirection: 'row', flexWrap: 'wrap', padding: 12, gap: 8 },
  tag: { paddingHorizontal: 12, paddingVertical: 8, borderRadius: 16, borderWidth: 1 },
  tagText: { fontSize: 13, fontFamily: 'Inter-Medium' },
  emptySection: { borderRadius: 18, borderWidth: 1, paddingVertical: 28, alignItems: 'center', gap: 8 },
  emptyIconWrap: { width: 40, height: 40, borderRadius: 20, alignItems: 'center', justifyContent: 'center' },
  emptySectionText: { fontSize: 14, fontFamily: 'Inter-Medium' },
});
