
import React from 'react';
import { View, StyleSheet } from 'react-native';
import { ThemedText } from './ThemedText';

export function AttributeIcon({ name, color }: { name: string; color: string }) {
  return (
    <View style={styles.container}>
      <ThemedText style={{ color }}>{name.substring(0, 1)}</ThemedText>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    width: 28,
    height: 28,
    borderRadius: 8,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: 'rgba(0,0,0,0.1)',
  },
});
