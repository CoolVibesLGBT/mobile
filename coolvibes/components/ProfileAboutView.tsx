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
        const value = (user as any)[item.field];
        if (value) {
            if (typeof value === 'string') return value;
            if (value.name) return value.name;
        }
        return 'Not set';
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
                tags={user.interests} 
                renderTag={(tag: any) => `${tag.emoji} ${tag.name}`} 
            />
            <TagsSection 
                title="Fantasies" 
                icon="heart-flash-outline" 
                tags={user.fantasies} 
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
