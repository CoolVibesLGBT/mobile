import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import MaterialCommunityIcons from '@expo/vector-icons/MaterialCommunityIcons';
import { useTheme } from '@react-navigation/native';

type TagsSectionProps = {
    title: string;
    icon: keyof typeof MaterialCommunityIcons.glyphMap;
    tags: any[];
    renderTag: (tag: any) => string;
};

const TagsSection = ({ title, icon, tags, renderTag }: TagsSectionProps) => {
    const { colors, dark } = useTheme();
    const borderColor = dark ? '#2F2F2F' : '#EBEBEB';
    const cardColor = dark ? '#1A1A1A' : '#F6F6F6';
    const backgroundColor = dark ? '#000000' : '#FFFFFF';
    const textColor = colors.text;

    if (!tags || tags.length === 0) return null;

    return (
        <View style={[styles.accordionContainer, { backgroundColor: cardColor, borderColor: borderColor }]}>
            <View style={styles.accordionHeader}>
                <MaterialCommunityIcons name={icon} size={20} color={textColor} style={{ opacity: 0.8 }} />
                <Text style={[styles.accordionTitle, { color: textColor }]}>{title}</Text>
            </View>
            <View style={styles.tagContainer}>
                {tags.map((tag: any, index: number) => (
                    <View key={index} style={[styles.tag, { backgroundColor: dark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.05)' }]}>
                        <Text style={[styles.tagText, { color: textColor }]}>{renderTag(tag)}</Text>
                    </View>
                ))}
            </View>
        </View>
    );
};

const styles = StyleSheet.create({
    accordionContainer: { 
        borderRadius: 12, 
        marginTop: 10,
        borderWidth: 1, 
        overflow: 'hidden' 
    },
    accordionHeader: { 
        flexDirection: 'row', 
        alignItems: 'center', 
        padding: 16 
    },
    accordionTitle: { 
        marginLeft: 12, 
        fontSize: 16, 
        fontWeight: '600' 
    },
    tagContainer: { 
        flexDirection: 'row', 
        flexWrap: 'wrap', 
        paddingHorizontal: 16, 
        paddingBottom: 16, 
        paddingTop: 4 
    },
    tag: { 
        paddingHorizontal: 14, 
        paddingVertical: 8, 
        borderRadius: 18, 
        margin: 4 
    },
    tagText: { 
        fontSize: 14, 
        fontWeight: '500' 
    },
});

export default TagsSection;
