import React, { useState } from 'react';
import { View, TouchableOpacity, StyleSheet, LayoutAnimation, Platform, UIManager } from 'react-native';
import { ThemedText } from '@/components/ThemedText';
import { useTheme } from '@react-navigation/native';
import MaterialCommunityIcons from '@expo/vector-icons/MaterialCommunityIcons';

if (Platform.OS === 'android' && UIManager.setLayoutAnimationEnabledExperimental) {
  UIManager.setLayoutAnimationEnabledExperimental(true);
}

type AccordionSectionProps = {
    title: string;
    icon: keyof typeof MaterialCommunityIcons.glyphMap;
    children: React.ReactNode;
};

const AccordionSection = ({ title, icon, children }: AccordionSectionProps) => {
    const { colors, dark } = useTheme();
    const [isOpen, setIsOpen] = useState(false);

    const toggleOpen = () => {
      LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
      setIsOpen(!isOpen);
    };

    const borderColor = dark ? '#2F2F2F' : '#EBEBEB';
    const cardColor = dark ? '#1A1A1A' : '#F6F6F6';
  
    return (
      <View style={[styles.accordionContainer, { backgroundColor: cardColor, borderColor: borderColor }]}>
        <TouchableOpacity onPress={toggleOpen} style={styles.accordionHeader}>
          <View style={{ flexDirection: 'row', alignItems: 'center' }}>
            <MaterialCommunityIcons name={icon} size={20} color={colors.text} style={{ opacity: 0.8 }} />
            <ThemedText style={styles.accordionTitle}>{title}</ThemedText>
          </View>
          <MaterialCommunityIcons name={isOpen ? 'chevron-up' : 'chevron-down'} size={24} color={colors.text} style={{ opacity: 0.6 }} />
        </TouchableOpacity>
        {isOpen && <View style={styles.accordionContent}>{children}</View>}
      </View>
    );
};

const styles = StyleSheet.create({
    accordionContainer: { 
        borderRadius: 12, 
        marginBottom: 10, 
        borderWidth: 1, 
        overflow: 'hidden' 
    },
    accordionHeader: { 
        flexDirection: 'row', 
        justifyContent: 'space-between', 
        alignItems: 'center', 
        padding: 16 
    },
    accordionTitle: { 
        fontSize: 16, 
        fontWeight: '600', 
        marginLeft: 12 
    },
    accordionContent: { 
        paddingBottom: 6 
    },
});

export default AccordionSection;
