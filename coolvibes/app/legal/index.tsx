import React from 'react';
import {
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { useTheme } from '@react-navigation/native';
import { useRouter } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import MaterialCommunityIcons from '@expo/vector-icons/MaterialCommunityIcons';

import { LEGAL_PAGE_ORDER, LEGAL_PAGES, LegalPageKey } from '@/helpers/legal';

export default function LegalIndexScreen() {
  const { colors, dark } = useTheme();
  const router = useRouter();
  const insets = useSafeAreaInsets();

  const borderColor = dark ? 'rgba(255,255,255,0.08)' : 'rgba(15,23,42,0.08)';
  const cardBackground = dark ? 'rgba(255,255,255,0.04)' : '#FFFFFF';
  const surfaceBackground = dark ? 'rgba(255,255,255,0.06)' : '#F8FAFC';
  const mutedText = dark ? 'rgba(255,255,255,0.58)' : 'rgba(15,23,42,0.58)';

  return (
    <ScrollView
      style={[styles.container, { backgroundColor: colors.background }]}
      contentContainerStyle={[styles.contentContainer, { paddingBottom: insets.bottom + 28 }]}
      showsVerticalScrollIndicator={false}
    >
      <View style={[styles.heroCard, { backgroundColor: surfaceBackground, borderColor }]}>
        <Text style={[styles.heroTitle, { color: colors.text }]}>Legal Center</Text>
        <Text style={[styles.heroText, { color: mutedText }]}>
          Privacy, terms, community guidelines and support information for CoolVibes.
        </Text>
      </View>

      <View style={styles.listWrap}>
        {LEGAL_PAGE_ORDER.map((key) => {
          const page = LEGAL_PAGES[key];

          return (
            <Pressable
              key={key}
              style={({ pressed }) => [
                styles.card,
                {
                  backgroundColor: cardBackground,
                  borderColor,
                  opacity: pressed ? 0.95 : 1,
                  transform: [{ scale: pressed ? 0.992 : 1 }],
                },
              ]}
              onPress={() => router.push(`/legal/${key}` as `/legal/${LegalPageKey}`)}
            >
              <View style={[styles.cardIcon, { backgroundColor: surfaceBackground }]}>
                <MaterialCommunityIcons
                  name={page.icon as keyof typeof MaterialCommunityIcons.glyphMap}
                  size={22}
                  color={colors.text}
                />
              </View>

              <View style={styles.cardBody}>
                <Text style={[styles.cardTitle, { color: colors.text }]}>{page.title}</Text>
                <Text style={[styles.cardSubtitle, { color: mutedText }]} numberOfLines={2}>
                  {page.description}
                </Text>
              </View>

              <MaterialCommunityIcons name="chevron-right" size={20} color={colors.text} />
            </Pressable>
          );
        })}
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  contentContainer: {
    paddingHorizontal: 20,
    paddingTop: 24,
  },
  heroCard: {
    borderWidth: 1,
    borderRadius: 24,
    paddingHorizontal: 18,
    paddingVertical: 18,
  },
  heroTitle: {
    fontSize: 28,
    lineHeight: 32,
    fontFamily: 'Outfit-Bold',
    letterSpacing: -0.5,
  },
  heroText: {
    marginTop: 8,
    fontSize: 14,
    lineHeight: 20,
    fontFamily: 'Inter-Regular',
  },
  listWrap: {
    marginTop: 16,
    gap: 12,
  },
  card: {
    borderWidth: 1,
    borderRadius: 22,
    padding: 16,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
  },
  cardIcon: {
    width: 46,
    height: 46,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
  },
  cardBody: {
    flex: 1,
    gap: 4,
  },
  cardTitle: {
    fontSize: 17,
    fontFamily: 'Outfit-Bold',
  },
  cardSubtitle: {
    fontSize: 13,
    lineHeight: 18,
    fontFamily: 'Inter-Regular',
  },
});
