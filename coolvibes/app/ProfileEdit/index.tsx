import React, { useEffect, useMemo, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TextInput,
  TouchableOpacity,
  ActivityIndicator,
  Alert,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import { useTheme } from '@react-navigation/native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Image } from 'expo-image';
import * as ImagePicker from 'expo-image-picker';
import MaterialCommunityIcons from '@expo/vector-icons/MaterialCommunityIcons';
import { useRouter } from 'expo-router';

import { useAppDispatch, useAppSelector } from '@/store/hooks';
import { api } from '@/services/apiService';
import { getAuthUserThunk } from '@/store/slice/auth';
import { getSafeImageURL, getSafeImageURLEx } from '@/helpers/safeUrl';
import {
  parsePreferencesFlags,
  serializePreferencesFlags,
  isBitSet,
  setBit,
  unsetBit,
  toggleBit,
} from '@/helpers/bitfield';
import { USER_ATTRIBUTES } from '@/constants/profile-data';

type EditTabKey = 'profile' | 'attributes' | 'interests' | 'fantasies';

type OptionItem = {
  id: string;
  name: string;
  bit_index?: number;
  display_order?: number;
  emoji?: string;
};

type CategoryItem = {
  id: string;
  name: string;
  allow_multiple?: boolean;
};

enum PrivacyLevel {
  Public = 'public',
  FriendsOnly = 'friends_only',
  FollowersOnly = 'followers_only',
  MutualsOnly = 'mutuals_only',
  Private = 'private',
}

export default function ProfileEditScreen() {
  const { dark, colors } = useTheme();
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const dispatch = useAppDispatch();

  const authUser = useAppSelector(state => state.auth.user);
  const systemData = useAppSelector(state => state.system.data);
  const language = useAppSelector(state => state.system.language) || 'en';

  const [localUser, setLocalUser] = useState<any>(authUser);
  const [editTab, setEditTab] = useState<EditTabKey>('profile');
  const [saving, setSaving] = useState(false);
  const [uploadingAvatar, setUploadingAvatar] = useState(false);
  const [uploadingCover, setUploadingCover] = useState(false);
  const [expandedField, setExpandedField] = useState<string | null>(null);
  const [expandedInterestCategory, setExpandedInterestCategory] = useState<string | null>(null);
  const [expandedFantasyCategory, setExpandedFantasyCategory] = useState<string | null>(null);

  const [preferencesFlags, setPreferencesFlags] = useState<bigint>(parsePreferencesFlags(authUser?.preferences_flags));

  const [profileImagePreview, setProfileImagePreview] = useState<string | null>(null);
  const [coverImagePreview, setCoverImagePreview] = useState<string | null>(null);

  const [editForm, setEditForm] = useState({
    username: '',
    displayname: '',
    email: '',
    bio: '',
    location: '',
    date_of_birth: '',
    website: '',
    privacy_level: PrivacyLevel.Public as PrivacyLevel,
  });

  useEffect(() => {
    if (!authUser) return;

    const getLocalizedText = (value: any, fallback = '') => {
      if (!value) return fallback;
      if (typeof value === 'string') return value;
      if (typeof value === 'number') return String(value);
      if (typeof value === 'object') {
        return value[language] || value.en || Object.values(value)[0] || fallback;
      }
      return fallback;
    };

    const stripHtml = (value: string) => value.replace(/<[^>]*>/g, '').replace(/&nbsp;/g, ' ').trim();

    const rawBio = authUser.bio || authUser.status_message;
    const bioText = typeof rawBio === 'string'
      ? stripHtml(rawBio)
      : getLocalizedText(rawBio);

    setLocalUser(authUser);
    setPreferencesFlags(parsePreferencesFlags(authUser?.preferences_flags));
    setEditForm({
      username: authUser.username || '',
      displayname: authUser.displayname || '',
      email: authUser.email || '',
      bio: bioText || '',
      location: authUser.location?.display || authUser.location?.city || '',
      date_of_birth: authUser.date_of_birth ? authUser.date_of_birth.slice(0, 10) : '',
      website: authUser.website || '',
      privacy_level: (authUser.privacy_level as PrivacyLevel) || PrivacyLevel.Public,
    });
  }, [authUser, language]);

  const textColor = dark ? '#FFFFFF' : '#000000';
  const secondaryText = dark ? '#888888' : '#666666';
  const borderColor = dark ? '#1A1A1A' : '#F0F0F0';
  const surfaceColor = dark ? '#0F0F0F' : '#F9F9F9';

  const privacyLevels = useMemo(() => ([
    PrivacyLevel.Public,
    PrivacyLevel.FriendsOnly,
    PrivacyLevel.FollowersOnly,
    PrivacyLevel.MutualsOnly,
    PrivacyLevel.Private,
  ]), []);

  const privacyLabels: Record<PrivacyLevel, string> = {
    [PrivacyLevel.Public]: 'Public',
    [PrivacyLevel.FriendsOnly]: 'Friends Only',
    [PrivacyLevel.FollowersOnly]: 'Followers Only',
    [PrivacyLevel.MutualsOnly]: 'Mutuals Only',
    [PrivacyLevel.Private]: 'Private',
  };

  const preferencesRoot = (systemData as any)?.data?.preferences || (systemData as any)?.preferences;
  const legacyRoot = (systemData as any)?.data || systemData;

  const fieldOptions: Record<string, OptionItem[]> = useMemo(() => {
    const options: Record<string, OptionItem[]> = {};
    const preferencesAttributes = preferencesRoot?.attributes;
    if (Array.isArray(preferencesAttributes)) {
      preferencesAttributes.forEach((attr: any) => {
        const tag = attr.tag || attr.slug;
        if (Array.isArray(attr.items)) {
          const sortedItems = [...attr.items].sort((a: any, b: any) => (a.display_order || 0) - (b.display_order || 0));
          options[tag] = sortedItems.map((item: any) => ({
            id: item.id,
            name: item.title?.[language] || item.title?.en || (item.title ? Object.values(item.title)[0] : '') || item.slug || '',
            bit_index: item.bit_index,
            display_order: item.display_order,
          }));
        }
      });
    } else if ((legacyRoot as any)?.attributes) {
      const legacy = legacyRoot as any;
      legacy.attributes.forEach((group: any) => {
        const sorted = [...(group.attributes || [])].sort((a: any, b: any) => (a.display_order || 0) - (b.display_order || 0));
        options[group.category] = sorted.map((attr: any) => ({
          id: attr.id,
          name: attr.name?.[language] || attr.name?.en || Object.values(attr.name || {})[0] || '',
          display_order: attr.display_order,
        }));
      });

      if (Array.isArray(legacy?.gender_identities)) {
        options['gender_identity'] = legacy.gender_identities.map((item: any) => ({
          id: item.id,
          name: item.name?.[language] || item.name?.en || Object.values(item.name || {})[0] || '',
          display_order: item.display_order,
        }));
      }

      if (Array.isArray(legacy?.sexual_orientations)) {
        options['sexual_orientation'] = legacy.sexual_orientations.map((item: any) => ({
          id: item.id,
          name: item.name?.[language] || item.name?.en || Object.values(item.name || {})[0] || '',
          display_order: item.display_order,
        }));
      }

      if (Array.isArray(legacy?.sexual_roles)) {
        options['sex_role'] = legacy.sexual_roles.map((item: any) => ({
          id: item.id,
          name: item.name?.[language] || item.name?.en || Object.values(item.name || {})[0] || '',
          display_order: item.display_order,
        }));
      }
    }

    return options;
  }, [systemData, language]);

  const fieldLabels: Record<string, string> = useMemo(() => {
    const labels: Record<string, string> = {};
    const preferencesAttributes = preferencesRoot?.attributes;
    if (Array.isArray(preferencesAttributes)) {
      preferencesAttributes.forEach((attr: any) => {
        const tag = attr.tag || attr.slug;
        const title = attr.title?.[language] || attr.title?.en || (attr.title ? Object.values(attr.title)[0] : '') || tag;
        labels[tag] = title;
      });
    }
    return labels;
  }, [preferencesRoot, language]);

  const fieldDescriptions: Record<string, string> = useMemo(() => {
    const descriptions: Record<string, string> = {};
    const preferencesAttributes = preferencesRoot?.attributes;
    if (Array.isArray(preferencesAttributes)) {
      preferencesAttributes.forEach((attr: any) => {
        const tag = attr.tag || attr.slug;
        const desc = attr.description?.[language] || attr.description?.en || (attr.description ? Object.values(attr.description)[0] : '') || '';
        descriptions[tag] = desc;
      });
    }
    return descriptions;
  }, [preferencesRoot, language]);

  const fieldAllowMultiple: Record<string, boolean> = useMemo(() => {
    const allowMap: Record<string, boolean> = {};
    const preferencesAttributes = preferencesRoot?.attributes;
    if (Array.isArray(preferencesAttributes)) {
      preferencesAttributes.forEach((attr: any) => {
        const tag = attr.tag || attr.slug;
        allowMap[tag] = attr.allow_multiple || false;
      });
    }
    return allowMap;
  }, [systemData]);

  const interestOptions: Record<string, OptionItem[]> = useMemo(() => {
    const options: Record<string, OptionItem[]> = {};
    const preferencesInterests = preferencesRoot?.interests;
    if (Array.isArray(preferencesInterests)) {
      preferencesInterests.forEach((interest: any) => {
        if (Array.isArray(interest.items)) {
          options[interest.id] = interest.items.map((item: any) => ({
            id: item.id,
            name: item.title?.[language] || item.title?.en || (item.title ? Object.values(item.title)[0] : '') || '',
            emoji: item.icon,
            bit_index: item.bit_index,
          }));
        }
      });
    } else if ((legacyRoot as any)?.interests) {
      const legacy = legacyRoot as any;
      legacy.interests.forEach((interest: any) => {
        options[interest.id] = (interest.items || []).map((item: any) => ({
          id: item.id,
          name: item.name?.[language] || item.name?.en || Object.values(item.name || {})[0] || '',
          emoji: item.emoji,
        }));
      });
    }
    return options;
  }, [systemData, language]);

  const interestCategories: CategoryItem[] = useMemo(() => {
    const categories: CategoryItem[] = [];
    const preferencesInterests = preferencesRoot?.interests;
    if (Array.isArray(preferencesInterests)) {
      preferencesInterests.forEach((interest: any) => {
        categories.push({
          id: interest.id,
          name: interest.title?.[language] || interest.title?.en || (interest.title ? Object.values(interest.title)[0] : '') || '',
          allow_multiple: interest.allow_multiple || false,
        });
      });
    } else if ((legacyRoot as any)?.interests) {
      const legacy = legacyRoot as any;
      legacy.interests.forEach((interest: any) => {
        categories.push({
          id: interest.id,
          name: interest.name?.[language] || interest.name?.en || Object.values(interest.name || {})[0] || '',
        });
      });
    }
    return categories;
  }, [systemData, language]);

  const fantasyOptions: Record<string, OptionItem[]> = useMemo(() => {
    const options: Record<string, OptionItem[]> = {};
    const preferencesFantasies = preferencesRoot?.fantasies;
    if (Array.isArray(preferencesFantasies)) {
      preferencesFantasies.forEach((fantasy: any) => {
        if (Array.isArray(fantasy.items)) {
          options[fantasy.slug] = fantasy.items.map((item: any) => ({
            id: item.id,
            name: item.title?.[language] || item.title?.en || (item.title ? Object.values(item.title)[0] : '') || '',
            bit_index: item.bit_index,
          }));
        }
      });
    } else if ((legacyRoot as any)?.fantasies) {
      const legacy = legacyRoot as any;
      legacy.fantasies.forEach((fantasy: any) => {
        const categorySlug = fantasy.slug;
        if (!options[categorySlug]) options[categorySlug] = [];
        options[categorySlug].push({
          id: fantasy.id,
          name: fantasy.label?.[language] || fantasy.label?.en || Object.values(fantasy.label || {})[0] || '',
        });
      });
    }
    return options;
  }, [systemData, language]);

  const fantasyCategories: CategoryItem[] = useMemo(() => {
    const categories: CategoryItem[] = [];
    const preferencesFantasies = preferencesRoot?.fantasies;
    if (Array.isArray(preferencesFantasies)) {
      preferencesFantasies.forEach((fantasy: any) => {
        categories.push({
          id: fantasy.slug,
          name: fantasy.title?.[language] || fantasy.title?.en || (fantasy.title ? Object.values(fantasy.title)[0] : '') || fantasy.slug,
          allow_multiple: fantasy.allow_multiple || false,
        });
      });
    } else if ((legacyRoot as any)?.fantasies) {
      const legacy = legacyRoot as any;
      const grouped: Record<string, string> = {};
      legacy.fantasies.forEach((fantasy: any) => {
        const categorySlug = fantasy.slug;
        const categoryName = fantasy.category?.[language] || fantasy.category?.en || Object.values(fantasy.category || {})[0] || categorySlug;
        grouped[categorySlug] = categoryName;
      });
      Object.keys(grouped).forEach((slug) => {
        categories.push({ id: slug, name: grouped[slug] });
      });
    }
    return categories;
  }, [systemData, language]);

  const userSelectedInterestIds = useMemo(() => {
    const selected: string[] = [];
    Object.keys(interestOptions).forEach((categoryId) => {
      const items = interestOptions[categoryId] || [];
      items.forEach((item) => {
        if (item.bit_index !== undefined && isBitSet(preferencesFlags, item.bit_index)) {
          selected.push(item.id);
        }
      });
    });

    if (selected.length === 0 && Array.isArray(localUser?.interests)) {
      return localUser.interests.map((interest: any) => {
        if (typeof interest === 'object' && interest !== null) {
          return String(interest.interest_item_id || interest.interest_item?.id || interest.id);
        }
        return String(interest);
      });
    }

    return selected;
  }, [interestOptions, preferencesFlags, localUser?.interests]);

  const userSelectedInterestByCategory = useMemo(() => {
    const grouped: Record<string, OptionItem[]> = {};
    Object.keys(interestOptions).forEach((categoryId) => {
      const items = interestOptions[categoryId] || [];
      items.forEach((item) => {
        if (item.bit_index !== undefined && isBitSet(preferencesFlags, item.bit_index)) {
          if (!grouped[categoryId]) grouped[categoryId] = [];
          grouped[categoryId].push(item);
        }
      });
    });

    if (Object.keys(grouped).length === 0 && Array.isArray(localUser?.interests)) {
      localUser.interests.forEach((userInterest: any) => {
        if (typeof userInterest === 'object' && userInterest !== null && userInterest.interest_item) {
          const interestItem = userInterest.interest_item;
          const categoryId = interestItem.interest_id || interestItem.interest?.id || 'other';
          if (!grouped[categoryId]) grouped[categoryId] = [];
          grouped[categoryId].push({
            id: interestItem.id,
            name: interestItem.name?.[language] || interestItem.name?.en || Object.values(interestItem.name || {})[0] || '',
            emoji: interestItem.emoji,
          });
        }
      });
    }

    return grouped;
  }, [interestOptions, preferencesFlags, localUser?.interests, language]);

  const userSelectedFantasyIds = useMemo(() => {
    const selected: string[] = [];
    Object.keys(fantasyOptions).forEach((categoryId) => {
      const items = fantasyOptions[categoryId] || [];
      items.forEach((item) => {
        if (item.bit_index !== undefined && isBitSet(preferencesFlags, item.bit_index)) {
          selected.push(item.id);
        }
      });
    });

    if (selected.length === 0 && Array.isArray(localUser?.fantasies)) {
      return localUser.fantasies.map((fantasy: any) => fantasy.fantasy_id || fantasy.id);
    }

    return selected;
  }, [fantasyOptions, preferencesFlags, localUser?.fantasies]);

  const userSelectedFantasyByCategory = useMemo(() => {
    const grouped: Record<string, OptionItem[]> = {};
    Object.keys(fantasyOptions).forEach((categoryId) => {
      const items = fantasyOptions[categoryId] || [];
      items.forEach((item) => {
        if (item.bit_index !== undefined && isBitSet(preferencesFlags, item.bit_index)) {
          if (!grouped[categoryId]) grouped[categoryId] = [];
          grouped[categoryId].push(item);
        }
      });
    });

    if (Object.keys(grouped).length === 0 && Array.isArray(localUser?.fantasies) && Array.isArray((legacyRoot as any)?.fantasies)) {
      const legacyFantasies = (legacyRoot as any).fantasies;
      localUser.fantasies.forEach((userFantasy: any) => {
        const fantasyId = userFantasy.fantasy_id || userFantasy.id;
        const fallbackFantasy = legacyFantasies.find((f: any) => f.id === fantasyId);
        if (fallbackFantasy) {
          const categoryId = fallbackFantasy.slug || 'other';
          if (!grouped[categoryId]) grouped[categoryId] = [];
          grouped[categoryId].push({
            id: fallbackFantasy.id,
            name: fallbackFantasy.label?.[language] || fallbackFantasy.label?.en || Object.values(fallbackFantasy.label || {})[0] || '',
          });
        }
      });
    }

    return grouped;
  }, [fantasyOptions, preferencesFlags, localUser?.fantasies, legacyRoot, language]);

  const coverImageUrl = coverImagePreview
    || getSafeImageURL(localUser?.banner, 'large')
    || getSafeImageURL(localUser?.cover, 'large')
    || (localUser?.id ? `https://picsum.photos/seed/${localUser.id}banner/1500/500` : null);

  const avatarImageUrl = profileImagePreview
    || getSafeImageURLEx(localUser?.id || localUser?.public_id, localUser?.avatar, 'large')
    || getSafeImageURLEx(localUser?.id || localUser?.public_id, localUser?.avatar_url || localUser?.avatarUrl, 'large');

  const handlePickImage = async (type: 'avatar' | 'cover') => {
    const permissionResult = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!permissionResult.granted) {
      Alert.alert('Permission needed', 'Please allow photo library access.');
      return;
    }

    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      allowsEditing: true,
      quality: 0.9,
    });

    if (result.canceled || !result.assets?.[0]) return;

    const asset = result.assets[0];
    const file = {
      uri: asset.uri,
      name: `${type}-${Date.now()}.jpg`,
      type: asset.mimeType || 'image/jpeg',
    };

    if (type === 'avatar') {
      setUploadingAvatar(true);
      setProfileImagePreview(asset.uri);
      try {
        const response = await api.uploadAvatar({ avatar: file });
        if (response?.user) {
          setLocalUser(response.user);
        }
        dispatch(getAuthUserThunk());
      } catch (err) {
        Alert.alert('Upload failed', 'Could not update profile image.');
      } finally {
        setUploadingAvatar(false);
      }
    } else {
      setUploadingCover(true);
      setCoverImagePreview(asset.uri);
      try {
        const response = await api.uploadCover({ cover: file });
        if (response?.user) {
          setLocalUser(response.user);
        }
        dispatch(getAuthUserThunk());
      } catch (err) {
        Alert.alert('Upload failed', 'Could not update cover image.');
      } finally {
        setUploadingCover(false);
      }
    }
  };

  const applyPreferencesFlags = (nextFlags: bigint) => {
    setPreferencesFlags(nextFlags);
    setLocalUser((prev: any) => ({
      ...prev,
      preferences_flags: serializePreferencesFlags(nextFlags),
    }));
  };

  const handleSaveProfile = async () => {
    if (!localUser) return;
    setSaving(true);
    try {
      const payload: Record<string, any> = {
        username: editForm.username || undefined,
        displayname: editForm.displayname || undefined,
        email: editForm.email || undefined,
        bio: editForm.bio || undefined,
        location: editForm.location || undefined,
        date_of_birth: editForm.date_of_birth || undefined,
        website: editForm.website || undefined,
        privacy_level: editForm.privacy_level || undefined,
      };

      const response = await api.updateProfile(payload);
      if (response?.user) {
        setLocalUser(response.user);
      }
      dispatch(getAuthUserThunk());
      Alert.alert('Saved', 'Your profile has been updated.');
    } catch (err) {
      Alert.alert('Update failed', 'Could not update your profile.');
    } finally {
      setSaving(false);
    }
  };

  const handleAttributeSelect = async (field: string, option: OptionItem) => {
    const options = fieldOptions[field] || [];
    const allowMultiple = fieldAllowMultiple[field] || false;
    const usePreferencesFlags = options.some(opt => opt.bit_index !== undefined);

    if (usePreferencesFlags && option.bit_index !== undefined) {
      let nextFlags = preferencesFlags;
      if (allowMultiple) {
        nextFlags = toggleBit(nextFlags, option.bit_index);
      } else {
        options.forEach((opt) => {
          if (opt.bit_index !== undefined) {
            nextFlags = unsetBit(nextFlags, opt.bit_index);
          }
        });
        nextFlags = setBit(nextFlags, option.bit_index);
      }
      applyPreferencesFlags(nextFlags);

      try {
        const enabled = allowMultiple ? isBitSet(nextFlags, option.bit_index) : true;
        await api.updatePreferences(option.id, option.bit_index, enabled);
        dispatch(getAuthUserThunk());
      } catch (err) {
        Alert.alert('Update failed', 'Could not update attribute.');
      }
      return;
    }

    try {
      const isSexualIdentityField = ['gender_identity', 'sexual_orientation', 'sex_role'].includes(field);
      if (isSexualIdentityField) {
        const bodyKey = field === 'gender_identity'
          ? 'gender_identity_id'
          : field === 'sexual_orientation'
            ? 'sexual_orientation_id'
            : 'sexual_role_id';
        await api.updateIdentify({ [bodyKey]: option.id });
      } else {
        await api.updateAttribute({ attribute_id: option.id });
      }

      setLocalUser((prev: any) => {
        const next = { ...prev };
        if (field === 'gender_identity') {
          next.gender_identities = [{ id: option.id, name: { [language]: option.name }, display_order: option.display_order || 0 }];
        } else if (field === 'sexual_orientation') {
          next.sexual_orientations = [{ id: option.id, name: { [language]: option.name }, display_order: option.display_order || 0 }];
        } else if (field === 'sex_role') {
          next.sexual_role = { id: option.id, name: { [language]: option.name }, display_order: option.display_order || 0 };
        } else if (field === 'relationship_status') {
          next.relationship_status = option.name;
        } else {
          const attrs = Array.isArray(prev?.user_attributes) ? [...prev.user_attributes] : [];
          const idx = attrs.findIndex((attr: any) => attr.category_type === field);
          const entry = {
            category_type: field,
            attribute_id: option.id,
            attribute: { id: option.id, name: { [language]: option.name } },
          } as any;
          if (idx >= 0) attrs[idx] = entry;
          else attrs.push(entry);
          next.user_attributes = attrs;
        }
        return next;
      });

      dispatch(getAuthUserThunk());
    } catch (err) {
      Alert.alert('Update failed', 'Could not update attribute.');
    }
  };

  const handleInterestToggle = async (item: OptionItem, categoryId: string, allowMultiple: boolean) => {
    const usePreferencesFlags = item.bit_index !== undefined;

    if (usePreferencesFlags && item.bit_index !== undefined) {
      let nextFlags = preferencesFlags;
      if (allowMultiple) {
        nextFlags = toggleBit(nextFlags, item.bit_index);
      } else {
        (interestOptions[categoryId] || []).forEach((opt) => {
          if (opt.bit_index !== undefined) {
            nextFlags = unsetBit(nextFlags, opt.bit_index);
          }
        });
        nextFlags = setBit(nextFlags, item.bit_index);
      }
      applyPreferencesFlags(nextFlags);
      try {
        const enabled = allowMultiple ? isBitSet(nextFlags, item.bit_index) : true;
        await api.updatePreferences(item.id, item.bit_index, enabled);
        dispatch(getAuthUserThunk());
      } catch (err) {
        Alert.alert('Update failed', 'Could not update interests.');
      }
      return;
    }

    try {
      await api.updateInterest({ interest_id: item.id });
      setLocalUser((prev: any) => {
        const current = Array.isArray(prev?.interests) ? [...prev.interests] : [];
        const alreadySelected = current.some((interest: any) => String(interest.interest_item_id || interest.interest_item?.id || interest.id) === item.id);
        if (alreadySelected) {
          return { ...prev, interests: current.filter((interest: any) => String(interest.interest_item_id || interest.interest_item?.id || interest.id) !== item.id) };
        }
        const category = interestCategories.find(cat => cat.id === categoryId);
        const entry = {
          id: item.id,
          interest_item_id: item.id,
          interest_item: {
            id: item.id,
            interest_id: categoryId,
            name: { [language]: item.name },
            emoji: item.emoji,
            interest: {
              id: categoryId,
              name: { [language]: category?.name || categoryId },
            },
          },
        } as any;
        return { ...prev, interests: [...current, entry] };
      });
      dispatch(getAuthUserThunk());
    } catch (err) {
      Alert.alert('Update failed', 'Could not update interests.');
    }
  };

  const handleFantasyToggle = async (item: OptionItem, categoryId: string, allowMultiple: boolean) => {
    const usePreferencesFlags = item.bit_index !== undefined;

    if (usePreferencesFlags && item.bit_index !== undefined) {
      let nextFlags = preferencesFlags;
      if (allowMultiple) {
        nextFlags = toggleBit(nextFlags, item.bit_index);
      } else {
        (fantasyOptions[categoryId] || []).forEach((opt) => {
          if (opt.bit_index !== undefined) {
            nextFlags = unsetBit(nextFlags, opt.bit_index);
          }
        });
        nextFlags = setBit(nextFlags, item.bit_index);
      }
      applyPreferencesFlags(nextFlags);
      try {
        const enabled = allowMultiple ? isBitSet(nextFlags, item.bit_index) : true;
        await api.updatePreferences(item.id, item.bit_index, enabled);
        dispatch(getAuthUserThunk());
      } catch (err) {
        Alert.alert('Update failed', 'Could not update fantasies.');
      }
      return;
    }

    try {
      await api.updateFantasy({ fantasy_id: item.id });
      setLocalUser((prev: any) => {
        const current = Array.isArray(prev?.fantasies) ? [...prev.fantasies] : [];
        const alreadySelected = current.some((fantasy: any) => String(fantasy.fantasy_id || fantasy.id) === item.id);
        if (alreadySelected) {
          return { ...prev, fantasies: current.filter((fantasy: any) => String(fantasy.fantasy_id || fantasy.id) !== item.id) };
        }
        const entry = { id: item.id, fantasy_id: item.id } as any;
        return { ...prev, fantasies: [...current, entry] };
      });
      dispatch(getAuthUserThunk());
    } catch (err) {
      Alert.alert('Update failed', 'Could not update fantasies.');
    }
  };

  if (!localUser) {
    return (
      <View style={[styles.loader, { backgroundColor: colors.background }]}> 
        <ActivityIndicator color={textColor} />
      </View>
    );
  }

  const renderProfileTab = () => (
    <View style={styles.section}>
      <Text style={[styles.sectionTitle, { color: textColor }]}>Profile Info</Text>

      <View style={styles.inputGroup}>
        <Text style={[styles.inputLabel, { color: secondaryText }]}>Username</Text>
        <TextInput
          style={[styles.input, { color: textColor, borderColor, backgroundColor: surfaceColor }]}
          value={editForm.username}
          onChangeText={(value) => setEditForm(prev => ({ ...prev, username: value }))}
          autoCapitalize="none"
        />
      </View>

      <View style={styles.inputGroup}>
        <Text style={[styles.inputLabel, { color: secondaryText }]}>Display Name</Text>
        <TextInput
          style={[styles.input, { color: textColor, borderColor, backgroundColor: surfaceColor }]}
          value={editForm.displayname}
          onChangeText={(value) => setEditForm(prev => ({ ...prev, displayname: value }))}
        />
      </View>

      <View style={styles.inputGroup}>
        <Text style={[styles.inputLabel, { color: secondaryText }]}>Email</Text>
        <TextInput
          style={[styles.input, { color: textColor, borderColor, backgroundColor: surfaceColor }]}
          value={editForm.email}
          onChangeText={(value) => setEditForm(prev => ({ ...prev, email: value }))}
          keyboardType="email-address"
          autoCapitalize="none"
        />
      </View>

      <View style={styles.inputGroup}>
        <Text style={[styles.inputLabel, { color: secondaryText }]}>Bio</Text>
        <TextInput
          style={[styles.input, styles.textarea, { color: textColor, borderColor, backgroundColor: surfaceColor }]}
          value={editForm.bio}
          onChangeText={(value) => setEditForm(prev => ({ ...prev, bio: value }))}
          multiline
          textAlignVertical="top"
        />
      </View>

      <View style={styles.inputGroup}>
        <Text style={[styles.inputLabel, { color: secondaryText }]}>Location</Text>
        <TextInput
          style={[styles.input, { color: textColor, borderColor, backgroundColor: surfaceColor }]}
          value={editForm.location}
          onChangeText={(value) => setEditForm(prev => ({ ...prev, location: value }))}
          placeholder="City"
          placeholderTextColor={dark ? '#555' : '#AAA'}
        />
      </View>

      <View style={styles.inputGroup}>
        <Text style={[styles.inputLabel, { color: secondaryText }]}>Date of Birth</Text>
        <TextInput
          style={[styles.input, { color: textColor, borderColor, backgroundColor: surfaceColor }]}
          value={editForm.date_of_birth}
          onChangeText={(value) => setEditForm(prev => ({ ...prev, date_of_birth: value }))}
          placeholder="YYYY-MM-DD"
          placeholderTextColor={dark ? '#555' : '#AAA'}
        />
      </View>

      <View style={styles.inputGroup}>
        <Text style={[styles.inputLabel, { color: secondaryText }]}>Website</Text>
        <TextInput
          style={[styles.input, { color: textColor, borderColor, backgroundColor: surfaceColor }]}
          value={editForm.website}
          onChangeText={(value) => setEditForm(prev => ({ ...prev, website: value }))}
          placeholder="https://example.com"
          placeholderTextColor={dark ? '#555' : '#AAA'}
          autoCapitalize="none"
        />
      </View>

      <View style={styles.inputGroup}>
        <Text style={[styles.inputLabel, { color: secondaryText }]}>Privacy Level</Text>
        <View style={styles.chipRow}>
          {privacyLevels.map((level) => {
            const isActive = editForm.privacy_level === level;
            return (
              <TouchableOpacity
                key={level}
                style={[styles.chip, {
                  backgroundColor: isActive ? textColor : surfaceColor,
                  borderColor: isActive ? textColor : borderColor,
                }]}
                onPress={() => setEditForm(prev => ({ ...prev, privacy_level: level }))}
              >
                <Text style={[styles.chipText, { color: isActive ? colors.background : secondaryText }]}>
                  {privacyLabels[level]}
                </Text>
              </TouchableOpacity>
            );
          })}
        </View>
      </View>

      <TouchableOpacity
        style={[styles.saveButton, { backgroundColor: textColor }]}
        onPress={handleSaveProfile}
        disabled={saving}
      >
        {saving ? (
          <ActivityIndicator color={colors.background} />
        ) : (
          <Text style={[styles.saveButtonText, { color: colors.background }]}>Save Changes</Text>
        )}
      </TouchableOpacity>
    </View>
  );

  const renderAttributesTab = () => (
    <View style={styles.section}>
      <Text style={[styles.sectionTitle, { color: textColor }]}>Attributes</Text>
      {USER_ATTRIBUTES.map((attr) => {
        const options = fieldOptions[attr.field] || [];
        const allowMultiple = fieldAllowMultiple[attr.field] || false;
        const usePreferencesFlags = options.some(opt => opt.bit_index !== undefined);

        let displayValue = 'Select option';
        let selectedIds: string[] = [];

        if (usePreferencesFlags) {
          selectedIds = options.filter(opt => opt.bit_index !== undefined && isBitSet(preferencesFlags, opt.bit_index)).map(opt => opt.id);
          if (selectedIds.length > 0) {
            displayValue = options.filter(opt => selectedIds.includes(opt.id)).map(opt => opt.name).join(', ');
          }
        } else {
          if (attr.field === 'gender_identity') {
            const genderIdentities = localUser?.gender_identities || localUser?.sexual_identities?.gender_identities;
            const genderIdentity = Array.isArray(genderIdentities) ? genderIdentities[0] : genderIdentities;
            if (genderIdentity?.id) selectedIds = [genderIdentity.id];
            displayValue = genderIdentity?.name?.[language] || genderIdentity?.name?.en || displayValue;
          } else if (attr.field === 'sexual_orientation') {
            const sexualOrientations = localUser?.sexual_orientations || localUser?.sexual_identities?.sexual_orientations;
            const sexualOrientation = Array.isArray(sexualOrientations) ? sexualOrientations[0] : sexualOrientations;
            if (sexualOrientation?.id) selectedIds = [sexualOrientation.id];
            displayValue = sexualOrientation?.name?.[language] || sexualOrientation?.name?.en || displayValue;
          } else if (attr.field === 'sex_role') {
            const sexRole = localUser?.sexual_role || localUser?.sex_role || localUser?.sexual_identities?.sex_role;
            if (sexRole?.id) selectedIds = [sexRole.id];
            displayValue = sexRole?.name?.[language] || sexRole?.name?.en || displayValue;
          } else if (attr.field === 'relationship_status' && localUser?.relationship_status) {
            displayValue = String(localUser.relationship_status);
          } else if (Array.isArray(localUser?.user_attributes)) {
            const ua = localUser.user_attributes.find((u: any) => u.category_type === attr.field);
            if (ua?.attribute?.id) selectedIds = [ua.attribute.id];
            if (ua?.attribute?.name) {
              displayValue = ua.attribute.name?.[language] || ua.attribute.name?.en || displayValue;
            }
          }
        }

        const isExpanded = expandedField === attr.field;

        const displayLabel = fieldLabels[attr.field] || attr.label;
        const displayHint = fieldDescriptions[attr.field] || '';
        return (
          <View key={attr.field} style={[styles.card, { borderColor, backgroundColor: surfaceColor }]}>  
            <TouchableOpacity
              style={styles.cardHeader}
              onPress={() => setExpandedField(isExpanded ? null : attr.field)}
            >
              <View style={styles.cardHeaderLeft}>
                <MaterialCommunityIcons name={attr.icon as any} size={20} color={textColor} />
                <View style={styles.cardHeaderText}>
                  <Text style={[styles.cardHeaderTitle, { color: textColor }]}>{displayLabel}</Text>
                  {!!displayHint && (
                    <Text style={[styles.cardHeaderHint, { color: secondaryText }]} numberOfLines={2}>{displayHint}</Text>
                  )}
                </View>
              </View>
              <View style={styles.cardHeaderRight}>
                <Text style={[styles.cardHeaderValue, { color: secondaryText }]} numberOfLines={1}>{displayValue}</Text>
                <MaterialCommunityIcons name={isExpanded ? 'chevron-up' : 'chevron-down'} size={18} color={secondaryText} />
              </View>
            </TouchableOpacity>

            {isExpanded && (
              <View style={styles.cardContent}>
                {options.length === 0 ? (
                  <Text style={[styles.emptyText, { color: secondaryText }]}>No options available.</Text>
                ) : (
                  options.map((option) => {
                    const isSelected = selectedIds.includes(option.id);
                    return (
                      <TouchableOpacity
                        key={option.id}
                        style={[styles.optionRow, { borderColor }, isSelected && { backgroundColor: dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.04)' }]}
                        onPress={() => handleAttributeSelect(attr.field, option)}
                      >
                        <Text style={[styles.optionText, { color: textColor }]}>{option.name}</Text>
                        {isSelected && (
                          <MaterialCommunityIcons name={allowMultiple ? 'check-circle-outline' : 'check'} size={18} color={textColor} />
                        )}
                      </TouchableOpacity>
                    );
                  })
                )}
              </View>
            )}
          </View>
        );
      })}
    </View>
  );

  const renderInterestsTab = () => (
    <View style={styles.section}>
      <Text style={[styles.sectionTitle, { color: textColor }]}>Interests</Text>
      {interestCategories.length === 0 ? (
        <Text style={[styles.emptyText, { color: secondaryText }]}>No interest categories available.</Text>
      ) : (
        interestCategories.map((category) => {
          const items = interestOptions[category.id] || [];
          const selectedItems = userSelectedInterestByCategory[category.id] || [];
          const isExpanded = expandedInterestCategory === category.id;
          const allowMultiple = category.allow_multiple ?? true;
          return (
            <View key={category.id} style={[styles.card, { borderColor, backgroundColor: surfaceColor }]}>  
              <TouchableOpacity
                style={styles.cardHeader}
                onPress={() => setExpandedInterestCategory(isExpanded ? null : category.id)}
              >
                <View style={styles.cardHeaderLeft}>
                  <Text style={[styles.cardHeaderTitle, { color: textColor }]}>{category.name}</Text>
                </View>
                <View style={styles.cardHeaderRight}>
                  <Text style={[styles.cardHeaderValue, { color: secondaryText }]}>{selectedItems.length} selected</Text>
                  <MaterialCommunityIcons name={isExpanded ? 'chevron-up' : 'chevron-down'} size={18} color={secondaryText} />
                </View>
              </TouchableOpacity>
              {isExpanded && (
                <View style={styles.cardContent}>
                  {items.length === 0 ? (
                    <Text style={[styles.emptyText, { color: secondaryText }]}>No options available.</Text>
                  ) : (
                    items.map((item) => {
                      const isSelected = userSelectedInterestIds.includes(item.id);
                      return (
                        <TouchableOpacity
                          key={item.id}
                          style={[styles.optionRow, { borderColor }, isSelected && { backgroundColor: dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.04)' }]}
                          onPress={() => handleInterestToggle(item, category.id, allowMultiple)}
                        >
                          <Text style={[styles.optionText, { color: textColor }]}>  
                            {item.emoji ? `${item.emoji} ` : ''}{item.name}
                          </Text>
                          {isSelected && (
                            <MaterialCommunityIcons name={allowMultiple ? 'check-circle-outline' : 'check'} size={18} color={textColor} />
                          )}
                        </TouchableOpacity>
                      );
                    })
                  )}
                </View>
              )}
            </View>
          );
        })
      )}
    </View>
  );

  const renderFantasiesTab = () => (
    <View style={styles.section}>
      <Text style={[styles.sectionTitle, { color: textColor }]}>Fantasies</Text>
      {fantasyCategories.length === 0 ? (
        <Text style={[styles.emptyText, { color: secondaryText }]}>No fantasy categories available.</Text>
      ) : (
        fantasyCategories.map((category) => {
          const items = fantasyOptions[category.id] || [];
          const selectedItems = userSelectedFantasyByCategory[category.id] || [];
          const isExpanded = expandedFantasyCategory === category.id;
          const allowMultiple = category.allow_multiple ?? true;
          return (
            <View key={category.id} style={[styles.card, { borderColor, backgroundColor: surfaceColor }]}>  
              <TouchableOpacity
                style={styles.cardHeader}
                onPress={() => setExpandedFantasyCategory(isExpanded ? null : category.id)}
              >
                <View style={styles.cardHeaderLeft}>
                  <Text style={[styles.cardHeaderTitle, { color: textColor }]}>{category.name}</Text>
                </View>
                <View style={styles.cardHeaderRight}>
                  <Text style={[styles.cardHeaderValue, { color: secondaryText }]}>{selectedItems.length} selected</Text>
                  <MaterialCommunityIcons name={isExpanded ? 'chevron-up' : 'chevron-down'} size={18} color={secondaryText} />
                </View>
              </TouchableOpacity>
              {isExpanded && (
                <View style={styles.cardContent}>
                  {items.length === 0 ? (
                    <Text style={[styles.emptyText, { color: secondaryText }]}>No options available.</Text>
                  ) : (
                    items.map((item) => {
                      const isSelected = userSelectedFantasyIds.includes(item.id);
                      return (
                        <TouchableOpacity
                          key={item.id}
                          style={[styles.optionRow, { borderColor }, isSelected && { backgroundColor: dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.04)' }]}
                          onPress={() => handleFantasyToggle(item, category.id, allowMultiple)}
                        >
                          <Text style={[styles.optionText, { color: textColor }]}>{item.name}</Text>
                          {isSelected && (
                            <MaterialCommunityIcons name={allowMultiple ? 'check-circle-outline' : 'check'} size={18} color={textColor} />
                          )}
                        </TouchableOpacity>
                      );
                    })
                  )}
                </View>
              )}
            </View>
          );
        })
      )}
    </View>
  );

  return (
    <KeyboardAvoidingView style={[styles.container, { backgroundColor: colors.background }]} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <ScrollView
        contentContainerStyle={{ paddingBottom: insets.bottom + 40 }}
        showsVerticalScrollIndicator={false}
      >
        <View style={{ paddingTop: insets.top + 60 }}>
          <View style={styles.headerRow}>
            <TouchableOpacity onPress={() => router.back()} style={styles.backButton}>
              <MaterialCommunityIcons name="chevron-left" size={26} color={textColor} />
            </TouchableOpacity>
            <Text style={[styles.headerTitle, { color: textColor }]}>Edit Profile</Text>
            <View style={styles.backButton} />
          </View>

          <View style={styles.coverContainer}>
            {coverImageUrl ? (
              <Image source={{ uri: coverImageUrl }} style={styles.coverImage} contentFit="cover" />
            ) : (
              <View style={[styles.coverPlaceholder, { backgroundColor: surfaceColor }]} />
            )}
            <TouchableOpacity
              style={[styles.coverAction, { backgroundColor: dark ? 'rgba(0,0,0,0.6)' : 'rgba(255,255,255,0.8)' }]}
              onPress={() => handlePickImage('cover')}
              disabled={uploadingCover}
            >
              {uploadingCover ? (
                <ActivityIndicator color={textColor} />
              ) : (
                <MaterialCommunityIcons name="camera-outline" size={18} color={textColor} />
              )}
            </TouchableOpacity>
          </View>

          <View style={styles.avatarRow}>
            <View style={[styles.avatarWrapper, { borderColor: colors.background }]}>  
              {avatarImageUrl ? (
                <Image source={{ uri: avatarImageUrl }} style={styles.avatarImage} contentFit="cover" />
              ) : (
                <View style={[styles.avatarPlaceholder, { backgroundColor: surfaceColor }]} />
              )}
            </View>
            <TouchableOpacity
              style={[styles.avatarAction, { backgroundColor: dark ? '#111' : '#FFF', borderColor }]}
              onPress={() => handlePickImage('avatar')}
              disabled={uploadingAvatar}
            >
              {uploadingAvatar ? (
                <ActivityIndicator color={textColor} />
              ) : (
                <MaterialCommunityIcons name="camera-outline" size={16} color={textColor} />
              )}
            </TouchableOpacity>
          </View>

          <View style={[styles.tabRow, { borderBottomColor: borderColor }]}>  
            {[
              { key: 'profile', label: 'Profile Info' },
              { key: 'attributes', label: 'Attributes' },
              { key: 'interests', label: 'Interests' },
              { key: 'fantasies', label: 'Fantasies' },
            ].map((tab) => {
              const isActive = editTab === tab.key;
              return (
                <TouchableOpacity
                  key={tab.key}
                  style={styles.tabButton}
                  onPress={() => setEditTab(tab.key as EditTabKey)}
                >
                  <Text style={[styles.tabLabel, { color: isActive ? textColor : secondaryText }]}>{tab.label}</Text>
                  {isActive && <View style={[styles.tabIndicator, { backgroundColor: textColor }]} />}
                </TouchableOpacity>
              );
            })}
          </View>

          {editTab === 'profile' && renderProfileTab()}
          {editTab === 'attributes' && renderAttributesTab()}
          {editTab === 'interests' && renderInterestsTab()}
          {editTab === 'fantasies' && renderFantasiesTab()}
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  loader: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  headerRow: {
    paddingHorizontal: 16,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 16,
  },
  headerTitle: { fontSize: 20, fontFamily: 'Outfit-Bold', letterSpacing: 0.5 },
  backButton: { width: 36, height: 36, alignItems: 'center', justifyContent: 'center' },
  coverContainer: { height: 180, marginHorizontal: 16, borderRadius: 18, overflow: 'hidden' },
  coverImage: { width: '100%', height: '100%' },
  coverPlaceholder: { flex: 1 },
  coverAction: {
    position: 'absolute',
    right: 12,
    top: 12,
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarRow: { marginTop: -40, marginLeft: 24, flexDirection: 'row', alignItems: 'flex-end', gap: 12 },
  avatarWrapper: { width: 96, height: 96, borderRadius: 48, borderWidth: 4, overflow: 'hidden' },
  avatarImage: { width: '100%', height: '100%' },
  avatarPlaceholder: { width: '100%', height: '100%' },
  avatarAction: {
    width: 36,
    height: 36,
    borderRadius: 18,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  tabRow: {
    marginTop: 16,
    flexDirection: 'row',
    borderBottomWidth: 1,
    paddingHorizontal: 8,
  },
  tabButton: { flex: 1, paddingVertical: 14, alignItems: 'center' },
  tabLabel: { fontSize: 12, fontFamily: 'Inter-Bold', textTransform: 'uppercase', letterSpacing: 0.8 },
  tabIndicator: { marginTop: 8, height: 2, width: '40%', borderRadius: 2 },
  section: { paddingHorizontal: 16, paddingTop: 20 },
  sectionTitle: { fontSize: 20, fontFamily: 'Outfit-Bold', marginBottom: 12 },
  inputGroup: { marginBottom: 16 },
  inputLabel: { fontSize: 12, fontFamily: 'Inter-SemiBold', marginBottom: 6, textTransform: 'uppercase', letterSpacing: 0.6 },
  input: {
    borderWidth: 1,
    borderRadius: 14,
    paddingHorizontal: 14,
    paddingVertical: 12,
    fontFamily: 'Inter-Regular',
    fontSize: 14,
  },
  textarea: { minHeight: 120 },
  chipRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  chip: { paddingHorizontal: 12, paddingVertical: 8, borderRadius: 20, borderWidth: 1 },
  chipText: { fontSize: 12, fontFamily: 'Inter-SemiBold' },
  saveButton: { marginTop: 12, borderRadius: 20, paddingVertical: 14, alignItems: 'center' },
  saveButtonText: { fontSize: 14, fontFamily: 'Inter-Bold', textTransform: 'uppercase', letterSpacing: 0.6 },
  card: { borderRadius: 18, borderWidth: 1, marginBottom: 12, overflow: 'hidden' },
  cardHeader: { paddingHorizontal: 16, paddingVertical: 14, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  cardHeaderLeft: { flexDirection: 'row', alignItems: 'flex-start', gap: 8, flex: 1 },
  cardHeaderText: { flex: 1, minWidth: 0 },
  cardHeaderTitle: { fontSize: 14, fontFamily: 'Inter-SemiBold' },
  cardHeaderHint: { fontSize: 11, fontFamily: 'Inter-Regular', marginTop: 4, lineHeight: 14 },
  cardHeaderRight: { flexDirection: 'row', alignItems: 'center', gap: 8, flexShrink: 1 },
  cardHeaderValue: { fontSize: 12, fontFamily: 'Inter-Medium', maxWidth: 140 },
  cardContent: { borderTopWidth: 1, borderTopColor: 'rgba(0,0,0,0.04)', paddingHorizontal: 12, paddingBottom: 12 },
  optionRow: {
    marginTop: 10,
    borderWidth: 1,
    borderRadius: 12,
    paddingHorizontal: 12,
    paddingVertical: 10,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  optionText: { fontSize: 13, fontFamily: 'Inter-Medium' },
  emptyText: { fontSize: 13, fontFamily: 'Inter-Medium', textAlign: 'center', paddingVertical: 16 },
});
