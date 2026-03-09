import React from 'react';
import { View, StyleSheet } from 'react-native';
import { useTheme } from '@react-navigation/native';
import AccordionSection from './AccordionSection';
import AttributeRow from './AttributeRow';
import TagsSection from './TagsSection';
import { ABOUT_SECTIONS, ATTRIBUTES_MAP } from '@/constants/profile-data';

type ProfileAboutViewProps = {
    user: any;
};

const ProfileAboutView = ({ user }: ProfileAboutViewProps) => {
    const { colors, dark } = useTheme();

    const getAttributeValue = (item: any) => {
        // 1. Try top-level field (common in both web and mobile)
        const topLevelValue = (user as any)[item.field];
        if (topLevelValue) {
            if (typeof topLevelValue === 'string') return topLevelValue;
            if (typeof topLevelValue === 'number') return String(topLevelValue);
            if (topLevelValue.name) {
                if (typeof topLevelValue.name === 'string') return topLevelValue.name;
                // Handle localized name object from web
                const firstLang = Object.keys(topLevelValue.name)[0];
                if (firstLang) return topLevelValue.name[firstLang];
            }
        }

        // 2. Try user_attributes array (standard structure for web API)
        if (user.user_attributes && Array.isArray(user.user_attributes)) {
            const attr = user.user_attributes.find((ua: any) => ua.category_type === item.field);
            if (attr && attr.attribute && attr.attribute.name) {
                if (typeof attr.attribute.name === 'string') return attr.attribute.name;
                // Handle localized name object
                const firstLang = Object.keys(attr.attribute.name)[0];
                if (firstLang) return attr.attribute.name[firstLang];
            }
        }

        // 3. Handle specific mappings for fields like gender, height, etc. if they are named differently
        if (item.field === 'gender_identity' && user.gender) return user.gender;

        return 'Not set';
    };

    // Helper to get interests/fantasies tags
    const getInterestTags = () => {
        if (!user.interests) return [];
        return user.interests.map((it: any) => {
            // Case 1: interest_item object (web)
            if (it.interest_item) {
                const nameObj = it.interest_item.name;
                const name = typeof nameObj === 'string' ? nameObj : (Object.values(nameObj)[0] as string);
                return {
                    id: it.id,
                    name: name,
                    emoji: it.interest_item.emoji || '✨'
                };
            }
            // Case 2: direct name (mobile dummy)
            return {
                id: it.id || it.name,
                name: it.name,
                emoji: it.emoji || '✨'
            };
        });
    };

    const getFantasyTags = () => {
        if (!user.fantasies) return [];
        return user.fantasies.map((it: any) => {
            // Case 1: fantasy object (web)
            if (it.fantasy) {
                const labelObj = it.fantasy.label;
                const name = typeof labelObj === 'string' ? labelObj : (Object.values(labelObj)[0] as string);
                return {
                    id: it.id,
                    name: name,
                    emoji: it.fantasy.emoji || '❤️'
                };
            }
            // Case 2: direct name (mobile dummy)
            return {
                id: it.id || it.name,
                name: it.name,
                emoji: it.emoji || '❤️'
            };
        });
    };

    return (
        <View style={styles.aboutContainer}>
            {ABOUT_SECTIONS.map(section => {
                const attributes = section.attributes
                    .map(field => ATTRIBUTES_MAP[field])
                    .filter(Boolean)
                    .filter(item => getAttributeValue(item) !== 'Not set');

                if (attributes.length === 0) return null;

                return (
                    <AccordionSection key={section.title} title={section.title} icon={section.icon as any}>
                        {attributes.map(item => (
                            <AttributeRow 
                                key={item.field} 
                                icon={item.icon as any}
                                label={item.label}
                                value={getAttributeValue(item)}
                            />
                        ))}
                    </AccordionSection>
                );
            })}
            
            <TagsSection 
                title="Interests" 
                icon="star-outline" 
                tags={getInterestTags()} 
                renderTag={(tag: any) => `${tag.emoji} ${tag.name}`} 
            />
            
            <TagsSection 
                title="Fantasies" 
                icon="heart-multiple-outline" 
                tags={getFantasyTags()} 
                renderTag={(tag: any) => `${tag.emoji} ${tag.name}`} 
            />
        </View>
    );
};

const styles = StyleSheet.create({
    aboutContainer: { 
        padding: 16 
    },
});

export default ProfileAboutView;
