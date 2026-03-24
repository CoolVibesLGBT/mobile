import React, { useCallback, useMemo, useRef, useState } from 'react';
import {
  Platform,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from 'react-native';
import { useTheme } from '@react-navigation/native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import MaterialCommunityIcons from '@expo/vector-icons/MaterialCommunityIcons';

import ChatInput from '@/components/ChatInput';
import { tabToClassifiedKind } from '@/helpers/classifieds';
import { plainTextToLexicalState } from '@/helpers/plainTextToLexicalState';
import { api } from '@/services/apiService';
import { useAppDispatch, useAppSelector } from '@/store/hooks';
import { completeBackgroundTask, enqueueBackgroundTask, failBackgroundTask } from '@/store/slice/postUploads';

type ClassifiedTab = 'hiring' | 'seeking';

type MetadataItem = {
  key: string;
  value: string;
};

function normalizeRouteTab(value: string | string[] | undefined): ClassifiedTab {
  const raw = Array.isArray(value) ? value[0] : value;
  return raw === 'seeking' ? 'seeking' : 'hiring';
}

function normalizeTitleParam(value: string | string[] | undefined): string {
  const raw = Array.isArray(value) ? value[0] : value;
  return typeof raw === 'string' ? raw : '';
}

export default function ClassifiedCreateScreen() {
  const { colors, dark } = useTheme();
  const router = useRouter();
  const dispatch = useAppDispatch();
  const authUser = useAppSelector((state) => state.auth.user);
  const params = useLocalSearchParams<{ tab?: string; title?: string }>();
  const sendingRef = useRef(false);

  const [activeTab, setActiveTab] = useState<ClassifiedTab>(normalizeRouteTab(params.tab));
  const [listingTitle, setListingTitle] = useState(normalizeTitleParam(params.title));
  const [metadataKey, setMetadataKey] = useState('');
  const [metadataValue, setMetadataValue] = useState('');
  const [metadataItems, setMetadataItems] = useState<MetadataItem[]>([]);
  const [validationText, setValidationText] = useState('');

  const borderColor = dark ? 'rgba(255,255,255,0.08)' : 'rgba(15,23,42,0.08)';
  const mutedText = dark ? 'rgba(255,255,255,0.58)' : 'rgba(15,23,42,0.58)';
  const softBackground = dark ? 'rgba(255,255,255,0.04)' : '#FFFFFF';
  const surfaceBackground = dark ? 'rgba(255,255,255,0.06)' : '#F8FAFC';
  const activeChipBackground = dark ? '#FFFFFF' : '#0F172A';
  const activeChipText = dark ? '#0B0B0B' : '#FFFFFF';

  const selectedKind = useMemo(() => tabToClassifiedKind(activeTab), [activeTab]);

  const handleAddMetadata = useCallback(() => {
    const key = metadataKey.trim();
    const value = metadataValue.trim();
    if (!key || !value) return;

    setMetadataItems((current) => {
      const existingIndex = current.findIndex((item) => item.key.toLowerCase() === key.toLowerCase());
      if (existingIndex >= 0) {
        const next = [...current];
        next[existingIndex] = { key, value };
        return next;
      }
      return [...current, { key, value }];
    });

    setMetadataKey('');
    setMetadataValue('');
  }, [metadataKey, metadataValue]);

  const handleRemoveMetadata = useCallback((key: string) => {
    setMetadataItems((current) => current.filter((item) => item.key !== key));
  }, []);

  const handleSendClassified = useCallback(
    (text: string, media: any[] = []) => {
      if (sendingRef.current) return;

      const title = listingTitle.trim();
      if (!title) {
        setValidationText('Listing title is required.');
        return;
      }

      const outgoingMedia = Array.isArray(media) ? media : [];
      const trimmedText = String(text ?? '').trim();

      if (!trimmedText && outgoingMedia.length === 0) {
        setValidationText('Add a description or media before publishing.');
        return;
      }

      setValidationText('');
      sendingRef.current = true;

      const taskId = `classified-${Date.now()}`;
      const payload: Record<string, any> = {
        content: plainTextToLexicalState(trimmedText),
        audience: 'public',
        kind: selectedKind,
        'extras[title]': JSON.stringify(title),
      };

      if (metadataItems.length > 0) {
        payload['extras[metadata]'] = metadataItems;
      }

      const imageFiles: any[] = [];
      const videoFiles: any[] = [];

      outgoingMedia.forEach((item: any, index: number) => {
        const uri = typeof item?.uri === 'string' ? item.uri : '';
        if (!uri) return;

        if (item?.type === 'image') {
          imageFiles.push({
            uri,
            name: item?.name || `classified-image-${Date.now()}-${index}.jpg`,
            type: item?.mimeType || 'image/jpeg',
          });
          return;
        }

        if (item?.type === 'video') {
          videoFiles.push({
            uri,
            name: item?.name || `classified-video-${Date.now()}-${index}.mp4`,
            type: item?.mimeType || 'video/mp4',
          });
        }
      });

      if (imageFiles.length > 0) payload['images[]'] = imageFiles;
      if (videoFiles.length > 0) payload['videos[]'] = videoFiles;

      dispatch(
        enqueueBackgroundTask({
          id: taskId,
          kind: 'classified.create',
          title: 'Ilan gonderiliyor',
          description: title,
        })
      );

      if (router.canGoBack()) {
        router.back();
      } else {
        router.replace('/Classifieds');
      }

      void api.createPost(payload)
        .then(() => {
          dispatch(
            completeBackgroundTask({
              id: taskId,
              kind: 'classified.create',
            })
          );
        })
        .catch((error: any) => {
          const message =
            typeof error?.response?.data?.message === 'string'
              ? error.response.data.message
              : typeof error?.message === 'string'
                ? error.message
                : 'Ilan gonderilemedi';

          dispatch(
            failBackgroundTask({
              id: taskId,
              kind: 'classified.create',
              title: 'Ilan gonderimi',
              message,
            })
          );
        })
        .finally(() => {
          sendingRef.current = false;
        });
    },
    [dispatch, listingTitle, metadataItems, router, selectedKind]
  );

  return (
    <View style={[styles.container, { backgroundColor: colors.background }]}>
      <StatusBar barStyle={dark ? 'light-content' : 'dark-content'} />

      <ScrollView
        contentContainerStyle={[
          styles.contentContainer,
          {
            paddingBottom: Platform.OS === 'ios' ? 260 : 232,
          },
        ]}
        keyboardShouldPersistTaps="handled"
        showsVerticalScrollIndicator={false}
      >
        <View style={[styles.heroCard, { backgroundColor: softBackground, borderColor }]}>
          <View style={styles.heroRow}>
            <View style={[styles.heroIcon, { backgroundColor: dark ? 'rgba(255,255,255,0.08)' : 'rgba(15,23,42,0.06)' }]}>
              <MaterialCommunityIcons name="briefcase-outline" size={20} color={colors.text} />
            </View>
            <View style={{ flex: 1 }}>
              <Text style={[styles.heroTitle, { color: colors.text }]}>Create listing</Text>
              <Text style={[styles.heroSubtitle, { color: mutedText }]}>
                Same composer standard, classifieds payload.
              </Text>
            </View>
          </View>

          <View style={[styles.segmentWrap, { backgroundColor: dark ? 'rgba(255,255,255,0.05)' : '#F1F5F9', borderColor }]}>
            {(['hiring', 'seeking'] as ClassifiedTab[]).map((tab) => {
              const selected = tab === activeTab;
              return (
                <TouchableOpacity
                  key={tab}
                  style={[
                    styles.segmentButton,
                    selected && { backgroundColor: activeChipBackground },
                  ]}
                  activeOpacity={0.86}
                  onPress={() => setActiveTab(tab)}
                >
                  <Text
                    style={[
                      styles.segmentText,
                      { color: selected ? activeChipText : colors.text },
                    ]}
                  >
                    {tab === 'hiring' ? 'Hiring' : 'Seeking'}
                  </Text>
                </TouchableOpacity>
              );
            })}
          </View>
        </View>

        <View style={[styles.sectionCard, { backgroundColor: softBackground, borderColor }]}>
          <Text style={[styles.sectionLabel, { color: mutedText }]}>Listing title</Text>
          <TextInput
            value={listingTitle}
            onChangeText={(value) => {
              setListingTitle(value);
              if (validationText) setValidationText('');
            }}
            placeholder="Senior designer, roommate, tutor..."
            placeholderTextColor={dark ? 'rgba(255,255,255,0.36)' : 'rgba(15,23,42,0.34)'}
            style={[
              styles.titleInput,
              {
                color: colors.text,
                borderColor,
                backgroundColor: surfaceBackground,
              },
            ]}
          />
          <Text style={[styles.helperText, { color: mutedText }]}>
            This maps to `extras.title`, same as web.
          </Text>
        </View>

        <View style={[styles.sectionCard, { backgroundColor: softBackground, borderColor }]}>
          <View style={styles.sectionHeaderRow}>
            <View>
              <Text style={[styles.sectionLabel, { color: mutedText }]}>Metadata</Text>
              <Text style={[styles.helperText, { color: mutedText }]}>
                Key/value details shown on the listing card and detail screen.
              </Text>
            </View>
          </View>

          <View style={styles.metadataInputRow}>
            <TextInput
              value={metadataKey}
              onChangeText={setMetadataKey}
              placeholder="Key"
              placeholderTextColor={dark ? 'rgba(255,255,255,0.36)' : 'rgba(15,23,42,0.34)'}
              style={[
                styles.metadataInput,
                {
                  color: colors.text,
                  borderColor,
                  backgroundColor: surfaceBackground,
                },
              ]}
            />
            <TextInput
              value={metadataValue}
              onChangeText={setMetadataValue}
              placeholder="Value"
              placeholderTextColor={dark ? 'rgba(255,255,255,0.36)' : 'rgba(15,23,42,0.34)'}
              style={[
                styles.metadataInput,
                {
                  color: colors.text,
                  borderColor,
                  backgroundColor: surfaceBackground,
                },
              ]}
            />
          </View>

          <TouchableOpacity
            style={[styles.metadataAddButton, { backgroundColor: activeChipBackground }]}
            onPress={handleAddMetadata}
            activeOpacity={0.86}
          >
            <MaterialCommunityIcons name="plus" size={18} color={activeChipText} />
            <Text style={[styles.metadataAddText, { color: activeChipText }]}>Add detail</Text>
          </TouchableOpacity>

          {metadataItems.length > 0 ? (
            <View style={styles.metadataList}>
              {metadataItems.map((item) => (
                <View
                  key={item.key}
                  style={[
                    styles.metadataCard,
                    {
                      backgroundColor: surfaceBackground,
                      borderColor,
                    },
                  ]}
                >
                  <View style={{ flex: 1 }}>
                    <Text style={[styles.metadataKey, { color: mutedText }]}>{item.key}</Text>
                    <Text style={[styles.metadataValue, { color: colors.text }]}>{item.value}</Text>
                  </View>
                  <TouchableOpacity onPress={() => handleRemoveMetadata(item.key)} activeOpacity={0.8}>
                    <MaterialCommunityIcons name="close" size={20} color={colors.text} />
                  </TouchableOpacity>
                </View>
              ))}
            </View>
          ) : null}
        </View>

        {validationText ? (
          <View style={[styles.validationCard, { borderColor: 'rgba(220,38,38,0.18)', backgroundColor: dark ? 'rgba(127,29,29,0.18)' : 'rgba(254,242,242,1)' }]}>
            <MaterialCommunityIcons name="alert-circle-outline" size={18} color={dark ? '#FCA5A5' : '#B91C1C'} />
            <Text style={[styles.validationText, { color: dark ? '#FCA5A5' : '#B91C1C' }]}>{validationText}</Text>
          </View>
        ) : null}
      </ScrollView>

      <View style={styles.inputDock}>
        <ChatInput
          kind="classified"
          autoFocus
          currentUser={authUser}
          replyingTo={null}
          editingMessage={null}
          onCancelReply={() => null}
          onCancelEdit={() => null}
          onSendMessage={handleSendClassified}
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  contentContainer: {
    paddingHorizontal: 20,
    paddingTop: 24,
    gap: 16,
  },
  heroCard: {
    borderWidth: 1,
    borderRadius: 24,
    padding: 18,
    gap: 18,
  },
  heroRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
  },
  heroIcon: {
    width: 46,
    height: 46,
    borderRadius: 23,
    alignItems: 'center',
    justifyContent: 'center',
  },
  heroTitle: {
    fontSize: 22,
    fontFamily: 'Outfit-Bold',
    letterSpacing: -0.4,
  },
  heroSubtitle: {
    marginTop: 4,
    fontSize: 13,
    lineHeight: 19,
    fontFamily: 'Inter-Regular',
  },
  segmentWrap: {
    flexDirection: 'row',
    borderRadius: 18,
    padding: 4,
    borderWidth: 1,
  },
  segmentButton: {
    flex: 1,
    height: 42,
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
  },
  segmentText: {
    fontSize: 13,
    fontFamily: 'Inter-Bold',
  },
  sectionCard: {
    borderWidth: 1,
    borderRadius: 24,
    padding: 18,
  },
  sectionHeaderRow: {
    marginBottom: 14,
  },
  sectionLabel: {
    fontSize: 12,
    fontFamily: 'Inter-Bold',
    textTransform: 'uppercase',
    letterSpacing: 1.1,
  },
  helperText: {
    marginTop: 6,
    fontSize: 13,
    lineHeight: 19,
    fontFamily: 'Inter-Regular',
  },
  titleInput: {
    minHeight: 54,
    borderWidth: 1,
    borderRadius: 16,
    paddingHorizontal: 16,
    fontSize: 16,
    fontFamily: 'Inter-SemiBold',
  },
  metadataInputRow: {
    flexDirection: 'row',
    gap: 10,
  },
  metadataInput: {
    flex: 1,
    minHeight: 50,
    borderWidth: 1,
    borderRadius: 16,
    paddingHorizontal: 14,
    fontSize: 14,
    fontFamily: 'Inter-Medium',
  },
  metadataAddButton: {
    marginTop: 12,
    alignSelf: 'flex-start',
    paddingHorizontal: 14,
    height: 40,
    borderRadius: 14,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  metadataAddText: {
    fontSize: 13,
    fontFamily: 'Inter-Bold',
  },
  metadataList: {
    marginTop: 14,
    gap: 10,
  },
  metadataCard: {
    borderWidth: 1,
    borderRadius: 18,
    paddingHorizontal: 14,
    paddingVertical: 12,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  metadataKey: {
    fontSize: 11,
    fontFamily: 'Inter-Bold',
    textTransform: 'uppercase',
    letterSpacing: 0.8,
  },
  metadataValue: {
    marginTop: 4,
    fontSize: 14,
    lineHeight: 19,
    fontFamily: 'Inter-SemiBold',
  },
  validationCard: {
    borderWidth: 1,
    borderRadius: 18,
    paddingHorizontal: 14,
    paddingVertical: 12,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  validationText: {
    flex: 1,
    fontSize: 13,
    lineHeight: 18,
    fontFamily: 'Inter-SemiBold',
  },
  inputDock: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 0,
  },
});
