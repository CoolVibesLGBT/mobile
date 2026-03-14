import React from 'react';
import { Share, StyleSheet, Text, TouchableOpacity, View, ScrollView } from 'react-native';
import { useTheme } from '@react-navigation/native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppErrorPayload, formatErrorDetails, reportAppError } from '@/helpers/errorReporter';

type Props = {
  children: React.ReactNode;
};

type State = {
  error: Error | null;
  info: React.ErrorInfo | null;
  payload: AppErrorPayload | null;
};

export default class AppErrorBoundary extends React.Component<Props, State> {
  state: State = {
    error: null,
    info: null,
    payload: null,
  };

  static getDerivedStateFromError(error: Error) {
    return { error };
  }

  componentDidCatch(error: Error, info: React.ErrorInfo) {
    const payload = reportAppError(error, {
      source: 'render',
      extra: { componentStack: info.componentStack },
      fatal: true,
    });
    this.setState({ info, payload });
  }

  handleRetry = () => {
    this.setState({ error: null, info: null, payload: null });
  };

  render() {
    const { error, info, payload } = this.state;
    if (!error) return this.props.children;
    return (
      <ErrorFallback
        error={error}
        info={info}
        payload={payload}
        onRetry={this.handleRetry}
      />
    );
  }
}

function ErrorFallback({
  error,
  info,
  payload,
  onRetry,
}: {
  error: Error;
  info: React.ErrorInfo | null;
  payload: AppErrorPayload | null;
  onRetry: () => void;
}) {
  const { colors, dark } = useTheme();
  const insets = useSafeAreaInsets();

  const detailsPayload: AppErrorPayload = payload ?? {
    id: `${Date.now()}-fallback`,
    message: error.message || 'Unknown error',
    name: error.name,
    stack: error.stack,
    source: 'render',
    extra: info?.componentStack ? { componentStack: info.componentStack } : undefined,
    fatal: true,
    timestamp: Date.now(),
  };

  const details = formatErrorDetails(detailsPayload);

  const handleSend = async () => {
    try {
      await Share.share({
        title: 'CoolVibes Hata Raporu',
        message: details,
      });
    } catch {
      // ignore share errors
    }
  };

  return (
    <View style={[styles.fallback, { backgroundColor: dark ? '#000' : '#FFF', paddingTop: insets.top + 32 }]}>
      <View style={styles.content}>
        <Text style={[styles.title, { color: colors.text }]}>Bir hata oluştu</Text>
        <Text style={[styles.subtitle, { color: colors.text, opacity: 0.7 }]}>
          Uygulama beklenmedik bir hata verdi. Detayları gönderebilir veya yeniden deneyebilirsiniz.
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
            onPress={onRetry}
          >
            <Text style={[styles.secondaryText, { color: colors.text }]}>Tekrar Dene</Text>
          </TouchableOpacity>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  fallback: {
    flex: 1,
  },
  content: {
    flex: 1,
    paddingHorizontal: 20,
  },
  title: {
    fontSize: 22,
    fontFamily: 'Outfit-Bold',
  },
  subtitle: {
    marginTop: 8,
    fontSize: 13,
    fontFamily: 'Inter-Regular',
  },
  details: {
    marginTop: 16,
    borderRadius: 12,
    backgroundColor: 'rgba(0,0,0,0.08)',
    maxHeight: 320,
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
    marginTop: 16,
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
