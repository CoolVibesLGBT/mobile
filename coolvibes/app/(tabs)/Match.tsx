import React, { useState, memo, useCallback, useRef, useEffect } from 'react';
import { View, Text, StyleSheet, Pressable, Dimensions, Image, ActivityIndicator, TouchableOpacity, Platform, LayoutChangeEvent } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  interpolate,
  Extrapolation,
  withSpring,
} from 'react-native-reanimated';
import { runOnJS } from 'react-native-reanimated';
import { Gesture, GestureDetector, GestureHandlerRootView } from 'react-native-gesture-handler';
import * as Haptics from 'expo-haptics';
import { useTheme } from '@react-navigation/native';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import UserCard from '@/components/UserCard';
import { LinearGradient } from 'expo-linear-gradient';
import { useRouter } from 'expo-router';
import * as Location from 'expo-location';
import { api } from '@/services/apiService';
import { calculateAge, getSafeImageURLEx } from '@/helpers/safeUrl';

const DEFAULT_COORDS = { lat: 41.0082, lng: 28.9784 };
// --- CONFIGURATION & DIMENSIONS ---
const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');
const HEX_SIZE = 100;
const RADAR_HEIGHT = SCREEN_HEIGHT;
const ITEM_DIM = 140;
const OFFSET = ITEM_DIM / 2;


const axialToPixel = (q: number, r: number) => {
  'worklet';
  return {
    x: HEX_SIZE * (Math.sqrt(3) * q + (Math.sqrt(3) / 2) * r),
    y: HEX_SIZE * (1.5 * r),
  };
};


const HexItem = memo(({ item, panX, panY, centerX, centerY, onSelect }: any) => {
  const { colors } = useTheme();
  const { user, q, r } = item;
  const { x, y } = axialToPixel(q, r);

  const style = useAnimatedStyle(() => {
    'worklet';
    const cx = centerX.value;
    const cy = centerY.value;
    const itemX = x + panX.value + cx;
    const itemY = y + panY.value + cy;

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
        { translateX: px + cx - OFFSET },
        { translateY: py + cy - OFFSET },
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
HexItem.displayName = 'HexItem';

function RadarBackdrop({ accent, centerX, centerY }: { accent: string; centerX: number; centerY: number }) {
  return (
    <View style={StyleSheet.absoluteFillObject} pointerEvents="none">
      <LinearGradient
        colors={['rgba(255,255,255,0.65)', 'rgba(245,245,245,0.92)', 'rgba(235,235,235,1)']}
        locations={[0, 0.55, 1]}
        style={StyleSheet.absoluteFillObject}
      />

      <View style={[styles.gridCross, { left: centerX - 520, top: centerY - 0.5, backgroundColor: accent, opacity: 0.06 }]} />
      <View style={[styles.gridCross, { left: centerX - 520, top: centerY - 0.5, backgroundColor: accent, opacity: 0.06, transform: [{ rotate: '90deg' }] }]} />
      <View style={[styles.gridCross, { left: centerX - 520, top: centerY - 0.5, backgroundColor: accent, opacity: 0.03, transform: [{ rotate: '45deg' }] }]} />
      <View style={[styles.gridCross, { left: centerX - 520, top: centerY - 0.5, backgroundColor: accent, opacity: 0.03, transform: [{ rotate: '-45deg' }] }]} />

      <View style={[styles.ring, { width: 220, height: 220, left: centerX - 110, top: centerY - 110, borderColor: 'rgba(0,0,0,0.08)' }]} />
      <View style={[styles.ring, { width: 420, height: 420, left: centerX - 210, top: centerY - 210, borderColor: 'rgba(0,0,0,0.06)' }]} />
      <View style={[styles.ring, { width: 640, height: 640, left: centerX - 320, top: centerY - 320, borderColor: 'rgba(0,0,0,0.045)' }]} />

      <View style={[styles.centerGlow, { left: centerX - 60, top: centerY - 60, backgroundColor: accent, opacity: 0.04 }]} />
    </View>
  );
}

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
    const router = useRouter();
    const [selectedUser, setSelectedUser] = useState<any>(null);
    const [viewportSize, setViewportSize] = useState({ width: SCREEN_WIDTH, height: SCREEN_HEIGHT });
    const centerXJs = viewportSize.width / 2;
    const centerYJs = viewportSize.height / 2;
    const centerX = useSharedValue(centerXJs);
    const centerY = useSharedValue(centerYJs);

    useEffect(() => {
        centerX.value = centerXJs;
        centerY.value = centerYJs;
    }, [centerX, centerXJs, centerY, centerYJs]);

    useEffect(() => {
        fetchRadarUsers({ reset: true });
    }, [fetchRadarUsers]);

    const coordGenerator = useRef(spiralCoordGenerator());
    const seenIdsRef = useRef(new Set<string>());
    const [honeycomb, setHoneycomb] = useState<any[]>([]);
    const [isLoading, setIsLoading] = useState(false);
    const [chatLoadingId, setChatLoadingId] = useState<string | null>(null);
    const [cursor, setCursor] = useState<string | null>(null);
    const [location, setLocation] = useState<{ lat: number; lng: number } | null>(null);

    const panX = useSharedValue(0);
    const panY = useSharedValue(0);
    const startX = useSharedValue(0);
    const startY = useSharedValue(0);
    const gridBounds = useSharedValue({ minX: 0, maxX: 0, minY: 0, maxY: 0 });
    const canvasScale = useSharedValue(1);

    useEffect(() => {
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
    }, [honeycomb, gridBounds]);

    const calcDistanceKm = useCallback((lat1: number, lng1: number, lat2: number, lng2: number) => {
        const toRad = (value: number) => (value * Math.PI) / 180;
        const R = 6371;
        const dLat = toRad(lat2 - lat1);
        const dLng = toRad(lng2 - lng1);
        const a = Math.sin(dLat / 2) ** 2 +
            Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
            Math.sin(dLng / 2) ** 2;
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c;
    }, []);

    const formatDistance = useCallback((km: number | null) => {
        if (km === null || !Number.isFinite(km)) return '-';
        if (km < 1) return km.toFixed(1);
        if (km < 10) return km.toFixed(1);
        return km.toFixed(0);
    }, []);

    const resolveLocation = useCallback(async () => {
        if (location) return location;
        const { status } = await Location.requestForegroundPermissionsAsync();
        if (status !== 'granted') {
            setLocation(DEFAULT_COORDS);
            return DEFAULT_COORDS;
        }
        const loc = await Location.getCurrentPositionAsync({});
        const coords = { lat: loc.coords.latitude, lng: loc.coords.longitude };
        setLocation(coords);
        return coords;
    }, [location]);

    const mapRadarUser = useCallback((raw: any, coords: { lat: number; lng: number }) => {
        const latRaw = raw?.location?.latitude ?? raw?.location?.location_point?.lat;
        const lngRaw = raw?.location?.longitude ?? raw?.location?.location_point?.lng;
        const lat = typeof latRaw === 'string' ? parseFloat(latRaw) : latRaw;
        const lng = typeof lngRaw === 'string' ? parseFloat(lngRaw) : lngRaw;
        if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
        const distanceKm = calcDistanceKm(coords.lat, coords.lng, lat, lng);
        const ageValue = typeof raw?.date_of_birth === 'string' ? calculateAge(raw.date_of_birth) : '-';
        const imageUrl = getSafeImageURLEx(raw?.public_id ?? raw?.id, raw?.avatar, 'medium') || '';
        const id = String(raw?.id ?? raw?.public_id ?? '');
        return {
            ...raw,
            id,
            name: raw?.displayname ?? raw?.username ?? 'User',
            displayname: raw?.displayname ?? raw?.username ?? 'User',
            username: raw?.username ?? '',
            age: typeof ageValue === 'number' ? ageValue : '-',
            imageUrl,
            distance: formatDistance(distanceKm),
        };
    }, [calcDistanceKm, formatDistance]);

    const fetchRadarUsers = useCallback(async (opts?: { reset?: boolean }) => {
        if (isLoading) return;
        setIsLoading(true);
        try {
            if (opts?.reset) {
                coordGenerator.current = spiralCoordGenerator();
                seenIdsRef.current = new Set();
                setHoneycomb([]);
                setCursor(null);
            }
            const coords = await resolveLocation();
            const response: any = await api.fetchNearbyUsers(coords.lat, coords.lng, opts?.reset ? null : cursor, 60);
            const payload = response?.data ?? response;
            if (response?.success === false || payload?.success === false) {
                throw new Error(response?.message || payload?.message || 'Failed to fetch users');
            }
            const rawUsers = payload?.users ?? response?.users ?? [];
            const nextCursor = payload?.cursor ?? response?.cursor ?? null;
            const mapped = rawUsers
                .map((raw: any) => mapRadarUser(raw, coords))
                .filter((item: any) => item && item.id);
            const newItems: any[] = [];
            for (const user of mapped) {
                if (seenIdsRef.current.has(user.id)) continue;
                seenIdsRef.current.add(user.id);
                const coords = coordGenerator.current.next().value;
                newItems.push({ user, ...coords, id: `hex-${user.id}` });
            }
            if (opts?.reset) {
                setHoneycomb(newItems);
            } else {
                setHoneycomb(prev => [...prev, ...newItems]);
            }
            setCursor(nextCursor);
        } catch (error) {
            console.error('Radar fetch failed', error);
        } finally {
            setIsLoading(false);
        }
    }, [isLoading, cursor, resolveLocation, mapRadarUser]);

    const loadMore = useCallback(() => {
        if (!cursor || isLoading) return;
        fetchRadarUsers();
    }, [cursor, isLoading, fetchRadarUsers]);

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

    const focusNearest = useCallback((items: any[]) => {
        if (!items.length) return;
        let minDist = Infinity;
        let targetX = 0;
        let targetY = 0;
        for (let i = 0; i < items.length; i += 1) {
            const h = items[i] as any;
            const p = axialToPixel(h.q, h.r);
            const px = p.x + panX.value;
            const py = p.y + panY.value;
            const d = px * px + py * py;
            if (d < minDist) {
                minDist = d;
                targetX = p.x;
                targetY = p.y;
            }
        }
        panX.value = withSpring(-targetX, { damping: 18, stiffness: 90 });
        panY.value = withSpring(-targetY, { damping: 18, stiffness: 90 });
    }, [panX, panY]);

    const handleDismissCard = (userToRemove: any) => {
        setSelectedUser(null);
        setHoneycomb(prev => {
            const next = prev.filter(item => item.user.id !== userToRemove.id);
            requestAnimationFrame(() => focusNearest(next));
            return next;
        });
    };

    const handleChat = useCallback(async (user: any) => {
        const userId = user?.id;
        if (!userId) return;
        setChatLoadingId(userId);
        try {
            const response = await api.createChat([userId]);
            const chatId = (response as { chat?: { id?: string } })?.chat?.id ?? userId;
            router.push({
                pathname: '/ChatDetail',
                params: {
                    chatId,
                    name: user.displayname || user.name || user.username,
                    avatar: user.imageUrl,
                    status: 'online',
                },
            });
        } catch (error) {
            console.error('Radar create chat failed', error);
            router.push({
                pathname: '/ChatDetail',
                params: {
                    chatId: userId,
                    name: user.displayname || user.name || user.username,
                    avatar: user.imageUrl,
                    status: 'online',
                },
            });
        } finally {
            setChatLoadingId(null);
        }
    }, [router]);

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
                        <Animated.View
                            style={[styles.radarViewport, animatedCanvasStyle]}
                            onLayout={(e: LayoutChangeEvent) => {
                                const { width, height } = e.nativeEvent.layout;
                                if (width > 0 && height > 0) {
                                    setViewportSize({ width, height });
                                }
                            }}
                        >
                            <RadarBackdrop accent={colors.primary || colors.text} centerX={centerXJs} centerY={centerYJs} />

                            {honeycomb.map((item) => (
                                <HexItem
                                    key={item.id}
                                    item={item}
                                    panX={panX}
                                    panY={panY}
                                    centerX={centerX}
                                    centerY={centerY}
                                    onSelect={handleItemPress}
                                />
                            ))}

                            {/* Fixed Crosshair (Magnet Point) */}
                            <View style={[styles.crosshairContainer, { left: centerXJs - 170, top: centerYJs - 170 }]} pointerEvents="none">
                                <View style={[styles.crossLineV, { backgroundColor: colors.text, opacity: 0.1 }]} />
                                <View style={[styles.crossLineH, { backgroundColor: colors.text, opacity: 0.1 }]} />
                                <View style={[styles.centerPulse, { borderColor: colors.text, opacity: 0.03 }]} />
                            </View>
                        </Animated.View>
                    </GestureDetector>
                </View>

                {selectedUser && (
                    <UserCard
                        user={selectedUser}
                        onDismiss={handleDismissCard}
                        onChat={handleChat}
                        chatLoadingId={chatLoadingId}
                    />
                )}
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

  // Pro radar background
  ring: { position: 'absolute', borderRadius: 999, borderWidth: 1 },
  gridCross: {
    position: 'absolute',
    width: 1040,
    height: 1,
  },
  centerGlow: {
    position: 'absolute',
    width: 120,
    height: 120,
    borderRadius: 60,
  },
});
