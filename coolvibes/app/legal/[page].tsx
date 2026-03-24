import React from 'react';
import {
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { useTheme } from '@react-navigation/native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import MaterialCommunityIcons from '@expo/vector-icons/MaterialCommunityIcons';

import { getLegalPage } from '@/helpers/legal';

export default function LegalDetailScreen() {
  const { colors, dark } = useTheme();
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const params = useLocalSearchParams<{ page?: string }>();

  const pageParam = Array.isArray(params.page) ? params.page[0] : params.page;
  const page = getLegalPage(pageParam);

  const borderColor = dark ? 'rgba(255,255,255,0.08)' : 'rgba(15,23,42,0.08)';
  const cardBackground = dark ? 'rgba(255,255,255,0.04)' : '#FFFFFF';
  const surfaceBackground = dark ? 'rgba(255,255,255,0.06)' : '#F8FAFC';
  const mutedText = dark ? 'rgba(255,255,255,0.58)' : 'rgba(15,23,42,0.58)';

  if (!page) {
    return (
      <View style={[styles.emptyContainer, { backgroundColor: colors.background }]}>
        <Text style={[styles.emptyTitle, { color: colors.text }]}>Page not found</Text>
        <Text style={[styles.emptyText, { color: mutedText }]}>
          The legal page you requested does not exist.
        </Text>
        <Pressable
          style={[styles.emptyButton, { backgroundColor: colors.text }]}
          onPress={() => router.replace('/legal')}
        >
          <Text style={[styles.emptyButtonText, { color: colors.background }]}>View legal index</Text>
        </Pressable>
      </View>
    );
  }

  return (
    <ScrollView
      style={[styles.container, { backgroundColor: colors.background }]}
      contentContainerStyle={[styles.contentContainer, { paddingBottom: insets.bottom + 28 }]}
      showsVerticalScrollIndicator={false}
    >
      <View style={[styles.heroCard, { backgroundColor: surfaceBackground, borderColor }]}>
        <View style={[styles.heroIcon, { backgroundColor: colors.text }]}>
          <MaterialCommunityIcons
            name={page.icon as keyof typeof MaterialCommunityIcons.glyphMap}
            size={26}
            color={colors.background}
          />
        </View>
        <Text style={[styles.heroTitle, { color: colors.text }]}>{page.title}</Text>
        <Text style={[styles.heroSubtitle, { color: mutedText }]}>{page.description}</Text>
      </View>

      <View style={styles.sectionList}>
        {page.sections.map((section) => (
          <View
            key={section.heading}
            style={[styles.sectionCard, { backgroundColor: cardBackground, borderColor }]}
          >
            <Text style={[styles.sectionTitle, { color: colors.text }]}>{section.heading}</Text>
            <Text style={[styles.sectionBody, { color: mutedText }]}>{section.body}</Text>
          </View>
        ))}
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
    paddingVertical: 20,
    alignItems: 'center',
  },
  heroIcon: {
    width: 64,
    height: 64,
    borderRadius: 22,
    alignItems: 'center',
    justifyContent: 'center',
  },
  heroTitle: {
    marginTop: 14,
    fontSize: 28,
    lineHeight: 32,
    textAlign: 'center',
    fontFamily: 'Outfit-Bold',
    letterSpacing: -0.5,
  },
  heroSubtitle: {
    marginTop: 8,
    fontSize: 14,
    lineHeight: 20,
    textAlign: 'center',
    fontFamily: 'Inter-Regular',
  },
  sectionList: {
    marginTop: 16,
    gap: 12,
  },
  sectionCard: {
    borderWidth: 1,
    borderRadius: 22,
    paddingHorizontal: 16,
    paddingVertical: 16,
  },
  sectionTitle: {
    fontSize: 18,
    lineHeight: 22,
    fontFamily: 'Outfit-Bold',
  },
  sectionBody: {
    marginTop: 8,
    fontSize: 14,
    lineHeight: 21,
    fontFamily: 'Inter-Regular',
  },
  emptyContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 24,
  },
  emptyTitle: {
    fontSize: 24,
    lineHeight: 28,
    fontFamily: 'Outfit-Bold',
  },
  emptyText: {
    marginTop: 8,
    textAlign: 'center',
    fontSize: 14,
    lineHeight: 20,
    fontFamily: 'Inter-Regular',
  },
  emptyButton: {
    marginTop: 16,
    borderRadius: 16,
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  emptyButtonText: {
    fontSize: 14,
    fontFamily: 'Inter-Bold',
  },
});
