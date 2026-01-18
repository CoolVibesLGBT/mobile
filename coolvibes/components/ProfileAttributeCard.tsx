
import React from 'react';
import { View, Text, StyleSheet, useColorScheme } from 'react-native';
import { ThemedText } from './ThemedText';
import { LinearGradient } from 'expo-linear-gradient';

type Props = {
  title: string;
  count?: number;
  total?: number;
  children: React.ReactNode;
};

export function ProfileAttributeCard({ title, count, total, children }: Props) {
  const colorScheme = useColorScheme() ?? 'light';
  const isDark = colorScheme === 'dark';

  const cardStyles = {
    backgroundColor: isDark ? 'rgba(30, 30, 30, 0.7)' : 'rgba(255, 255, 255, 0.8)',
    borderColor: isDark ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.08)',
    borderWidth: 1,
  };
  
  const gradientColors = isDark 
    ? ['rgba(40, 40, 40, 0.8)', 'rgba(30, 30, 30, 0.8)'] 
    : ['#ffffff', '#fcfcfc'];


  return (
    <View style={styles.wrapper}>
      <View style={styles.header}>
        <ThemedText style={styles.title}>{title}</ThemedText>
        {count !== undefined && total !== undefined && (
          <ThemedText type="secondary" style={styles.count}>
            {count} / {total}
          </ThemedText>
        )}
      </View>
      <View style={[styles.cardContainer, cardStyles]}>
        <LinearGradient colors={gradientColors} style={styles.gradient}>
            {children}
        </LinearGradient>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrapper: {
    paddingHorizontal: 16,
    marginBottom: 24,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  title: {
    fontSize: 20,
    fontWeight: 'bold',
  },
  count: {
    fontSize: 14,
    fontWeight: '600',
  },
  cardContainer: {
    borderRadius: 18,
    overflow: 'hidden',
    // Note: backdrop-blur is not directly supported in React Native
  },
  gradient: {
      flex: 1,
  }
});
