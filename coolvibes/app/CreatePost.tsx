import React, { useCallback, useMemo, useRef, useState } from 'react';
import { View, StyleSheet, StatusBar, ScrollView, Pressable, Text } from 'react-native';
import { useTheme } from '@react-navigation/native';
import { useRouter } from 'expo-router';
import MaterialCommunityIcons from '@expo/vector-icons/MaterialCommunityIcons';
import * as Haptics from 'expo-haptics';

import ChatInput from '@/components/ChatInput';
import { api } from '@/services/apiService';
import { useAppDispatch, useAppSelector } from '@/store/hooks';
import { completePostUpload, enqueuePostUpload, failPostUpload } from '@/store/slice/postUploads';

function plainTextToLexicalState(text: string): string {
  const safe = String(text ?? '').replace(/\r\n/g, '\n');
  const lines = safe.split('\n');

  const paragraphs = lines.map((line) => ({
    children: line
      ? [
          {
            detail: 0,
            format: 0,
            mode: 'normal',
            style: '',
            text: line,
            type: 'text',
            version: 1,
          },
        ]
      : [],
    direction: null,
    format: '',
    indent: 0,
    type: 'paragraph',
    version: 1,
    textFormat: 0,
    textStyle: '',
  }));

  return JSON.stringify({
    root: {
      children: paragraphs,
      direction: null,
      format: '',
      indent: 0,
      type: 'root',
      version: 1,
    },
  });
}

export default function CreatePostScreen() {
  const { colors, dark } = useTheme();
  const router = useRouter();
  const dispatch = useAppDispatch();
  const authUser = useAppSelector((state) => state.auth.user);
  const sendingRef = useRef(false);
  const [selectedPrompt, setSelectedPrompt] = useState<{ id: string; text: string } | null>(null);
  const borderColor = dark ? 'rgba(255,255,255,0.08)' : '#E8EDF4';
  const cardBackground = dark ? 'rgba(255,255,255,0.04)' : '#FFFFFF';
  const subtleBackground = dark ? 'rgba(255,255,255,0.06)' : '#F8FAFC';
  const mutedText = dark ? '#A1A1AA' : '#64748B';
  const promptCards = useMemo(() => ([
    {
      title: 'Bugunun enerjisi',
      description: 'Kucuk ama iyi hissettiren bir ani paylas.',
      text: 'Bugun bana iyi gelen kucuk bir sey su oldu: ',
      icon: 'weather-sunset-up',
      eyebrow: 'Personal',
    },
    {
      title: 'Topluluga soru sor',
      description: 'Samimi bir soru bircok guzel sohbet acabilir.',
      text: 'Bunu merak ediyorum: siz olsaniz nasil yapardiniz? ',
      icon: 'chat-question-outline',
      eyebrow: 'Question',
    },
    {
      title: 'Oneri birak',
      description: 'Bir mekan, sarki ya da deneyim oner.',
      text: 'Su aralar herkese onerebilecegim bir sey var: ',
      icon: 'star-four-points-outline',
      eyebrow: 'Recommendation',
    },
  ]), []);
  const quickVibes = useMemo(() => ([
    'samimi',
    'kisa',
    'acik',
    'merak uyandir',
  ]), []);

  const handleSendPost = useCallback(
    (text: string, media: any[] = []) => {
      const trimmed = String(text ?? '').trim();
      const outgoingMedia = Array.isArray(media) ? media : [];
      if (!trimmed && outgoingMedia.length === 0) return;
      if (sendingRef.current) return;

      sendingRef.current = true;
      const uploadId = `post-${Date.now()}`;
      let queued = false;

      try {
        const payload: Record<string, any> = {
          content: plainTextToLexicalState(trimmed),
          audience: 'public',
        };

        const imageFiles: any[] = [];

        outgoingMedia.forEach((item: any, index: number) => {
          const uri = typeof item?.uri === 'string' ? item.uri : '';
          if (!uri) return;

          if (item?.type === 'image') {
            imageFiles.push({
              uri,
              name: item?.name || `post-image-${Date.now()}-${index}.jpg`,
              type: item?.mimeType || 'image/jpeg',
            });
          }
        });

        if (imageFiles.length > 0) payload['images[]'] = imageFiles;

        const descriptionParts: string[] = [];
        if (trimmed) descriptionParts.push(trimmed.slice(0, 80));
        if (imageFiles.length > 0) {
          descriptionParts.push(imageFiles.length === 1 ? '1 gorsel' : `${imageFiles.length} gorsel`);
        }

        dispatch(enqueuePostUpload({
          id: uploadId,
          title: 'Cool post gonderiliyor',
          description: descriptionParts.join(' • '),
        }));
        queued = true;

        if (router.canGoBack()) {
          router.back();
        } else {
          router.replace('/(tabs)');
        }

        void api.createPost(payload)
          .then(() => {
            dispatch(completePostUpload({ id: uploadId }));
          })
          .catch((error: any) => {
            const message = typeof error?.response?.data?.message === 'string'
              ? error.response.data.message
              : typeof error?.message === 'string'
                ? error.message
                : 'Post gonderilemedi';
            dispatch(failPostUpload({ id: uploadId, message }));
          })
          .finally(() => {
            sendingRef.current = false;
          });
      } catch (error: any) {
        sendingRef.current = false;
        const message = typeof error?.message === 'string' ? error.message : 'Post gonderilemedi';
        dispatch(failPostUpload({ id: queued ? uploadId : `post-failed-${Date.now()}`, message }));
      }
    },
    [dispatch, router]
  );

  const handleSelectPrompt = useCallback((text: string, index: number) => {
    void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    setSelectedPrompt({
      id: `post-prompt-${Date.now()}-${index}`,
      text,
    });
  }, []);

  return (
    <View style={[styles.container, { backgroundColor: colors.background }]}>
      <StatusBar barStyle={dark ? 'light-content' : 'dark-content'} />
      <ScrollView
        style={styles.content}
        contentContainerStyle={styles.contentContainer}
        showsVerticalScrollIndicator={false}
      >
        <View
          style={[
            styles.introCard,
            {
              backgroundColor: cardBackground,
              borderColor,
            },
          ]}
        >
          <View style={styles.introTopRow}>
            <View
              style={[
                styles.introIconWrap,
                { backgroundColor: subtleBackground },
              ]}
            >
              <MaterialCommunityIcons
                name="creation-outline"
                size={18}
                color={dark ? '#FFFFFF' : '#111827'}
              />
            </View>
            <View style={[styles.introBadge, { backgroundColor: subtleBackground }]}>
              <Text style={[styles.introBadgeText, { color: mutedText }]}>
                Public post
              </Text>
            </View>
          </View>
          <Text style={[styles.introEyebrow, { color: mutedText }]}>
            CREATE FOR COOL
          </Text>
          <Text style={[styles.introTitle, { color: dark ? '#FFFFFF' : '#0F172A' }]}>
            Net bir fikir yaz. Gerisi sohbet olur.
          </Text>
          <Text style={[styles.introSubtitle, { color: mutedText }]}>
            Iyi bir post icin uzun yazman gerekmiyor. Kisa, temiz ve gercek bir giris yeterli.
          </Text>

          <View style={styles.signalRow}>
            <View style={[styles.signalCard, { backgroundColor: subtleBackground }]}>
              <Text style={[styles.signalValue, { color: dark ? '#FFFFFF' : '#0F172A' }]}>1</Text>
              <Text style={[styles.signalLabel, { color: mutedText }]}>cumleyle basla</Text>
            </View>
            <View style={[styles.signalCard, { backgroundColor: subtleBackground }]}>
              <Text style={[styles.signalValue, { color: dark ? '#FFFFFF' : '#0F172A' }]}>+</Text>
              <Text style={[styles.signalLabel, { color: mutedText }]}>gorsel ekle</Text>
            </View>
            <View style={[styles.signalCard, { backgroundColor: subtleBackground }]}>
              <Text style={[styles.signalValue, { color: dark ? '#FFFFFF' : '#0F172A' }]}>?</Text>
              <Text style={[styles.signalLabel, { color: mutedText }]}>cevap tetikle</Text>
            </View>
          </View>

          <View style={styles.vibeRow}>
            {quickVibes.map((item) => (
              <View
                key={item}
                style={[
                  styles.vibeChip,
                  { backgroundColor: subtleBackground },
                ]}
              >
                <Text style={[styles.vibeChipText, { color: dark ? '#E4E4E7' : '#475569' }]}>
                  {item}
                </Text>
              </View>
            ))}
          </View>
        </View>

        <View style={styles.sectionHeader}>
          <Text style={[styles.sectionTitle, { color: dark ? '#FFFFFF' : '#0F172A' }]}>
            Quick starts
          </Text>
          <Text style={[styles.sectionSubtitle, { color: mutedText }]}>
            Bir prompt sec, sonra sadece kendi sesinle tamamla.
          </Text>
        </View>

        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={styles.promptRow}
        >
          {promptCards.map((card, index) => (
            <Pressable
              key={card.title}
              onPress={() => handleSelectPrompt(card.text, index)}
              style={({ pressed }) => {
                const selected = selectedPrompt?.text === card.text;
                return [
                  styles.promptCard,
                  {
                    backgroundColor: selected ? (dark ? '#FFFFFF' : '#0F172A') : cardBackground,
                    borderColor: selected ? (dark ? '#FFFFFF' : '#0F172A') : borderColor,
                    opacity: pressed ? 0.94 : 1,
                    transform: [{ scale: pressed ? 0.988 : 1 }],
                  },
                ];
              }}
            >
              <View style={styles.promptHeaderRow}>
                <View
                  style={[
                    styles.promptIconWrap,
                    {
                      backgroundColor: selectedPrompt?.text === card.text
                        ? (dark ? 'rgba(15,23,42,0.10)' : 'rgba(255,255,255,0.14)')
                        : subtleBackground,
                    },
                  ]}
                >
                  <MaterialCommunityIcons
                    name={card.icon as any}
                    size={18}
                    color={selectedPrompt?.text === card.text
                      ? (dark ? '#0F172A' : '#FFFFFF')
                      : (dark ? '#FFFFFF' : '#0F172A')}
                  />
                </View>
                <MaterialCommunityIcons
                  name={selectedPrompt?.text === card.text ? 'check-circle' : 'arrow-top-right'}
                  size={18}
                  color={selectedPrompt?.text === card.text
                    ? (dark ? '#0F172A' : '#FFFFFF')
                    : mutedText}
                />
              </View>
              <Text
                style={[
                  styles.promptEyebrow,
                  {
                    color: selectedPrompt?.text === card.text
                      ? (dark ? '#475569' : 'rgba(255,255,255,0.72)')
                      : mutedText,
                  },
                ]}
              >
                {card.eyebrow}
              </Text>
              <Text
                style={[
                  styles.promptTitle,
                  {
                    color: selectedPrompt?.text === card.text
                      ? (dark ? '#0F172A' : '#FFFFFF')
                      : (dark ? '#FFFFFF' : '#111827'),
                  },
                ]}
              >
                {card.title}
              </Text>
              <Text
                style={[
                  styles.promptDescription,
                  {
                    color: selectedPrompt?.text === card.text
                      ? (dark ? '#64748B' : 'rgba(255,255,255,0.78)')
                      : mutedText,
                  },
                ]}
              >
                {card.description}
              </Text>
            </Pressable>
          ))}
        </ScrollView>

        {selectedPrompt ? (
          <View
            style={[
              styles.selectedTemplateCard,
              { backgroundColor: subtleBackground, borderColor },
            ]}
          >
            <View style={styles.selectedTemplateHeader}>
              <Text style={[styles.selectedTemplateLabel, { color: mutedText }]}>
                Secilen baslangic
              </Text>
              <Pressable onPress={() => setSelectedPrompt(null)} hitSlop={10}>
                <Text style={[styles.selectedTemplateClear, { color: dark ? '#FFFFFF' : '#0F172A' }]}>
                  Temizle
                </Text>
              </Pressable>
            </View>
            <Text style={[styles.selectedTemplateText, { color: dark ? '#FFFFFF' : '#0F172A' }]}>
              {selectedPrompt.text}
            </Text>
          </View>
        ) : null}
      </ScrollView>

      <View style={styles.inputWrap}>
        <ChatInput
          kind="post"
          autoFocus
          textTemplate={selectedPrompt}
          currentUser={authUser}
          replyingTo={null}
          editingMessage={null}
          onCancelReply={() => null}
          onCancelEdit={() => null}
          onSendMessage={handleSendPost}
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  content: {
    flex: 1,
  },
  contentContainer: {
    paddingHorizontal: 20,
    paddingTop: 20,
    paddingBottom: 28,
    gap: 18,
  },
  introCard: {
    borderWidth: 1,
    borderRadius: 24,
    padding: 20,
    gap: 12,
  },
  introTopRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  introIconWrap: {
    width: 38,
    height: 38,
    borderRadius: 19,
    alignItems: 'center',
    justifyContent: 'center',
  },
  introBadge: {
    borderRadius: 999,
    paddingHorizontal: 10,
    paddingVertical: 5,
  },
  introBadgeText: {
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 0.4,
    textTransform: 'uppercase',
  },
  introEyebrow: {
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 1.1,
  },
  introTitle: {
    fontSize: 26,
    lineHeight: 32,
    fontWeight: '800',
  },
  introSubtitle: {
    fontSize: 14,
    lineHeight: 21,
    fontWeight: '500',
  },
  signalRow: {
    flexDirection: 'row',
    gap: 10,
  },
  signalCard: {
    flex: 1,
    borderRadius: 18,
    paddingVertical: 12,
    paddingHorizontal: 10,
    alignItems: 'center',
    gap: 2,
  },
  signalValue: {
    fontSize: 18,
    fontWeight: '800',
  },
  signalLabel: {
    fontSize: 11,
    fontWeight: '700',
    textAlign: 'center',
  },
  vibeRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  vibeChip: {
    borderRadius: 999,
    paddingHorizontal: 12,
    paddingVertical: 7,
  },
  vibeChipText: {
    fontSize: 12,
    fontWeight: '700',
    textTransform: 'capitalize',
  },
  sectionHeader: {
    gap: 4,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '800',
  },
  sectionSubtitle: {
    fontSize: 14,
    lineHeight: 20,
    fontWeight: '500',
  },
  promptRow: {
    gap: 12,
    paddingRight: 20,
  },
  promptCard: {
    borderWidth: 1,
    borderRadius: 22,
    padding: 16,
    gap: 10,
    width: 220,
  },
  promptHeaderRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  promptIconWrap: {
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
  },
  promptEyebrow: {
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 0.5,
    textTransform: 'uppercase',
  },
  promptTitle: {
    fontSize: 16,
    fontWeight: '800',
  },
  promptDescription: {
    fontSize: 14,
    lineHeight: 20,
    fontWeight: '500',
  },
  selectedTemplateCard: {
    borderWidth: 1,
    borderRadius: 20,
    padding: 16,
    gap: 10,
  },
  selectedTemplateHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  selectedTemplateLabel: {
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 0.5,
    textTransform: 'uppercase',
  },
  selectedTemplateClear: {
    fontSize: 13,
    fontWeight: '700',
  },
  selectedTemplateText: {
    fontSize: 15,
    lineHeight: 22,
    fontWeight: '600',
  },
  inputWrap: {
    width: '100%',
  },
});
