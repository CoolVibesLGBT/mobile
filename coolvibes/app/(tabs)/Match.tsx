import React, { useMemo, useState, memo, useCallback, useRef } from 'react';
import { View, Text, StyleSheet, Pressable, Dimensions, Image, ActivityIndicator } from 'react-native';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  interpolate,
  Extrapolation,
  withSpring,
  withTiming,
} from 'react-native-reanimated';
import { runOnJS } from 'react-native-worklets';
import { Gesture, GestureDetector, GestureHandlerRootView } from 'react-native-gesture-handler';
import * as Haptics from 'expo-haptics';
import { useTheme } from '@react-navigation/native';
import UserCard from '../../components/UserCard';

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
        { scale: withSpring(scale, { damping: 20, stiffness: 90 }) }
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

export  default function Match() {
    const { colors } = useTheme();
    const insets = useSafeAreaInsets();
    const [selectedUser, setSelectedUser] = useState<any>(null);
    
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
        honeycomb.forEach(item => {
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
        console.log("Loading more users...");

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
                const h = honeycomb[i];
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

        console.log("CODER")
        // Find index from the current honeycomb state
        const currentIndex = honeycomb.findIndex(item => item.user.id === userToRemove.id);

        // This should not happen if everything is correct
        if (currentIndex === -1) { 
            console.warn("Dismissed user not found in honeycomb array.");
            // Fallback to original behavior
            setSelectedUser(null);
            setHoneycomb(prev => prev.filter(item => item.user.id !== userToRemove.id));
            return;
        }

        // Create the new array of users for the honeycomb
        const newHoneycomb = honeycomb.filter(item => item.user.id !== userToRemove.id);
        
        // Update the honeycomb state
        setHoneycomb(newHoneycomb);

         setSelectedUser(null);
    };

    return (
        <GestureHandlerRootView style={{ flex: 1 }}>
            <SafeAreaView style={[styles.screen, { backgroundColor: colors.background }]} edges={['bottom', 'left', 'right']}>
                <View style={styles.radarWrapper}>
                     <View style={[styles.radarHud, {top: insets.top}]}>
                        <View style={{flex: 1}} />
                        <View style={{alignItems: 'center'}}>
                            <Text style={[styles.hudTitle, {color: colors.text}]}>Discover</Text>
                            <Text style={[styles.hudLabel, {color: colors.text}]}>Find your match</Text>
                        </View>
                        <View style={{flex: 1, alignItems: 'flex-end'}}>
                            {isLoading && <ActivityIndicator size="small" color={colors.primary} />}
                        </View>
                    </View>

                    <GestureDetector gesture={composedGesture}>
                        <Animated.View style={[styles.radarViewport, animatedCanvasStyle]}>
                            {/* Radar Grid Circles */}
                            <View style={[styles.radarRing, { width: 200, height: 200, left: CENTER_X - 100, top: CENTER_Y - 100 }]} pointerEvents="none" />
                            <View style={[styles.radarRing, { width: 400, height: 400, left: CENTER_X - 200, top: CENTER_Y - 200 }]} pointerEvents="none" />
                            <View style={[styles.radarRing, { width: 600, height: 600, left: CENTER_X - 300, top: CENTER_Y - 300, opacity: 0.2 }]} pointerEvents="none" />

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
                                <View style={styles.crossLineV} />
                                <View style={styles.crossLineH} />
                                <View style={styles.centerPulse} />
                            </View>
                        </Animated.View>
                    </GestureDetector>
                </View>

                {selectedUser && <UserCard user={selectedUser} onDismiss={handleDismissCard} />}
            </SafeAreaView>
        </GestureHandlerRootView>
    );
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  radarWrapper: {flex:1, position: 'relative'},
  radarHud: { 
    position: 'absolute',
    width: '100%', 
    flexDirection: 'row',
    alignItems: 'center',
    zIndex: 10, 
    paddingHorizontal: 20,
    paddingVertical: 10 
  },
  hudLabel: { fontSize: 12, fontWeight: '700', opacity: 0.6, letterSpacing: 2 },
  hudTitle: { fontSize: 28, fontWeight: 'bold' },
  radarViewport: { position:"relative", flex: 1, justifyContent: 'center', alignItems: 'center', /* removed overflow: hidden */ },
  hexWrap: { position: 'absolute', left: 0, top: 0, width: ITEM_DIM, height: ITEM_DIM, alignItems: 'center', justifyContent: 'center' },
  hexBtn: {
    width: 96, height: 96, borderRadius: 48, 
    alignItems: 'center', justifyContent: 'center', borderWidth: 1.5,
    shadowColor: "#000", shadowOpacity: 0.1, shadowRadius: 12, elevation: 6
  },
  pressedBtn: { transform: [{ scale: 0.95 }], opacity: 0.8 },
  bubbleImage: {
    width: 90,
    height: 90,
    borderRadius: 45,
  },
  crosshairContainer: { position: 'absolute', width: 340, height: 340, alignItems: 'center', justifyContent: 'center' },
  crossLineV: { position: 'absolute', width: 2, height: 48, backgroundColor: 'rgba(225,29,72,0.2)' },
  crossLineH: { position: 'absolute', width: 48, height: 2, backgroundColor: 'rgba(225,29,72,0.2)' },
  centerPulse: { width: 300, height: 300, borderRadius: 150, borderWidth: 2, borderColor: 'rgba(225,29,72,0.04)' },
  radarRing: { position: 'absolute', borderRadius: 999, borderWidth: 1, borderColor: 'rgba(127,127,127,0.1)' },
});