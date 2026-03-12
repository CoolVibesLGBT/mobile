import React from 'react';
import { View, StyleSheet, Text } from 'react-native';
import { useTheme } from '@react-navigation/native';
import MaterialCommunityIcons from '@expo/vector-icons/MaterialCommunityIcons';
import { USER_ATTRIBUTES } from '@/constants/profile-data';
import { useAppSelector } from '@/store/hooks';
import { parsePreferencesFlags, isBitSet } from '@/helpers/bitfield';

type ProfileAboutViewProps = {
    user: any;
};

const ProfileAboutView = ({ user }: ProfileAboutViewProps) => {
    const { dark } = useTheme();
    const systemData = useAppSelector(state => state.system.data);
    const flags = parsePreferencesFlags(user.preferences_flags);
    const language = useAppSelector(state => state.system.language) || 'en';

    // Monochrome Colors
    const textColor = dark ? '#FFFFFF' : '#000000';
    const secondaryText = dark ? '#888888' : '#666666';
    const borderColor = dark ? (dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.06)') : '#F0F0F0';
    const surfaceColor = dark ? 'rgba(255,255,255,0.03)' : 'rgba(0,0,0,0.02)';

    const getAttributeValue = (item: any) => {
        // 1. Try bitfield from preferences_flags first (New Architecture)
        if (systemData?.preferences?.attributes) {
            const configAttr = systemData.preferences.attributes.find((a: any) => a.tag === item.field);
            if (configAttr && configAttr.items) {
                const selectedItems = configAttr.items.filter((opt: any) => isBitSet(flags, opt.bit_index));
                if (selectedItems.length > 0) {
                    return selectedItems.map((si: any) => si.title?.[language] || si.title?.en || si.slug).join(', ');
                }
            }
        }

        // 2. Try direct field on user object
        const topLevelValue = (user as any)[item.field];
        if (topLevelValue) {
            if (typeof topLevelValue === 'string') return topLevelValue;
            if (typeof topLevelValue === 'number') return String(topLevelValue);
            if (topLevelValue.name) {
                if (typeof topLevelValue.name === 'string') return topLevelValue.name;
                return topLevelValue.name[language] || topLevelValue.name.en || Object.values(topLevelValue.name)[0];
            }
            if (topLevelValue.title) {
                if (typeof topLevelValue.title === 'string') return topLevelValue.title;
                return topLevelValue.title[language] || topLevelValue.title.en || Object.values(topLevelValue.title)[0];
            }
        }

        // 3. Try user_attributes array (Old Architecture)
        if (user.user_attributes && Array.isArray(user.user_attributes)) {
            const attr = user.user_attributes.find((ua: any) => ua.category_type === item.field);
            if (attr && attr.attribute && attr.attribute.name) {
                const name = attr.attribute.name;
                if (typeof name === 'string') return name;
                return name[language] || name.en || Object.values(name)[0];
            }
        }

        return null;
    };

    const getInterestsByCategory = () => {
        if (!systemData?.preferences?.interests) return {};
        const categorized: Record<string, { title: string, items: any[] }> = {};
        systemData.preferences.interests.forEach((cat: any) => {
            const catTitle = cat.title?.[language] || cat.title?.en || cat.id;
            const items: any[] = [];
            if (cat.items) {
                cat.items.forEach((item: any) => {
                    if (isBitSet(flags, item.bit_index)) {
                        items.push({
                            name: item.title?.[language] || item.title?.en || item.slug,
                            emoji: item.icon || '✨'
                        });
                    }
                });
            }
            if (items.length > 0) {
                categorized[cat.id] = { title: catTitle, items };
            }
        });
        return categorized;
    };

    const getFantasiesByCategory = () => {
        if (!systemData?.preferences?.fantasies) return {};
        const categorized: Record<string, { title: string, items: any[] }> = {};
        systemData.preferences.fantasies.forEach((cat: any) => {
            const catTitle = cat.title?.[language] || cat.title?.en || cat.slug;
            const items: any[] = [];
            if (cat.items) {
                cat.items.forEach((item: any) => {
                    if (isBitSet(flags, item.bit_index)) {
                        items.push({
                            name: item.title?.[language] || item.title?.en || item.slug,
                            emoji: item.emoji || '🔥'
                        });
                    }
                });
            }
            if (items.length > 0) {
                categorized[cat.slug] = { title: catTitle, items };
            }
        });
        return categorized;
    };

    const attributesData = USER_ATTRIBUTES.map((attr: any) => ({
        ...attr,
        value: getAttributeValue(attr)
    }));

    const filledCount = attributesData.filter((a: any) => a.value !== null).length;
    const totalCount = USER_ATTRIBUTES.length;

    const categorizedInterests = getInterestsByCategory();
    const categorizedFantasies = getFantasiesByCategory();

    const isEmpty = filledCount === 0 && 
                    Object.keys(categorizedInterests).length === 0 && 
                    Object.keys(categorizedFantasies).length === 0;

    if (isEmpty) {
        return (
            <View style={styles.emptyContainer}>
                <MaterialCommunityIcons name="account-details-outline" size={48} color={secondaryText} style={{ marginBottom: 12 }} />
                <Text style={[styles.emptyText, { color: textColor }]}>No profile details set yet.</Text>
                <Text style={[styles.emptySubText, { color: secondaryText }]}>Complete your profile to let others know more about you.</Text>
            </View>
        );
    }

    return (
        <View style={styles.container}>
            {/* Attributes Section */}
            <View style={styles.section}>
                <View style={styles.sectionHeader}>
                    <Text style={[styles.sectionTitle, { color: textColor }]}>Attributes</Text>
                    <Text style={[styles.sectionCount, { color: secondaryText }]}>{filledCount} / {totalCount}</Text>
                </View>
                <View style={[styles.card, { borderColor, backgroundColor: surfaceColor }]}>
                    {attributesData.map((item: any, index: number) => {
                        const isLast = index === attributesData.length - 1;
                        return (
                            <View key={item.field} style={[styles.attrRow, !isLast && { borderBottomWidth: 1, borderBottomColor: borderColor }]}>
                                <View style={styles.attrLabelCol}>
                                    <View style={[styles.iconContainer, { backgroundColor: dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.04)' }]}>
                                        <MaterialCommunityIcons name={item.icon as any} size={22} color={textColor} />
                                    </View>
                                    <Text style={[styles.attrLabel, { color: textColor }]}>{item.label}</Text>
                                </View>
                                <View style={styles.attrValueCol}>
                                    {!item.value && <View style={styles.dot} />}
                                    <Text style={[styles.attrValue, { color: item.value ? secondaryText : (dark ? '#FFD700' : '#B8860B') }]}>
                                        {item.value || 'Select option'}
                                    </Text>
                                </View>
                            </View>
                        );
                    })}
                </View>
            </View>

            {/* Fantasies Section */}
            {Object.keys(categorizedFantasies).length > 0 && (
                <View style={styles.section}>
                    <View style={styles.sectionHeader}>
                        <Text style={[styles.sectionTitle, { color: textColor }]}>Fantasies</Text>
                        <Text style={[styles.sectionCount, { color: secondaryText }]}>
                            {Object.values(categorizedFantasies).reduce((acc, cat) => acc + cat.items.length, 0)}
                        </Text>
                    </View>
                    {Object.entries(categorizedFantasies).map(([slug, cat]) => (
                        <View key={slug} style={[styles.categoryCard, { borderColor, backgroundColor: surfaceColor }]}>
                            <View style={[styles.categoryHeader, { borderBottomColor: borderColor }]}>
                                <Text style={[styles.categoryTitle, { color: secondaryText }]}>{cat.title.toUpperCase()}</Text>
                            </View>
                            <View style={styles.tagGrid}>
                                {cat.items.map((item, idx) => (
                                    <View key={idx} style={[styles.tag, { backgroundColor: dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.04)', borderColor }]}>
                                        <Text style={[styles.tagText, { color: textColor }]}>{item.name}</Text>
                                    </View>
                                ))}
                            </View>
                        </View>
                    ))}
                </View>
            )}

            {/* Interests Section */}
            {Object.keys(categorizedInterests).length > 0 && (
                <View style={styles.section}>
                    <View style={styles.sectionHeader}>
                        <Text style={[styles.sectionTitle, { color: textColor }]}>Interests</Text>
                        <Text style={[styles.sectionCount, { color: secondaryText }]}>
                            {Object.values(categorizedInterests).reduce((acc, cat) => acc + cat.items.length, 0)}
                        </Text>
                    </View>
                    {Object.entries(categorizedInterests).map(([id, cat]) => (
                        <View key={id} style={[styles.categoryCard, { borderColor, backgroundColor: surfaceColor }]}>
                            <View style={[styles.categoryHeader, { borderBottomColor: borderColor }]}>
                                <Text style={[styles.categoryTitle, { color: secondaryText }]}>{cat.title.toUpperCase()}</Text>
                            </View>
                            <View style={styles.tagGrid}>
                                {cat.items.map((item, idx) => (
                                    <View key={idx} style={[styles.tag, { backgroundColor: dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.04)', borderColor }]}>
                                        <Text style={[styles.tagText, { color: textColor }]}>
                                            <Text style={{ fontSize: 16 }}>{item.emoji}</Text> {item.name}
                                        </Text>
                                    </View>
                                ))}
                            </View>
                        </View>
                    ))}
                </View>
            )}
        </View>
    );
};

const styles = StyleSheet.create({
    container: { padding: 16 },
    section: { marginBottom: 32 },
    sectionHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 },
    sectionTitle: { fontSize: 22, fontFamily: 'Outfit-Bold', letterSpacing: -0.5 },
    sectionCount: { fontSize: 13, fontFamily: 'Inter-SemiBold' },
    card: { borderRadius: 18, borderWidth: 1, overflow: 'hidden' },
    attrRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 16, paddingVertical: 12 },
    attrLabelCol: { flexDirection: 'row', alignItems: 'center', flex: 1 },
    iconContainer: { width: 32, height: 32, borderRadius: 10, alignItems: 'center', justifyContent: 'center', marginRight: 12 },
    attrLabel: { fontSize: 15, fontFamily: 'Inter-Medium' },
    attrValueCol: { flexDirection: 'row', alignItems: 'center', gap: 6 },
    attrValue: { fontSize: 13, fontFamily: 'Inter-Medium' },
    dot: { width: 6, height: 6, borderRadius: 3, backgroundColor: '#FFD700' },
    categoryCard: { borderRadius: 18, borderWidth: 1, overflow: 'hidden', marginBottom: 12 },
    categoryHeader: { paddingHorizontal: 16, paddingVertical: 10, borderBottomWidth: 1 },
    categoryTitle: { fontSize: 11, fontFamily: 'Inter-Bold', letterSpacing: 0.8 },
    tagGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, padding: 14 },
    tag: { paddingHorizontal: 16, paddingVertical: 8, borderRadius: 20, borderWidth: 1 },
    tagText: { fontSize: 14, fontFamily: 'Inter-Medium' },
    emptyContainer: { alignItems: 'center', justifyContent: 'center', paddingVertical: 60, opacity: 0.8 },
    emptyText: { fontSize: 18, fontFamily: 'Outfit-Bold', marginBottom: 6 },
    emptySubText: { fontSize: 14, fontFamily: 'Inter-Medium', textAlign: 'center', paddingHorizontal: 40 },
});

export default ProfileAboutView;
