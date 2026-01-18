import { LocalizedStringToString } from '@/utils/utils';
import MaterialCommunityIcons from '@expo/vector-icons/MaterialCommunityIcons';
import React, { useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Pressable, Linking, Platform, ImageBackground } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { getRankGradient } from '@/utils/colors';
import Animated, { useSharedValue, useAnimatedStyle, withSpring } from 'react-native-reanimated';
import { useNavigation } from '@react-navigation/native';

type RankAvatarProps = {
    tag: string;
    size?: number;
    label?: string;
};

// RankAvatar remains a key visual element, representing status or category.
export const RankAvatar: React.FC<RankAvatarProps> = ({
    tag,
    size = 36,
    label,
}) => {
    const gradient = getRankGradient(tag);
    return (
        <LinearGradient
            colors={gradient.colors}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 1 }}
            style={{
                width: size,
                height: size,
                borderRadius: size / 2,
                alignItems: 'center',
                justifyContent: 'center',
                overflow: 'hidden',
                borderWidth: 2,
                borderColor: 'rgba(255, 255, 255, 0.2)',
            }}>
            <Text
                style={{
                    color: gradient.textColor,
                    fontSize: size * 0.5,
                    fontWeight: '800',
                }}
                numberOfLines={1}
            >
                {tag.charAt(0).toUpperCase()}
            </Text>
        </LinearGradient>
    );
};



const AnimatedEngagementButton: React.FC<{iconEnabled: string , iconDisabled:string, initialCount: number, engagementType:string }> = ({iconEnabled,iconDisabled, initialCount, engagementType}) => {
    const [isLiked, setIsLiked] = useState(false);
    const [count, setCount] = useState(initialCount);
    const scale = useSharedValue(1);

    const animatedIconStyle = useAnimatedStyle(() => ({
        transform: [{ scale: scale.value }]
    }));

    const handlePress = (e: any) => {
        e.stopPropagation();
        scale.value = withSpring(1.25, { damping: 2, stiffness: 100 }, () => {
            scale.value = withSpring(1);
        });

        setIsLiked(prev => {
            setCount(prev ? count - 1 : count + 1);
            return !prev;
        });
    }

    const iconColor = isLiked ? '#EF4444' : '#6B7280';

    return (
        <Pressable onPress={handlePress} style={styles.action}>
            <Animated.View style={animatedIconStyle}>
                <MaterialCommunityIcons 
                    name={isLiked ? iconEnabled as any : iconDisabled as any} 
                    size={24} 
                    color={iconColor}
                />
            </Animated.View>
            <Text style={[styles.actionText, { color: iconColor }]}>
                {count}
            </Text>
        </Pressable>
    )
}

// The main PlaceItem component, designed for a flat, efficient, and clean list aesthetic.
export const PlaceItem: React.FC<{ item: any }> = ({ item }) => {
    const navigation = useNavigation<any>();
    const isPressed = useSharedValue(false);

    // Press-in animation for tactile feedback.
    const animatedCardStyle = useAnimatedStyle(() => {
        return {
            backgroundColor: isPressed.value ? '#F9FAFB' : 'white',
            transform: [{ scale: withSpring(isPressed.value ? 0.995 : 1) }],
        };
    });

    // Stops event propagation to parent Pressable.
    const stopPropagation = (e: any) => e.stopPropagation();

    // Opens maps for directions.
    const handleGetDirections = (e: any) => {
        e.stopPropagation();
        const { address, town, country } = item.extras.place;
        const fullAddress = `${address}, ${town}, ${country}`;
        const scheme = Platform.OS === 'ios' ? 'maps:0,0?q=' : 'geo:0,0?q=';
        const url = scheme + encodeURIComponent(fullAddress);
        Linking.openURL(url);
    };

    // Navigates to the detail screen.
    const handleNavigate = () => {
        navigation.navigate('PlaceDetail', { item: item });
    };
 
    const title = LocalizedStringToString(item.title);

    return (
        <Pressable
            onPress={handleNavigate}
            onPressIn={() => isPressed.value = true}
            onPressOut={() => isPressed.value = false}
        >
            <Animated.View style={[styles.container, animatedCardStyle]}>
                {/* --- HEADER --- */}
                <View style={styles.headerContainer}>
                    <RankAvatar tag={item?.extras?.place?.tag || title} size={48} />
                    <View style={styles.headerTextContainer}>
                        <View style={styles.titleLine}>
                            <Text style={styles.name} numberOfLines={1}>{title}</Text>
                            {item.extras.place.tag && (
                                <View style={styles.tagContainer}>
                                    <Text style={styles.tagText}>{item.extras.place.tag}</Text>
                                </View>
                            )}
                        </View>
                        <View style={{flex:1,paddingVertical:10,flexDirection:"row",gap:2}}>
                        
                            <MaterialCommunityIcons name="map-marker-outline" size={20} color="#6B7280" />
                            <Text style={styles.addressText}>
                           {item.extras.place.address}, {item.extras.place.town}, {item.extras.place.country}
                        </Text>
                        </View>
                    </View>
                </View>

                {(item.note || item.image) && (
                    <View style={styles.bodyContainer}>
                        {item.note && (
                            <Text style={styles.noteText}>{item.note}</Text>
                        )}
                        {item.image && (
                            <ImageBackground source={{ uri: item.image }} style={styles.image} imageStyle={{ borderRadius: 8 }} />
                        )}
                    </View>
                )}

                <View style={styles.footerContainer}>
                    <View style={styles.socialActions}>
                        <AnimatedEngagementButton initialCount={0} iconEnabled='cards-heart' iconDisabled='cards-heart-outline' engagementType='like'/>
                        <AnimatedEngagementButton initialCount={0} iconEnabled='heart-broken' iconDisabled='heart-broken-outline' engagementType='dislike'/>

                       
                        <TouchableOpacity style={styles.action} onPress={stopPropagation}>
                            <MaterialCommunityIcons name="share-variant-outline" size={24} color="#6B7280" />
                        </TouchableOpacity>
                    </View>
                    <TouchableOpacity style={styles.directionsButton} onPress={handleGetDirections}>
                        <MaterialCommunityIcons name="directions" size={18} color="white" />
                        <Text style={styles.directionsButtonText}>Yol Tarifi</Text>
                    </TouchableOpacity>
                </View>
            </Animated.View>
        </Pressable>
    );
};

// Styles optimized for a dense, screen-efficient, and flat "list-item" appearance.
const styles = StyleSheet.create({
    container: {
        paddingHorizontal: 16,
        paddingVertical: 14,
        borderBottomWidth: 1,
        borderBottomColor: '#F3F4F6', // Soft bottom line
    },
    headerContainer: {
        flexDirection: 'row',
        alignItems: 'center',
        gap: 14,
    },
    headerTextContainer: {
        flex: 1,
    },
    titleLine: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
        marginBottom: 4,
    },
    name: {
        fontSize: 17,
        fontWeight: '600',
        color: '#111827',
        flexShrink: 1,
    },
    tagContainer: {
        backgroundColor: '#F3F4F6',
        borderRadius: 12,
        paddingHorizontal: 8,
        paddingVertical: 3,
        marginLeft: 8,
    },
    tagText: {
        fontSize: 11,
        fontWeight: '500',
        color: '#4B5563',
    },
    addressText: {
        flex:1,
        flexWrap:"wrap",
        fontSize: 16,
        color: '#6B7280',
        lineHeight: 18,
    },
    bodyContainer: {
        paddingTop: 12,
    },
    noteText: {
        fontSize: 14.5,
        color: '#374151',
        lineHeight: 21,
        marginBottom: 10,
    },
    image: {
        width: '100%',
        height: 200,
        borderRadius: 8,
        backgroundColor: '#F9FAFB',
    },
    footerContainer: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
        paddingTop: 12,
    },
    socialActions: {
        flexDirection: 'row',
        alignItems: 'center',
        gap: 20,
    },
    action: {
        flexDirection: 'row',
        alignItems: 'center',
        gap: 5,
    },
    actionText: {
        fontSize: 14,
        fontWeight: '500',
        color: '#6B7280',
    },
    directionsButton: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'center',
        backgroundColor: '#000',
        borderRadius: 8,
        paddingVertical: 8,
        paddingHorizontal: 12,
        gap: 6,
    },
    directionsButtonText: {
        color: 'white',
        fontWeight: '500',
        fontSize: 14,
    },
});