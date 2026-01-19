import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import MaterialCommunityIcons from '@expo/vector-icons/MaterialCommunityIcons';
import { useTheme } from '@react-navigation/native';

type AttributeRowProps = {
  icon: keyof typeof MaterialCommunityIcons.glyphMap;
  label: string;
  value: string;
};

const AttributeRow = ({ icon, label, value }: AttributeRowProps) => {
  const { colors } = useTheme();
  if (!value || value === 'Not set') return null;

  return (
    <View style={styles.attributeRow}>
      <View style={styles.row}>
        <MaterialCommunityIcons name={icon} size={20} color={colors.text} style={styles.attributeIcon} />
        <Text style={[styles.attributeLabel, { color: colors.text }]}>{label}</Text>
      </View>
      <Text style={[styles.attributeValue, { color: colors.text, opacity: 0.8 }]}>{value}</Text>
    </View>
  );
};

const styles = StyleSheet.create({
    attributeRow: { 
        flexDirection: 'row', 
        justifyContent: 'space-between', 
        alignItems: 'center', 
        paddingVertical: 12,
    },
    row: {
        flexDirection: 'row',
        alignItems: 'center',
        flex: 1
    },
    attributeIcon: { 
        opacity: 0.7, 
        marginRight: 12, 
        width: 24 
    },
    attributeLabel: { 
        fontSize: 16, 
    },
    attributeValue: { 
        fontSize: 16, 
        fontWeight: '500' 
    },
});

export default AttributeRow;
