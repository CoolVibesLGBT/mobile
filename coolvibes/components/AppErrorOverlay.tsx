import React, { useEffect, useMemo, useState } from 'react';
import { Modal, Share, StyleSheet, Text, TouchableOpacity, View, ScrollView } from 'react-native';
import { useTheme } from '@react-navigation/native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppErrorPayload, formatErrorDetails, getLastAppError, subscribeToAppErrors } from '@/helpers/errorReporter';
import * as Clipboard from 'expo-clipboard';

export default function AppErrorOverlay() {
  const { colors, dark } = useTheme();
  const insets = useSafeAreaInsets();
  const [error, setError] = useState<AppErrorPayload | null>(null);
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    setError(getLastAppError());
    return subscribeToAppErrors(payload => {
      setError(payload);
    });
  }, []);

  const details = useMemo(() => (error ? formatErrorDetails(error) : ''), [error]);

  const handleSend = async () => {
    if (!error) return;
    try {
      await Share.share({
        title: 'CoolVibes Hata Raporu',
        message: details,
      });
    } catch {
      // ignore share errors
    }
  };

  const handleCopy = async () => {
    if (!error) return;
    try {
      await Clipboard.setStringAsync(details);
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    } catch {
      // ignore clipboard errors
    }
  };

  if (!error) return null;

  return (
    <Modal
      visible
      transparent
      animationType="fade"
      onRequestClose={() => setError(null)}
    >
      <View style={styles.backdrop}>
        <View
          style={[
            styles.card,
            {
              backgroundColor: dark ? '#0F0F0F' : '#FFFFFF',
              borderColor: dark ? '#232323' : '#E5E5E5',
              paddingBottom: 16 + insets.bottom,
              marginTop: insets.top + 12,
            },
          ]}
        >
          <Text style={[styles.title, { color: colors.text }]}>Bir hata oluştu</Text>
          <Text style={[styles.subtitle, { color: colors.text, opacity: 0.7 }]}>
            Hata detaylarını bizimle paylaşabilirsiniz.
          </Text>

          <ScrollView style={styles.details} contentContainerStyle={styles.detailsContent}>
            <Text style={[styles.detailsText, { color: colors.text }]}>{details}</Text>
          </ScrollView>

          <View style={styles.actions}>
            <TouchableOpacity
              style={[styles.primaryBtn, { backgroundColor: dark ? '#1F5FFF' : '#1E4ED8' }]}
              activeOpacity={0.85}
              onPress={handleSend}
            >
              <Text style={styles.primaryText}>Hata Detayı Gönder</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.secondaryBtn, { borderColor: dark ? '#2A2A2A' : '#E0E0E0' }]}
              activeOpacity={0.8}
              onPress={handleCopy}
            >
              <Text style={[styles.secondaryText, { color: colors.text }]}>
                {copied ? 'Kopyalandı' : 'Kopyala'}
              </Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.secondaryBtn, { borderColor: dark ? '#2A2A2A' : '#E0E0E0' }]}
              activeOpacity={0.8}
              onPress={() => setError(null)}
            >
              <Text style={[styles.secondaryText, { color: colors.text }]}>Kapat</Text>
            </TouchableOpacity>
          </View>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.55)',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 18,
  },
  card: {
    width: '100%',
    borderRadius: 18,
    borderWidth: 1,
    paddingHorizontal: 18,
    paddingTop: 18,
    maxHeight: '80%',
  },
  title: {
    fontSize: 20,
    fontFamily: 'Outfit-Bold',
  },
  subtitle: {
    marginTop: 6,
    fontSize: 13,
    fontFamily: 'Inter-Regular',
  },
  details: {
    marginTop: 14,
    borderRadius: 12,
    backgroundColor: 'rgba(0,0,0,0.08)',
    maxHeight: 260,
  },
  detailsContent: {
    padding: 12,
  },
  detailsText: {
    fontSize: 12,
    fontFamily: 'Inter-Regular',
    lineHeight: 16,
  },
  actions: {
    marginTop: 14,
    gap: 10,
  },
  primaryBtn: {
    height: 46,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  primaryText: {
    color: '#FFFFFF',
    fontSize: 14,
    fontFamily: 'Inter-SemiBold',
  },
  secondaryBtn: {
    height: 44,
    borderRadius: 12,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  secondaryText: {
    fontSize: 13,
    fontFamily: 'Inter-SemiBold',
  },
});
