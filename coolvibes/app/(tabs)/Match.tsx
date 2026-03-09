import React, { useMemo, useState, memo, useCallback, useRef, useEffect } from 'react';
import { View, Text, StyleSheet, Pressable, Dimensions, Image, ActivityIndicator, TouchableOpacity, Platform } from 'react-native';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  interpolate,
  Extrapolation,
  withSpring,
  withTiming,
} from 'react-native-reanimated';
import { runOnJS } from 'react-native-reanimated';
import { Gesture, GestureDetector, GestureHandlerRootView } from 'react-native-gesture-handler';
import * as Haptics from 'expo-haptics';
import { useTheme } from '@react-navigation/native';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import UserCard from '@/components/UserCard';

// --- DUMMY DATA ---
const ZODIACS = ['Aries', 'Taurus', 'Gemini', 'Cancer', 'Leo', 'Virgo', 'Libra', 'Scorpio', 'Sagittarius', 'Capricorn', 'Aquarius', 'Pisces'];
const EDUCATIONS = ['High School', 'Bachelors', 'Masters', 'PhD'];
const PERSONALITIES = ['INTJ', 'INTP', 'ENTJ', 'ENTP', 'INFJ', 'INFP', 'ENFJ', 'ENFP', 'ISTJ', 'ISFJ', 'ESTJ', 'ESFJ', 'ISTP', 'ISFP', 'ESTP', 'ESFP'];
const INTERESTS = [
    {id: '1', name: 'Photography', emoji: '📷'}, {id: '2', name: 'Gaming', emoji: '🎮'}, {id: '3', name: 'Traveling', emoji: '✈️'},
    {id: '4', name: 'Cooking', emoji: '🍳'}, {id: '5', name: 'Reading', emoji: '📚'}, {id: '6', name: 'Hiking', emoji: '🥾'},
];

const createUsers = (count: number, offset = 0) => Array.from({ length: count }).map((_, i) => {
    const userIndex = offset + i;
    return {
        id: userIndex,
        name: `User ${userIndex}`,
        age: Math.floor(Math.random() * 15) + 18,
        imageUrl: `https://picsum.photos/id/${userIndex + 100}/400/400`,
        distance: (Math.random() * 15).toFixed(1),
        about: `Just a dummy bio for user ${userIndex}. I enjoy long walks on the virtual beach and coding under the moonlight.`,
        zodiac_sign: ZODIACS[userIndex % ZODIACS.length],
        education: EDUCATIONS[userIndex % EDUCATIONS.length],
        personality: PERSONALITIES[userIndex % PERSONALITIES.length],
        interests: INTERESTS.slice(i % 3, i % 3 + 3),
    }
});


// --- CONFIGURATION & DIMENSIONS ---
const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');
const HEX_SIZE = 100;
const RADAR_HEIGHT = SCREEN_HEIGHT;
const CENTER_X = SCREEN_WIDTH / 2;
const CENTER_Y = RADAR_HEIGHT / 2;
const ITEM_DIM = 140;
const OFFSET = ITEM_DIM / 2;


const axialToPixel = (q: number, r: number) => {
  'worklet';
  return {
    x: HEX_SIZE * (Math.sqrt(3) * q + (Math.sqrt(3) / 2) * r),
    y: HEX_SIZE * (1.5 * r),
  };
};


const HexItem = memo(({ item, panX, panY, onSelect }: any) => {
  const { colors } = useTheme();
  const { user, q, r } = item;
  const { x, y } = axialToPixel(q, r);

  const style = useAnimatedStyle(() => {
    'worklet';
    const itemX = x + panX.value + CENTER_X;
    const itemY = y + panY.value + CENTER_Y;

    // Culling logic: check if the item is within the screen bounds + a buffer
    const isVisible = 
        itemX > -ITEM_DIM && 
        itemX < SCREEN_WIDTH + ITEM_DIM &&
        itemY > -ITEM_DIM &&
        itemY < SCREEN_HEIGHT + ITEM_DIM;

    if (!isVisible) {
        return { display: 'none' };
    }

    const px = x + panX.value;
    const py = y + panY.value;
    const dist = Math.sqrt(px * px + py * py);

    const scale = interpolate(dist, [0, 100, 450], [1.8, 1.0, 0.4], Extrapolation.CLAMP);
    const opacity = interpolate(dist, [0, 220, 500], [1, 0.9, 0.05], Extrapolation.CLAMP);

    return {
      display: 'flex',
      transform: [
        { translateX: px + CENTER_X - OFFSET },
        { translateY: py + CENTER_Y - OFFSET },
        { scale: withSpring(scale, { damping: 20, stiffness: 100 }) }
      ] as any,
      opacity,
      zIndex: Math.round(1000 - dist),
    };
  });

  return (
    <Animated.View style={[styles.hexWrap, style]}>
      <Pressable
        onPress={() => onSelect(user, x, y)}
        style={({ pressed }) => [
          styles.hexBtn,
          { backgroundColor: colors.card, borderColor: colors.border },
          pressed && styles.pressedBtn
        ]}
      >
        <Image source={{ uri: user.imageUrl }} style={styles.bubbleImage} />
        {/* Active dot */}
        <View style={styles.activeDot} />
      </Pressable>
    </Animated.View>
  );
});

const spiralDirections = [
    { q: 1, r: 0 }, { q: 1, r: -1 }, { q: 0, r: -1 },
    { q: -1, r: 0 }, { q: -1, r: 1 }, { q: 0, r: 1 },
];

function* spiralCoordGenerator() {
    yield { q: 0, r: 0 };
    let radius = 1;
    while (true) {
        let q = spiralDirections[4].q * radius;
        let r = spiralDirections[4].r * radius;
        for (let side = 0; side < 6; side++) {
            for (let step = 0; step < radius; step++) {
                yield { q, r };
                q += spiralDirections[side].q;
                r += spiralDirections[side].r;
            }
        }
        radius++;
    }
}

export default function MatchScreen() {
    const { colors, dark } = useTheme();
    const insets = useSafeAreaInsets();
    const [selectedUser, setSelectedUser] = useState<any>(null);
    
    // Pulse animation for radar
    const pulse = useSharedValue(1);
    useEffect(() => {
        const runPulse = () => {
            pulse.value = withTiming(1.6, { duration: 2500 }, () => {
                pulse.value = 1;
            });
        };
        runPulse();
        const interval = setInterval(runPulse, 3000);
        return () => clearInterval(interval);
    }, []);

    const pulseStyle = useAnimatedStyle(() => ({
        transform: [{ scale: pulse.value }],
        opacity: interpolate(pulse.value, [1, 1.6], [0.4, 0]),
    }));

    const coordGenerator = useRef(spiralCoordGenerator());
    const [honeycomb, setHoneycomb] = useState(() => {
        const initialUsers = createUsers(30);
        return initialUsers.map(user => {
            const coords = coordGenerator.current.next().value;
            return { user, ...coords, id: `hex-${user.id}` };
        });
    });

    const [isLoading, setIsLoading] = useState(false);

    const panX = useSharedValue(0);
    const panY = useSharedValue(0);
    const startX = useSharedValue(0);
    const startY = useSharedValue(0);
    const gridBounds = useSharedValue({ minX: 0, maxX: 0, minY: 0, maxY: 0 });
    const canvasScale = useSharedValue(1);

    useMemo(() => {
        if (honeycomb.length === 0) {
            gridBounds.value = { minX: 0, maxX: 0, minY: 0, maxY: 0 };
            return;
        };
        let minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity;
        honeycomb.forEach((item: any) => {
            const p = axialToPixel(item.q, item.r);
            minX = Math.min(minX, p.x);
            maxX = Math.max(maxX, p.x);
            minY = Math.min(minY, p.y);
            maxY = Math.max(maxY, p.y);
        });
        gridBounds.value = { minX, maxX, minY, maxY };
    }, [honeycomb]);

    const loadMore = useCallback(() => {
        if (isLoading) return;
        setIsLoading(true);

        setTimeout(() => {
            const newUsers = createUsers(20, honeycomb.length);
            const newItems = newUsers.map(user => {
                const coords = coordGenerator.current.next().value;
                return { user, ...coords, id: `hex-${user.id}` };
            });
            setHoneycomb(prev => [...prev, ...newItems]);
            setIsLoading(false);
        }, 1500);
    }, [isLoading, honeycomb.length]);

    const handleItemPress = (user: any, x: number, y: number) => {
        panX.value = withSpring(-x, { damping: 18, stiffness: 100 });
        panY.value = withSpring(-y, { damping: 18, stiffness: 100 });
        Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
        setSelectedUser(user);
    };

    const panGesture = Gesture.Pan()
        .onBegin(() => {
            startX.value = panX.value;
            startY.value = panY.value;
        })
        .onUpdate(e => {
            panX.value = startX.value + e.translationX;
            panY.value = startY.value + e.translationY;
        })
        .onEnd((e) => {
            'worklet';
            const predictedX = panX.value + e.velocityX * 0.12;
            const predictedY = panY.value + e.velocityY * 0.12;
            
            let minDist = Infinity;
            let targetX = 0;
            let targetY = 0;

            for (let i = 0; i < honeycomb.length; i++) {
                const h = honeycomb[i] as any;
                const p = axialToPixel(h.q, h.r);
                const px = p.x + predictedX;
                const py = p.y + predictedY;
                const d = px * px + py * py;
                if (d < minDist) {
                    minDist = d;
                    targetX = p.x;
                    targetY = p.y;
                }
            }
            panX.value = withSpring(-targetX, { damping: 18, stiffness: 90, velocity: e.velocityX });
            panY.value = withSpring(-targetY, { damping: 18, stiffness: 90, velocity: e.velocityY });
            
            const finalPanX = -targetX;
            const finalPanY = -targetY;
            
            const THRESHOLD = 200;
            const viewMaxX = -finalPanX + SCREEN_WIDTH / 2;
            const viewMinX = -finalPanX - SCREEN_WIDTH / 2;
            const viewMaxY = -finalPanY + SCREEN_HEIGHT / 2;
            const viewMinY = -finalPanY - SCREEN_HEIGHT / 2;

            if (
                viewMaxX >= gridBounds.value.maxX - THRESHOLD || 
                viewMinX <= gridBounds.value.minX + THRESHOLD ||
                viewMaxY >= gridBounds.value.maxY - THRESHOLD ||
                viewMinY <= gridBounds.value.minY + THRESHOLD
            ) {
                runOnJS(loadMore)();
            }
        });
        
    const longPressGesture = Gesture.LongPress()
        .minDuration(200)
        .onStart(() => {
            canvasScale.value = withSpring(0.5, { damping: 20, stiffness: 150 });
        })
        .onEnd(() => {
            canvasScale.value = withSpring(1);
        })
        .onFinalize(() => {
            canvasScale.value = withSpring(1);
        });

    const composedGesture = Gesture.Simultaneous(panGesture, longPressGesture);
    
    const animatedCanvasStyle = useAnimatedStyle(() => ({
        transform: [{ scale: canvasScale.value }]
    }));

    const handleDismissCard = (userToRemove: any) => {
        setSelectedUser(null);
        setHoneycomb(prev => prev.filter(item => item.user.id !== userToRemove.id));
    };

    const bottomBarHeight = Platform.OS === 'ios' ? 88 : 68;
    const headerHeight = 60 + insets.top;

    return (
        <GestureHandlerRootView style={{ flex: 1 }}>
            <View style={[styles.screen, { backgroundColor: colors.background, paddingTop: insets.top, paddingBottom: bottomBarHeight }]}>
                <View style={styles.radarWrapper}>
                    {/* Stealth HUD - Only functional icons below GlobalHeader */}
                    <View style={styles.radarHud}>
                        <TouchableOpacity style={{ opacity: 0.6 }}>
                           <MaterialCommunityIcons name="tune-vertical" size={24} color={colors.text} />
                        </TouchableOpacity>
                        <View style={{ flex: 1 }} />
                        <View style={{ opacity: 0.6 }}>
                            {isLoading ? <ActivityIndicator size="small" color={colors.text} /> : (
                               <MaterialCommunityIcons name="radar" size={24} color={colors.text} />
                            )}
                        </View>
                    </View>

                    <GestureDetector gesture={composedGesture}>
                        <Animated.View style={[styles.radarViewport, animatedCanvasStyle]}>
                            {/* Radar Grid Circles */}
                            <Animated.View style={[styles.pulseRing, { width: 400, height: 400, left: CENTER_X - 200, top: CENTER_Y - 200, borderColor: colors.text }, pulseStyle]} pointerEvents="none" />
                            
                            <View style={[styles.radarRing, { width: 240, height: 240, left: CENTER_X - 120, top: CENTER_Y - 120 }]} pointerEvents="none" />
                            <View style={[styles.radarRing, { width: 480, height: 480, left: CENTER_X - 240, top: CENTER_Y - 240 }]} pointerEvents="none" />
                            <View style={[styles.radarRing, { width: 720, height: 720, left: CENTER_X - 360, top: CENTER_Y - 360, opacity: 0.05 }]} pointerEvents="none" />

                            {honeycomb.map((item) => (
                                <HexItem
                                    key={item.id}
                                    item={item}
                                    panX={panX}
                                    panY={panY}
                                    onSelect={handleItemPress}
                                />
                            ))}

                            {/* Fixed Crosshair (Magnet Point) */}
                            <View style={[styles.crosshairContainer, { left: CENTER_X - 170, top: CENTER_Y - 170 }]} pointerEvents="none">
                                <View style={[styles.crossLineV, { backgroundColor: colors.text, opacity: 0.1 }]} />
                                <View style={[styles.crossLineH, { backgroundColor: colors.text, opacity: 0.1 }]} />
                                <View style={[styles.centerPulse, { borderColor: colors.text, opacity: 0.03 }]} />
                            </View>
                        </Animated.View>
                    </GestureDetector>
                </View>

                {selectedUser && <UserCard user={selectedUser} onDismiss={handleDismissCard} />}
            </View>
        </GestureHandlerRootView>
    );
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  radarWrapper: { flex: 1, position: 'relative' },
  radarHud: { 
    position: 'absolute',
    width: '100%', 
    flexDirection: 'row',
    alignItems: 'center',
    zIndex: 10, 
    paddingHorizontal: 25,
    paddingVertical: 10 
  },
  hudLabel: { fontSize: 9, fontFamily: 'Inter-Bold', letterSpacing: 2, marginTop: 2 },
  hudTitle: { fontSize: 28, fontFamily: 'Outfit-Black', letterSpacing: -1 },
  radarViewport: { position:"relative", flex: 1, justifyContent: 'center', alignItems: 'center' },
  hexWrap: { position: 'absolute', left: 0, top: 0, width: ITEM_DIM, height: ITEM_DIM, alignItems: 'center', justifyContent: 'center' },
  hexBtn: {
    width: 90, height: 90, borderRadius: 45, 
    alignItems: 'center', justifyContent: 'center', borderWidth: 2,
    shadowColor: "#000", shadowOpacity: 0.1, shadowRadius: 10, elevation: 5
  },
  pressedBtn: { transform: [{ scale: 0.9 }], opacity: 0.8 },
  bubbleImage: {
    width: 82,
    height: 82,
    borderRadius: 41,
  },
  activeDot: {
    position: 'absolute',
    bottom: 5,
    right: 5,
    width: 14,
    height: 14,
    borderRadius: 7,
    backgroundColor: '#34C759', // High-end active green
    borderWidth: 2,
    borderColor: '#FFF',
  },
  crosshairContainer: { position: 'absolute', width: 340, height: 340, alignItems: 'center', justifyContent: 'center' },
  crossLineV: { position: 'absolute', width: 1, height: 60 },
  crossLineH: { position: 'absolute', width: 60, height: 1 },
  centerPulse: { width: 320, height: 320, borderRadius: 160, borderWidth: 1 },
  radarRing: { position: 'absolute', borderRadius: 999, borderWidth: 1, borderColor: 'rgba(127,127,127,0.1)' },
  pulseRing: { position: 'absolute', borderRadius: 999, borderWidth: 2 },
});