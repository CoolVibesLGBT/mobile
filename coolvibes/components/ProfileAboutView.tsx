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

type OptionItem = {
    id: string;
    name: string;
    bit_index?: number;
};

type CategoryGroup = {
    title: string;
    items: Array<{ name: string; emoji?: string }>;
};

const ProfileAboutView = ({ user }: ProfileAboutViewProps) => {
    const { dark } = useTheme();
    const systemData = useAppSelector(state => state.system.data);
    const flags = parsePreferencesFlags(user?.preferences_flags);
    const language = useAppSelector(state => state.system.language) || 'en';

    // Monochrome Colors
    const textColor = dark ? '#FFFFFF' : '#000000';
    const secondaryText = dark ? '#888888' : '#666666';
    const borderColor = dark ? (dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.06)') : '#F0F0F0';
    const surfaceColor = dark ? 'rgba(255,255,255,0.03)' : 'rgba(0,0,0,0.02)';

    const getLocalizedText = (value: any, fallback = '') => {
        if (!value) return fallback;
        if (typeof value === 'string') return value;
        if (typeof value === 'number') return String(value);
        if (typeof value === 'object') {
            return value[language] || value.en || Object.values(value)[0] || fallback;
        }
        return fallback;
    };

    const getNameFromEntity = (entity: any) => {
        if (!entity) return '';
        if (typeof entity === 'string' || typeof entity === 'number') return String(entity);
        if (entity.name) return getLocalizedText(entity.name);
        if (entity.title) return getLocalizedText(entity.title);
        return '';
    };

    const fieldOptions: Record<string, OptionItem[]> = {};
    const fieldAllowMultiple: Record<string, boolean> = {};
    const fieldLabels: Record<string, string> = {};
    const fieldDescriptions: Record<string, string> = {};

    const preferencesRoot = (systemData as any)?.data?.preferences || (systemData as any)?.preferences;
    const legacyRoot = (systemData as any)?.data || systemData;
    const preferencesAttributes = preferencesRoot?.attributes;
    if (Array.isArray(preferencesAttributes)) {
        preferencesAttributes.forEach((attr: any) => {
            const tag = attr.tag || attr.slug;
            const allowMultiple = attr.allow_multiple || false;
            fieldAllowMultiple[tag] = allowMultiple;
            fieldLabels[tag] = getLocalizedText(attr.title, tag);
            fieldDescriptions[tag] = getLocalizedText(attr.description, '');

            if (Array.isArray(attr.items)) {
                const sortedItems = [...attr.items].sort((a: any, b: any) => (a.display_order || 0) - (b.display_order || 0));
                fieldOptions[tag] = sortedItems.map((item: any) => ({
                    id: item.id,
                    name: getLocalizedText(item.title) || item.slug || '',
                    bit_index: item.bit_index,
                }));
            }
        });
    } else {
        const legacy = legacyRoot as any;
        if (Array.isArray(legacy?.attributes)) {
            legacy.attributes.forEach((group: any) => {
                const sortedAttributes = [...(group.attributes || [])].sort((a: any, b: any) => (a.display_order || 0) - (b.display_order || 0));
                fieldOptions[group.category] = sortedAttributes.map((attr: any) => ({
                    id: attr.id,
                    name: getLocalizedText(attr.name),
                }));
            });
        }

        if (Array.isArray(legacy?.gender_identities)) {
            const sortedGenderIdentities = [...legacy.gender_identities].sort((a: any, b: any) => (a.display_order || 0) - (b.display_order || 0));
            fieldOptions['gender_identity'] = sortedGenderIdentities.map((item: any) => ({
                id: item.id,
                name: getLocalizedText(item.name),
            }));
        }

        if (Array.isArray(legacy?.sexual_orientations)) {
            const sortedSexualOrientations = [...legacy.sexual_orientations].sort((a: any, b: any) => (a.display_order || 0) - (b.display_order || 0));
            fieldOptions['sexual_orientation'] = sortedSexualOrientations.map((item: any) => ({
                id: item.id,
                name: getLocalizedText(item.name),
            }));
        }

        if (Array.isArray(legacy?.sexual_roles)) {
            const sortedSexualRoles = [...legacy.sexual_roles].sort((a: any, b: any) => (a.display_order || 0) - (b.display_order || 0));
            fieldOptions['sex_role'] = sortedSexualRoles.map((item: any) => ({
                id: item.id,
                name: getLocalizedText(item.name),
            }));
        }
    }

    const getAttributeValue = (item: any) => {
        const options = fieldOptions[item.field] || [];
        const allowMultiple = fieldAllowMultiple[item.field] || false;
        const usePreferencesFlags = options.some(opt => opt.bit_index !== undefined);

        if (usePreferencesFlags) {
            const selectedOptions = options.filter(opt => opt.bit_index !== undefined && isBitSet(flags, opt.bit_index));
            if (selectedOptions.length > 0) {
                const selectedNames = selectedOptions.map(opt => opt.name).filter(Boolean);
                return {
                    value: allowMultiple ? selectedNames.join(', ') : selectedOptions[0].name,
                    selectedOptions: selectedNames,
                    allowMultiple,
                    hasValue: true,
                };
            }
            return { value: null, selectedOptions: [], allowMultiple, hasValue: false };
        }

        if (item.field === 'gender_identity') {
            const genderIdentities = user?.gender_identities || user?.sexual_identities?.gender_identities;
            const identityList = Array.isArray(genderIdentities) ? genderIdentities : (genderIdentities ? [genderIdentities] : []);
            const names = identityList.map(getNameFromEntity).filter(Boolean);
            if (names.length > 0) {
                return {
                    value: allowMultiple ? names.join(', ') : names[0],
                    selectedOptions: allowMultiple ? names : [names[0]],
                    allowMultiple,
                    hasValue: true,
                };
            }

            const genderIdentity = user?.gender_identity;
            const name = getNameFromEntity(genderIdentity);
            if (name) return { value: name, selectedOptions: [name], allowMultiple, hasValue: true };
        }

        if (item.field === 'sexual_orientation') {
            const sexualOrientations = user?.sexual_orientations || user?.sexual_identities?.sexual_orientations;
            const orientationList = Array.isArray(sexualOrientations) ? sexualOrientations : (sexualOrientations ? [sexualOrientations] : []);
            const names = orientationList.map(getNameFromEntity).filter(Boolean);
            if (names.length > 0) {
                return {
                    value: allowMultiple ? names.join(', ') : names[0],
                    selectedOptions: allowMultiple ? names : [names[0]],
                    allowMultiple,
                    hasValue: true,
                };
            }

            const sexualOrientation = user?.sexual_orientation;
            const name = getNameFromEntity(sexualOrientation);
            if (name) return { value: name, selectedOptions: [name], allowMultiple, hasValue: true };
        }

        if (item.field === 'sex_role') {
            const sexRole = user?.sexual_role || user?.sex_role || user?.sexual_identities?.sex_role;
            const name = getNameFromEntity(sexRole);
            if (name) return { value: name, selectedOptions: [name], allowMultiple, hasValue: true };
        }

        const topLevelValue = user?.[item.field];
        if (topLevelValue) {
            const name = getNameFromEntity(topLevelValue);
            if (name) return { value: name, selectedOptions: [name], allowMultiple, hasValue: true };
        }

        if (Array.isArray(user?.user_attributes)) {
            const attr = user.user_attributes.find((ua: any) => ua.category_type === item.field);
            if (attr?.attribute?.name) {
                const name = getLocalizedText(attr.attribute.name);
                if (name) return { value: name, selectedOptions: [name], allowMultiple, hasValue: true };
            }
        }

        if (item.field === 'relationship_status' && user?.relationship_status) {
            return { value: String(user.relationship_status), selectedOptions: [String(user.relationship_status)], allowMultiple, hasValue: true };
        }

        return { value: null, selectedOptions: [], allowMultiple, hasValue: false };
    };

    const getInterestsByCategory = (): Record<string, CategoryGroup> => {
        const categorized: Record<string, CategoryGroup> = {};
        const preferencesInterests = preferencesRoot?.interests;

        if (Array.isArray(preferencesInterests)) {
            preferencesInterests.forEach((cat: any) => {
                const catTitle = getLocalizedText(cat.title, cat.id);
                const items: Array<{ name: string; emoji?: string }> = [];
                if (Array.isArray(cat.items)) {
                    cat.items.forEach((item: any) => {
                        if (item.bit_index !== undefined && isBitSet(flags, item.bit_index)) {
                            items.push({
                                name: getLocalizedText(item.title, item.slug),
                                emoji: item.icon || '✨',
                            });
                        }
                    });
                }
                if (items.length > 0) {
                    categorized[cat.id] = { title: catTitle, items };
                }
            });
        }

        if (Object.keys(categorized).length > 0) return categorized;

        const interestsSource = user?.interests;
        if (Array.isArray(interestsSource)) {
            interestsSource.forEach((userInterest: any) => {
                if (typeof userInterest === 'object' && userInterest !== null && userInterest.interest_item) {
                    const interestItem = userInterest.interest_item;
                    const categoryId = interestItem.interest_id || interestItem.interest?.id || 'other';
                    const categoryName = getLocalizedText(interestItem.interest?.name, 'Other');
                    if (!categorized[categoryId]) {
                        categorized[categoryId] = { title: categoryName, items: [] };
                    }
                    categorized[categoryId].items.push({
                        name: getLocalizedText(interestItem.name, String(interestItem.id || '')),
                        emoji: interestItem.emoji,
                    });
                } else {
                    const categoryId = 'other';
                    if (!categorized[categoryId]) {
                        categorized[categoryId] = { title: 'Other', items: [] };
                    }
                    categorized[categoryId].items.push({ name: String(userInterest) });
                }
            });
        }

        return categorized;
    };

    const getFantasiesByCategory = (): Record<string, CategoryGroup> => {
        const categorized: Record<string, CategoryGroup> = {};
        const preferencesFantasies = preferencesRoot?.fantasies;

        if (Array.isArray(preferencesFantasies)) {
            preferencesFantasies.forEach((cat: any) => {
                const catTitle = getLocalizedText(cat.title, cat.slug || cat.id);
                const items: Array<{ name: string; emoji?: string }> = [];
                if (Array.isArray(cat.items)) {
                    cat.items.forEach((item: any) => {
                        if (item.bit_index !== undefined && isBitSet(flags, item.bit_index)) {
                            items.push({
                                name: getLocalizedText(item.title, item.slug),
                                emoji: item.emoji || '🔥',
                            });
                        }
                    });
                }
                if (items.length > 0) {
                    categorized[cat.slug || cat.id] = { title: catTitle, items };
                }
            });
        }

        if (Object.keys(categorized).length > 0) return categorized;

        const fantasiesSource = user?.fantasies;
        const legacyFantasies = (legacyRoot as any)?.fantasies;
        if (Array.isArray(fantasiesSource)) {
            fantasiesSource.forEach((userFantasy: any) => {
                if (typeof userFantasy === 'object' && userFantasy !== null) {
                    const fantasy = userFantasy.fantasy;
                    if (fantasy) {
                        const categoryId = fantasy.slug || fantasy.category?.en || 'other';
                        const categoryName = getLocalizedText(fantasy.category, categoryId);
                        if (!categorized[categoryId]) {
                            categorized[categoryId] = { title: categoryName, items: [] };
                        }
                        categorized[categoryId].items.push({
                            name: getLocalizedText(fantasy.label || fantasy.title, String(fantasy.id || userFantasy.fantasy_id || '')),
                        });
                        return;
                    }

                    const fantasyId = userFantasy.fantasy_id || userFantasy.id;
                    if (fantasyId && Array.isArray(legacyFantasies)) {
                        const fallbackFantasy = legacyFantasies.find((f: any) => f.id === fantasyId);
                        if (fallbackFantasy) {
                            const categoryId = fallbackFantasy.slug || 'other';
                            const categoryName = getLocalizedText(fallbackFantasy.category, categoryId);
                            if (!categorized[categoryId]) {
                                categorized[categoryId] = { title: categoryName, items: [] };
                            }
                            categorized[categoryId].items.push({
                                name: getLocalizedText(fallbackFantasy.label, String(fantasyId)),
                            });
                        }
                    }
                }
            });
        }

        return categorized;
    };

    const attributesData = USER_ATTRIBUTES.map((attr: any) => {
        const resolved = getAttributeValue(attr);
        return {
            ...attr,
            label: fieldLabels[attr.field] || attr.label,
            description: fieldDescriptions[attr.field] || '',
            value: resolved.value,
            hasValue: resolved.hasValue,
            selectedOptions: resolved.selectedOptions,
            allowMultiple: resolved.allowMultiple,
        };
    });

    const filledCount = attributesData.filter((a: any) => a.hasValue).length;
    const totalCount = USER_ATTRIBUTES.length;

    const categorizedInterests = getInterestsByCategory();
    const categorizedFantasies = getFantasiesByCategory();

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
                        const isMulti = item.allowMultiple && Array.isArray(item.selectedOptions) && item.selectedOptions.length > 1;
                        return (
                            <View
                                key={item.field}
                                style={[
                                    styles.attrRow,
                                    !isLast && { borderBottomWidth: 1, borderBottomColor: borderColor },
                                ]}
                            >  
                                <View style={styles.attrHeader}>
                                    <View style={[styles.iconContainer, { backgroundColor: dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.04)' }]}>  
                                        <MaterialCommunityIcons name={item.icon as any} size={22} color={textColor} />
                                    </View>
                                    <View style={styles.attrLabelStack}>
                                        <Text style={[styles.attrLabel, { color: textColor }]} numberOfLines={2}>{item.label}</Text>
                                        {!!item.description && (
                                            <Text style={[styles.attrHint, { color: secondaryText }]} numberOfLines={3}>{item.description}</Text>
                                        )}
                                    </View>
                                </View>
                                <View style={styles.attrValueBlock}>
                                    {isMulti ? (
                                        <View style={styles.attrValueWrap}>
                                            {item.selectedOptions.map((opt: string, optIndex: number) => (
                                                <View key={`${item.field}-opt-${optIndex}`} style={[styles.valueChip, { backgroundColor: dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.04)', borderColor }]}>
                                                    <Text style={[styles.valueChipText, { color: secondaryText }]} numberOfLines={2}>{opt}</Text>
                                                </View>
                                            ))}
                                        </View>
                                    ) : (
                                        <View style={styles.attrValueSingle}>
                                            {!item.value && <View style={styles.dot} />}
                                            {item.value ? (
                                                <View style={[styles.valuePill, { backgroundColor: dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.04)', borderColor }]}>
                                                    <Text style={[styles.valuePillText, { color: secondaryText }]} numberOfLines={2}>
                                                        {item.value}
                                                    </Text>
                                                </View>
                                            ) : (
                                                <Text style={[styles.attrValue, { color: dark ? '#FFD700' : '#B8860B' }]} numberOfLines={2}>
                                                    Select option
                                                </Text>
                                            )}
                                        </View>
                                    )}
                                </View>
                            </View>
                        );
                    })}
                </View>
            </View>

            {/* Fantasies Section */}
            <View style={styles.section}>
                <View style={styles.sectionHeader}>
                    <Text style={[styles.sectionTitle, { color: textColor }]}>Fantasies</Text>
                    <Text style={[styles.sectionCount, { color: secondaryText }]}>  
                        {Object.values(categorizedFantasies).reduce((acc, cat) => acc + cat.items.length, 0)}
                    </Text>
                </View>
                {Object.keys(categorizedFantasies).length > 0 ? (
                    Object.entries(categorizedFantasies).map(([slug, cat]) => (
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
                    ))
                ) : (
                    <View style={[styles.emptySection, { borderColor, backgroundColor: surfaceColor }]}>  
                        <View style={[styles.emptyIconWrap, { backgroundColor: dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.04)' }]}>  
                            <MaterialCommunityIcons name="star-four-points-outline" size={22} color={secondaryText} />
                        </View>
                        <Text style={[styles.emptySectionText, { color: secondaryText }]}>No fantasies added yet.</Text>
                    </View>
                )}
            </View>

            {/* Interests Section */}
            <View style={styles.section}>
                <View style={styles.sectionHeader}>
                    <Text style={[styles.sectionTitle, { color: textColor }]}>Interests</Text>
                    <Text style={[styles.sectionCount, { color: secondaryText }]}>  
                        {Object.values(categorizedInterests).reduce((acc, cat) => acc + cat.items.length, 0)}
                    </Text>
                </View>
                {Object.keys(categorizedInterests).length > 0 ? (
                    Object.entries(categorizedInterests).map(([id, cat]) => (
                        <View key={id} style={[styles.categoryCard, { borderColor, backgroundColor: surfaceColor }]}>  
                            <View style={[styles.categoryHeader, { borderBottomColor: borderColor }]}>  
                                <Text style={[styles.categoryTitle, { color: secondaryText }]}>{cat.title.toUpperCase()}</Text>
                            </View>
                            <View style={styles.tagGrid}>
                                {cat.items.map((item, idx) => (
                                    <View key={idx} style={[styles.tag, { backgroundColor: dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.04)', borderColor }]}>  
                                        <Text style={[styles.tagText, { color: textColor }]}>  
                                            {item.emoji && <Text style={{ fontSize: 16 }}>{item.emoji}</Text>} {item.name}
                                        </Text>
                                    </View>
                                ))}
                            </View>
                        </View>
                    ))
                ) : (
                    <View style={[styles.emptySection, { borderColor, backgroundColor: surfaceColor }]}>  
                        <View style={[styles.emptyIconWrap, { backgroundColor: dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.04)' }]}>  
                            <MaterialCommunityIcons name="heart-outline" size={22} color={secondaryText} />
                        </View>
                        <Text style={[styles.emptySectionText, { color: secondaryText }]}>No interests added yet.</Text>
                    </View>
                )}
            </View>
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
    attrRow: { paddingHorizontal: 16, paddingVertical: 14, rowGap: 10 },
    attrHeader: { flexDirection: 'row', alignItems: 'flex-start' },
    iconContainer: { width: 32, height: 32, borderRadius: 10, alignItems: 'center', justifyContent: 'center', marginRight: 12 },
    attrLabelStack: { flex: 1, minWidth: 0 },
    attrLabel: { fontSize: 15, fontFamily: 'Inter-Medium', flexShrink: 1 },
    attrHint: { fontSize: 11, fontFamily: 'Inter-Regular', marginTop: 4, lineHeight: 14 },
    attrValueBlock: { marginLeft: 44 },
    attrValueSingle: { flexDirection: 'row', alignItems: 'center', gap: 6 },
    attrValue: { fontSize: 12, fontFamily: 'Inter-Medium' },
    attrValueWrap: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
    valueChip: { paddingHorizontal: 10, paddingVertical: 6, borderRadius: 14, borderWidth: 1 },
    valueChipText: { fontSize: 12, fontFamily: 'Inter-Medium' },
    valuePill: { paddingHorizontal: 10, paddingVertical: 6, borderRadius: 14, borderWidth: 1, alignSelf: 'flex-start' },
    valuePillText: { fontSize: 12, fontFamily: 'Inter-SemiBold' },
    dot: { width: 6, height: 6, borderRadius: 3, backgroundColor: '#FFD700' },
    categoryCard: { borderRadius: 18, borderWidth: 1, overflow: 'hidden', marginBottom: 12 },
    categoryHeader: { paddingHorizontal: 16, paddingVertical: 10, borderBottomWidth: 1 },
    categoryTitle: { fontSize: 11, fontFamily: 'Inter-Bold', letterSpacing: 0.8 },
    tagGrid: { flexDirection: 'row', flexWrap: 'wrap', padding: 12, gap: 8 },
    tag: { paddingHorizontal: 12, paddingVertical: 8, borderRadius: 16, borderWidth: 1 },
    tagText: { fontSize: 13, fontFamily: 'Inter-Medium' },
    emptySection: { borderRadius: 18, borderWidth: 1, paddingVertical: 28, alignItems: 'center', gap: 8 },
    emptyIconWrap: { width: 40, height: 40, borderRadius: 20, alignItems: 'center', justifyContent: 'center' },
    emptySectionText: { fontSize: 14, fontFamily: 'Inter-Medium' },
});

export default ProfileAboutView;
