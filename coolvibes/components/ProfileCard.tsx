
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { useTheme } from '@react-navigation/native';

type ProfileCardProps = {
  title: string;
  count?: number;
  total?: number;
  children: React.ReactNode;
};

export function ProfileCard({ title, count, total, children }: ProfileCardProps) {
  const { colors, dark } = useTheme();

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={[styles.title, { color: colors.text }]}>{title}</Text>
        {count !== undefined && total !== undefined && (
          <Text style={[styles.count, { color: colors.text }]}>
            {count} / {total}
          </Text>
        )}
      </View>
      <View
        style={[
          styles.card,
          {
            backgroundColor: dark ? 'rgba(255, 255, 255, 0.1)' : 'white',
            borderColor: dark ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.1)',
          },
        ]}
      >
        {children}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  title: {
    fontSize: 22,
    fontWeight: 'bold',
  },
  count: {
    fontSize: 13,
    fontWeight: '600',
    opacity: 0.5,
  },
  card: {
    borderRadius: 18,
    overflow: 'hidden',
    borderWidth: 1,
  },
});
