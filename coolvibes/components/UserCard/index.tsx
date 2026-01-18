import React from 'react';
import { View, Text, StyleSheet, Dimensions, Image } from 'react-native';
import { useTheme } from '@react-navigation/native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  interpolate,
  Extrapolation,
  withSpring,
  withTiming,
} from 'react-native-reanimated';
import { runOnJS } from 'react-native-worklets';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

const UserCard = ({ user, onDismiss }: any) => {
    const { colors } = useTheme();
    const translateX = useSharedValue(0);
    const translateY = useSharedValue(0);

    const gesture = Gesture.Pan()
        .onUpdate((event) => {
            translateX.value = event.translationX;
            translateY.value = event.translationY;
        })
        .onEnd((event) => {
            if (Math.abs(event.translationX) > 100) {
                translateX.value = withTiming(event.translationX > 0 ? SCREEN_WIDTH : -SCREEN_WIDTH, { duration: 300 }, () => {
                    runOnJS(onDismiss)(user);
                });
            } else {
                translateX.value = withSpring(0);
                translateY.value = withSpring(0);
            }
        });

    const cardStyle = useAnimatedStyle(() => {
        const rotate = interpolate(translateX.value, [-SCREEN_WIDTH / 2, SCREEN_WIDTH / 2], [-15, 15], Extrapolation.CLAMP);
        return {
            transform: [
                { translateX: translateX.value },
                { translateY: translateY.value },
                { rotate: `${rotate}deg` },
            ],
        };
    });

    const likeOpacity = useAnimatedStyle(() => ({
        opacity: interpolate(translateX.value, [20, 80], [0, 1], Extrapolation.CLAMP),
    }));

    const nopeOpacity = useAnimatedStyle(() => ({
        opacity: interpolate(translateX.value, [-80, -20], [1, 0], Extrapolation.CLAMP),
    }));

    return (
        <View style={StyleSheet.absoluteFillObject} pointerEvents="box-none">
            <GestureDetector gesture={gesture}>
                <Animated.View style={[styles.card, { backgroundColor: colors.card }, cardStyle]}>
                    <Image source={{ uri: user.imageUrl }} style={styles.cardImage} />
                    <View style={styles.cardOverlay}>
                        <Text style={styles.cardName}>{user.name}, {user.age}</Text>
                        <Text style={styles.cardDistance}>{user.distance} km away</Text>
                    </View>
                    <Animated.View style={[styles.cardLabelContainer, { top: 30, left: 20, transform: [{ rotate: '-15deg' }] }, likeOpacity]}>
                        <Text style={[styles.cardLabel, { color: '#4CAF50', borderColor: '#4CAF50' }]}>LIKE</Text>
                    </Animated.View>
                    <Animated.View style={[styles.cardLabelContainer, { top: 30, right: 20, transform: [{ rotate: '15deg' }] }, nopeOpacity]}>
                        <Text style={[styles.cardLabel, { color: '#F44336', borderColor: '#F44336' }]}>NOPE</Text>
                    </Animated.View>
                </Animated.View>
            </GestureDetector>
        </View>
    );
};

const styles = StyleSheet.create({
   card: {
        position: 'absolute',
        width: SCREEN_WIDTH * 0.9,
        height: SCREEN_HEIGHT * 0.7,
        alignSelf: 'center',
        top: SCREEN_HEIGHT * 0.15,
        borderRadius: 20,
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 5 },
        shadowOpacity: 0.3,
        shadowRadius: 10,
        elevation: 10,
    },
    cardImage: {
        width: '100%',
        height: '100%',
        borderRadius: 20,
    },
    cardOverlay: {
        position: 'absolute',
        bottom: 0,
        left: 0,
        right: 0,
        padding: 20,
        backgroundColor: 'rgba(0,0,0,0.4)',
        borderBottomLeftRadius: 20,
        borderBottomRightRadius: 20,
    },
    cardName: {
        fontSize: 28,
        fontWeight: 'bold',
        color: 'white',
    },
    cardDistance: {
        fontSize: 18,
        color: 'white',
        opacity: 0.8,
    },
    cardLabelContainer: {
        position: 'absolute',
    },
    cardLabel: {
        fontSize: 32,
        fontWeight: 'bold',
        borderWidth: 2,
        padding: 8,
        borderRadius: 10,
        opacity: 0.8
    }
});

export default UserCard;
