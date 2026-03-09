import React, { useState, useCallback } from 'react';
import { View, Text, StyleSheet, Dimensions, Image, Pressable, ScrollView, Platform, TouchableOpacity } from 'react-native';
import { useTheme } from '@react-navigation/native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  interpolate,
  runOnJS,
} from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { BlurView } from 'expo-blur';
import * as Haptics from 'expo-haptics';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import ProfileAboutView from '../ProfileAboutView';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');
const CARD_DIAMETER = SCREEN_WIDTH * 0.8;
const ACTION_BUTTON_SIZE = 70;
const EXPANDED_AVATAR_SIZE = 110;
const NAME_AGE_HEIGHT_ESTIMATE = 70; 

const AnimatedBlurView = Animated.createAnimatedComponent(BlurView);

const UserCard = ({ user, onDismiss }: any) => {
    const { colors, dark } = useTheme();
    const insets = useSafeAreaInsets();
    const [isExpanded, setIsExpanded] = useState(false);
    const animationProgress = useSharedValue(0);

    const handleToggleExpand = useCallback(() => {
        const toValue = isExpanded ? 0 : 1;
        animationProgress.value = withSpring(toValue, { damping: 20, stiffness: 120 });
        setIsExpanded(!isExpanded);
        Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    }, [isExpanded, animationProgress]);

    const handleAction = (action: 'like' | 'dislike' | 'chat') => {
        Haptics.notificationAsync(
             action === 'like' ? Haptics.NotificationFeedbackType.Success : Haptics.NotificationFeedbackType.Warning
        );
        onDismiss(user);
    };

    const handleClose = () => {
        onDismiss(user);
    };

    const animatedBlurStyle = useAnimatedStyle(() => ({
        opacity: interpolate(animationProgress.value, [0, 0.5, 1], [0.8, 0.9, 1]),
    }));

    const animatedImageContainerStyle = useAnimatedStyle(() => ({
        transform: [{ translateY: interpolate(animationProgress.value, [0, 1], [SCREEN_HEIGHT / 2 - (CARD_DIAMETER / 2) - 60, insets.top + 20]) }],
    }));
    
    const animatedImageStyle = useAnimatedStyle(() => ({
        width: interpolate(animationProgress.value, [0, 1], [CARD_DIAMETER, EXPANDED_AVATAR_SIZE]),
        height: interpolate(animationProgress.value, [0, 1], [CARD_DIAMETER, EXPANDED_AVATAR_SIZE]),
        borderRadius: interpolate(animationProgress.value, [0, 1], [CARD_DIAMETER / 2, EXPANDED_AVATAR_SIZE / 2]),
        borderWidth: interpolate(animationProgress.value, [0, 1], [4, 2]),
    }));

    const animatedOverlayStyle = useAnimatedStyle(() => ({
        opacity: interpolate(animationProgress.value, [0, 0.3], [1, 0]),
    }));

    const animatedDetailsStyle = useAnimatedStyle(() => ({
        opacity: interpolate(animationProgress.value, [0.4, 1], [0, 1]),
    }));

    const animatedCloseButtonStyle = useAnimatedStyle(() => ({
        opacity: interpolate(animationProgress.value, [0.8, 1], [0, 1]),
    }));

    const animatedNameAgePositionStyle = useAnimatedStyle(() => {
        const imageContainerTranslateY = interpolate(animationProgress.value, [0, 1], [SCREEN_HEIGHT / 2 - (CARD_DIAMETER / 2) - 60, insets.top + 20]);
        const imageHeight = interpolate(animationProgress.value, [0, 1], [CARD_DIAMETER, EXPANDED_AVATAR_SIZE]);
        const nameAgeTop = imageContainerTranslateY + imageHeight + 15; 

        return {
            position: 'absolute',
            top: nameAgeTop,
            width: '100%',
            alignItems: 'center',
            zIndex: 25,
        };
    });

    const animatedActionsPositionStyle = useAnimatedStyle(() => {
        const imageContainerTranslateY = interpolate(animationProgress.value, [0, 1], [SCREEN_HEIGHT / 2 - (CARD_DIAMETER / 2) - 60, insets.top + 20]);
        const imageHeight = interpolate(animationProgress.value, [0, 1], [CARD_DIAMETER, EXPANDED_AVATAR_SIZE]);
        const nameAgeTop = imageContainerTranslateY + imageHeight + 15; 
        const actionsTop = nameAgeTop + NAME_AGE_HEIGHT_ESTIMATE + 25; 

        return {
            position: 'absolute',
            top: actionsTop,
            width: '100%',
            flexDirection: 'row',
            justifyContent: 'center',
            alignItems: 'center',
            gap: 20,
            zIndex: 20,
        };
    });

    const iconColor = dark ? '#FFFFFF' : '#000000';
    const premiumAccent = '#7C4DFF';

    return (
        <View style={styles.wrapper} pointerEvents="auto">
            <AnimatedBlurView 
              style={[StyleSheet.absoluteFill, { backgroundColor: dark ? 'rgba(0,0,0,0.8)' : 'rgba(255,255,255,0.9)' }, animatedBlurStyle]} 
              tint={dark ? 'dark' : 'light'} 
              intensity={Platform.OS === 'ios' ? 40 : 100}
            />
            
            <Animated.View style={[styles.detailsContainer, animatedDetailsStyle]} pointerEvents={isExpanded ? 'auto' : 'none'}>
                <ScrollView 
                    showsVerticalScrollIndicator={false} 
                    contentContainerStyle={{
                        paddingBottom: 150, 
                        paddingTop: insets.top + 40 + EXPANDED_AVATAR_SIZE + NAME_AGE_HEIGHT_ESTIMATE + ACTION_BUTTON_SIZE + 40
                    }}
                >
                    <ProfileAboutView user={user} />
                </ScrollView>
            </Animated.View>

            <Animated.View style={[styles.imageContainer, animatedImageContainerStyle]}>
                <Pressable
                    onPress={handleToggleExpand}
                    onPressIn={() => Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light)}
                    style={({ pressed }) => ({ opacity: pressed ? 0.9 : 1 })}
                >
                    <Animated.Image 
                        source={{ uri: user.imageUrl }} 
                        style={[styles.cardImage, { borderColor: dark ? '#222' : '#EEE' }, animatedImageStyle]} 
                    />
                    <Animated.View style={[styles.cardOverlay, animatedImageStyle, animatedOverlayStyle]} />
                    <View style={styles.premiumBadge}>
                        <MaterialCommunityIcons name="star" size={14} color="#FFF" />
                    </View>
                </Pressable>
            </Animated.View>

            <Animated.View style={[animatedNameAgePositionStyle]}>
                <Text style={[styles.cardName, { color: colors.text }]}>{user.name}, {user.age}</Text>
                <View style={styles.badgeRow}>
                    <View style={[styles.verifiedBadge, { backgroundColor: dark ? '#333' : '#EEE' }]}>
                        <MaterialCommunityIcons name="check-decagram" size={14} color={premiumAccent} />
                        <Text style={[styles.badgeText, { color: colors.text }]}>Verified</Text>
                    </View>
                    <Text style={[styles.cardDistance, { color: colors.text, opacity: 0.5 }]}>• {user.distance} km</Text>
                </View>
            </Animated.View>

            <Animated.View style={[animatedActionsPositionStyle]} pointerEvents="auto">
                <TouchableOpacity
                    style={[styles.actionButton, { backgroundColor: dark ? '#222' : '#F5F5F5' }]}
                    onPress={() => handleAction('dislike')}
                >
                    <MaterialCommunityIcons name="close" size={32} color="#FF3B30" />
                </TouchableOpacity>
                
                <TouchableOpacity
                    style={[styles.mainActionButton, { backgroundColor: iconColor }]}
                    onPress={() => handleAction('chat')}
                >
                    <MaterialCommunityIcons name="chat" size={30} color={dark ? '#000' : '#FFF'} />
                </TouchableOpacity>

                <TouchableOpacity
                    style={[styles.actionButton, { backgroundColor: dark ? '#222' : '#F5F5F5' }]}
                    onPress={() => handleAction('like')}
                >
                    <MaterialCommunityIcons name="heart" size={32} color="#34C759" />
                </TouchableOpacity>
            </Animated.View>

            <Animated.View style={[styles.closeButtonContainer, { top: insets.top + 15, right: 25 }, animatedCloseButtonStyle]} pointerEvents={isExpanded ? 'auto' : 'none'}>
                <TouchableOpacity onPress={handleClose} style={styles.closeButton}>
                    <MaterialCommunityIcons name="chevron-down" size={28} color={iconColor} />
                </TouchableOpacity>
            </Animated.View>
        </View>
    );
};

const styles = StyleSheet.create({
    wrapper: { ...StyleSheet.absoluteFillObject, zIndex: 1000 },
    imageContainer: { position: 'absolute', width: '100%', alignItems: 'center' },
    cardImage: { backgroundColor: '#333' },
    cardOverlay: { position: 'absolute', backgroundColor: 'rgba(0,0,0,0.05)' },
    premiumBadge: {
        position: 'absolute',
        top: 20,
        right: 20,
        backgroundColor: '#FFD700',
        padding: 6,
        borderRadius: 15,
        elevation: 5,
        shadowColor: '#000', shadowOpacity: 0.2, shadowRadius: 5,
    },
    detailsContainer: { ...StyleSheet.absoluteFillObject, backgroundColor: 'transparent' },
    cardName: { fontSize: 34, fontWeight: '900', letterSpacing: -1.5, marginBottom: 4 },
    badgeRow: { flexDirection: 'row', alignItems: 'center', gap: 8 },
    verifiedBadge: { 
        flexDirection: 'row', 
        alignItems: 'center', 
        gap: 4, 
        paddingHorizontal: 10, 
        paddingVertical: 4, 
        borderRadius: 12 
    },
    badgeText: { fontSize: 12, fontWeight: '800' },
    cardDistance: { fontSize: 14, fontWeight: '700' },
    actionButton: {
        width: ACTION_BUTTON_SIZE,
        height: ACTION_BUTTON_SIZE,
        borderRadius: ACTION_BUTTON_SIZE / 2,
        justifyContent: 'center',
        alignItems: 'center',
        elevation: 6,
        shadowColor: '#000', shadowOffset: { width: 0, height: 8 }, shadowOpacity: 0.1, shadowRadius: 15,
    },
    mainActionButton: {
        width: ACTION_BUTTON_SIZE + 10,
        height: ACTION_BUTTON_SIZE + 10,
        borderRadius: (ACTION_BUTTON_SIZE + 10) / 2,
        justifyContent: 'center',
        alignItems: 'center',
        elevation: 10,
        shadowColor: '#000', shadowOffset: { width: 0, height: 10 }, shadowOpacity: 0.2, shadowRadius: 20,
    },
    closeButtonContainer: { position: 'absolute', zIndex: 30 },
    closeButton: {
        width: 48,
        height: 48,
        borderRadius: 24,
        justifyContent: 'center',
        alignItems: 'center',
        backgroundColor: 'rgba(127,127,127,0.15)',
    },
});

export default UserCard;
