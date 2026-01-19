import React, { useState, useCallback } from 'react';
import { View, Text, StyleSheet, Dimensions, Image, Pressable, ScrollView, Platform } from 'react-native';
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
import LikeIcon from '../Icons/LikeIcon';
import DislikeIcon from '../Icons/DislikeIcon';
import ChatIcon from '../Icons/ChatIcon';
import CloseIcon from '../Icons/CloseIcon';
import ProfileAboutView from '../ProfileAboutView';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');
const CARD_DIAMETER = SCREEN_WIDTH * 0.75;
const ACTION_BUTTON_SIZE = 65;
const EXPANDED_AVATAR_SIZE = 100;
const NAME_AGE_HEIGHT_ESTIMATE = 60; // Estimated height for name and age texts (e.g., 28 + 18 + ~14 padding)

const AnimatedBlurView = Animated.createAnimatedComponent(BlurView);

const UserCard = ({ user, onDismiss }: any) => {
    const { colors } = useTheme();
    const insets = useSafeAreaInsets();
    const [isExpanded, setIsExpanded] = useState(false);
    const animationProgress = useSharedValue(0);

    const handleToggleExpand = useCallback(() => {
        const toValue = isExpanded ? 0 : 1;
        animationProgress.value = withSpring(toValue, { damping: 20, stiffness: 120 });
        setIsExpanded(!isExpanded);
    }, [isExpanded, animationProgress]);

    const handleAction = (action: 'like' | 'dislike') => {
        // Here, you might want a different animation before dismissing
        console.log(`User ${user.id} was ${action}d`);
        onDismiss(user);
    };

    const handleClose = () => {
      
        onDismiss(user)
    };

    const handleDismiss = () => {
        // First, animate the card closed
        animationProgress.value = withSpring(0, { damping: 20, stiffness: 120 }, (isFinished) => {
            if (isFinished) {
                // Then, once the animation is complete, call onDismiss
                runOnJS(onDismiss)(user);
            }
        });
    };

    const animatedBlurStyle = useAnimatedStyle(() => ({
        intensity: interpolate(animationProgress.value, [0, 1], [0, Platform.OS === 'ios' ? 80 : 95]),
        opacity: interpolate(animationProgress.value, [0, 1], [0, 1]), // Opacity interpolates throughout the full animation
    }));

    const animatedImageContainerStyle = useAnimatedStyle(() => ({
        transform: [{ translateY: interpolate(animationProgress.value, [0, 1], [SCREEN_HEIGHT / 2 - (CARD_DIAMETER / 2) - 80, insets.top + 20]) }],
    }));
    
    const animatedImageStyle = useAnimatedStyle(() => ({
        width: interpolate(animationProgress.value, [0, 1], [CARD_DIAMETER, EXPANDED_AVATAR_SIZE]),
        height: interpolate(animationProgress.value, [0, 1], [CARD_DIAMETER, EXPANDED_AVATAR_SIZE]),
        borderRadius: interpolate(animationProgress.value, [0, 1], [CARD_DIAMETER / 2, EXPANDED_AVATAR_SIZE / 2]),
    }));

    const animatedOverlayStyle = useAnimatedStyle(() => ({
        opacity: interpolate(animationProgress.value, [0, 0.3], [1, 0]),
    }));

    const animatedDetailsStyle = useAnimatedStyle(() => ({
        opacity: interpolate(animationProgress.value, [0.5, 1], [0, 1]),
    }));


    
    const animatedCloseButtonStyle = useAnimatedStyle(() => ({
        opacity: interpolate(animationProgress.value, [0.8, 1], [0, 1]),
    }));

    const animatedNameAgePositionStyle = useAnimatedStyle(() => {
        const imageContainerTranslateY = interpolate(animationProgress.value, [0, 1], [SCREEN_HEIGHT / 2 - (CARD_DIAMETER / 2) - 80, insets.top + 20]);
        const imageHeight = interpolate(animationProgress.value, [0, 1], [CARD_DIAMETER, EXPANDED_AVATAR_SIZE]);
        const nameAgeTop = imageContainerTranslateY + imageHeight + 10; // 10 for spacing

        return {
            position: 'absolute',
            top: nameAgeTop,
            width: '100%',
            alignItems: 'center',
            zIndex: 25,
        };
    });

    const animatedActionsPositionStyle = useAnimatedStyle(() => {
        const imageContainerTranslateY = interpolate(animationProgress.value, [0, 1], [SCREEN_HEIGHT / 2 - (CARD_DIAMETER / 2) - 80, insets.top + 20]);
        const imageHeight = interpolate(animationProgress.value, [0, 1], [CARD_DIAMETER, EXPANDED_AVATAR_SIZE]);
        const nameAgeTop = imageContainerTranslateY + imageHeight + 10; // 10 for spacing
        const actionsTop = nameAgeTop + NAME_AGE_HEIGHT_ESTIMATE + 20; // 20 for some spacing

        return {
            position: 'absolute',
            top: actionsTop,
            width: '100%',
            flexDirection: 'row',
            justifyContent: 'space-evenly',
            alignItems: 'center',
            zIndex: 20, // Ensure it's above other elements if needed
        };
    });

    return (
        <View style={styles.wrapper} pointerEvents="auto">
            <AnimatedBlurView style={[StyleSheet.absoluteFill, { opacity: 1, backgroundColor: 'rgba(255, 255, 255, 0.14)' }]} tint="light" />
            
            <Animated.View style={[styles.detailsContainer, animatedDetailsStyle]} pointerEvents={isExpanded ? 'auto' : 'none'}>
                <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={{paddingBottom: 150, paddingTop: insets.top + 20 + EXPANDED_AVATAR_SIZE + 10 + NAME_AGE_HEIGHT_ESTIMATE + 20 + ACTION_BUTTON_SIZE + 20}}>
                    <View style={styles.detailsHeader}>
                        {/* Name, age, and distance are now displayed outside the ScrollView */}
                    </View>
                    <ProfileAboutView user={user} />
                </ScrollView>
            </Animated.View>

            <Animated.View style={[styles.imageContainer, animatedImageContainerStyle]}>
                <Pressable onPress={handleToggleExpand}>
                    <Animated.Image source={{ uri: user.imageUrl }} style={[styles.cardImage, animatedImageStyle]} />
                    <Animated.View style={[styles.cardOverlay, animatedImageStyle, animatedOverlayStyle]} />
                </Pressable>
            </Animated.View>

            <Animated.View style={[animatedNameAgePositionStyle]}>
                <Text style={[styles.cardName, { color: colors.text }]}>{user.name}, {user.age}</Text>
                <Text style={[styles.cardDistance, { color: colors.text, opacity: 0.7 }]}>{user.distance} km away</Text>
            </Animated.View>

            <Animated.View style={[animatedActionsPositionStyle]} pointerEvents="auto">
                <Pressable style={styles.actionButton} onPress={() => handleAction('dislike')}>
                    <DislikeIcon size={30} color="#F44336" />
                </Pressable>
                <Pressable style={styles.actionButton}>
                    <ChatIcon size={28} color="#2196F3" />
                </Pressable>
                <Pressable style={styles.actionButton} onPress={() => handleAction('like')}>
                    <LikeIcon size={30} color="#4CAF50" />
                </Pressable>
            </Animated.View>

            <Animated.View style={[styles.closeButtonContainer, { top: insets.top + 10, right: 20 }, animatedCloseButtonStyle]} pointerEvents={isExpanded ? 'auto' : 'none'}>
                <Pressable onPress={handleClose} style={styles.closeButton}>
                    <CloseIcon size={20} color="white" />
                </Pressable>
            </Animated.View>
         
        </View>
    );
};

const styles = StyleSheet.create({
    wrapper: { ...StyleSheet.absoluteFillObject, zIndex: 10 },
    imageContainer: { position: 'absolute', width: '100%', alignItems: 'center' },
    cardImage: { backgroundColor: '#ccc' },
    cardOverlay: {
        position: 'absolute',
        justifyContent: 'flex-end',
        alignItems: 'center',
        paddingBottom: 30,
        backgroundColor: 'rgba(0,0,0,0.3)',
    },
    overlayName: { fontSize: 28, fontWeight: 'bold', color: 'white', textShadowColor: 'rgba(0, 0, 0, 0.75)', textShadowOffset: {width: -1, height: 1}, textShadowRadius: 10 },
    overlayDistance: { fontSize: 18, color: 'white', textShadowColor: 'rgba(0, 0, 0, 0.75)', textShadowOffset: {width: -1, height: 1}, textShadowRadius: 10 },
    detailsContainer: { ...StyleSheet.absoluteFillObject, backgroundColor: 'transparent' },
    detailsHeader: { alignItems: 'center', paddingBottom: 20 },
    cardName: { fontSize: 28, fontWeight: 'bold' },
    cardDistance: { fontSize: 18 },

    actionButton: {
        width: ACTION_BUTTON_SIZE,
        height: ACTION_BUTTON_SIZE,
        borderRadius: ACTION_BUTTON_SIZE / 2,
        backgroundColor: 'white',
        justifyContent: 'center',
        alignItems: 'center',
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 4 },
        shadowOpacity: 0.15,
        shadowRadius: 8,
        elevation: 8,
    },
    closeButtonContainer: { position: 'absolute', zIndex: 30 },
    closeButton: {
        width: 40,
        height: 40,
        borderRadius: 20,
        justifyContent: 'center',
        alignItems: 'center',
        backgroundColor: 'rgba(0,0,0,0.3)',
    },
});

export default UserCard;
