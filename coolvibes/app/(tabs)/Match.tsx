import React, { useState, memo, useCallback, useRef, useEffect, useMemo } from 'react';
import { View, Text, StyleSheet, Pressable, Dimensions, ActivityIndicator, TouchableOpacity, Platform, LayoutChangeEvent } from 'react-native';
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
import { LinearGradient } from 'expo-linear-gradient';
import { Image as ExpoImage } from 'expo-image';
import { BlurView } from 'expo-blur';
import { useRouter } from 'expo-router';
import * as Location from 'expo-location';
import { api } from '@/services/apiService';
import { encodeProfileParam, normalizeProfileUser } from '@/helpers/profile';
import { calculateAge, getSafeImageURLEx } from '@/helpers/safeUrl';
import FullProfileView from '@/components/FullProfileView';
import { useAppSelector } from '@/store/hooks';

const DEFAULT_COORDS = { lat: 41.0082, lng: 28.9784 };
// --- CONFIGURATION & DIMENSIONS ---
const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');
const HEX_SIZE = 100;
const RADAR_HEIGHT = SCREEN_HEIGHT;
const ITEM_DIM = 140;
const OFFSET = ITEM_DIM / 2;
const CARD_DIAMETER = SCREEN_WIDTH * 0.8;
const ACTION_BUTTON_SIZE = 70;
const EXPANDED_AVATAR_SIZE = 110;
const NAME_AGE_HEIGHT_ESTIMATE = 70;
const PROFILE_BANNER_HEIGHT = 200;
const AnimatedBlurView = Animated.createAnimatedComponent(BlurView);
const AnimatedExpoImage = Animated.createAnimatedComponent(ExpoImage);
const DEFAULT_RADAR_COLOR = { r: 52, g: 199, b: 89 };

const parseHexColor = (value?: string) => {
  if (!value || typeof value !== 'string') return null;
  const hex = value.trim();
  if (!hex.startsWith('#')) return null;
  const normalized = hex.length === 4
    ? `#${hex[1]}${hex[1]}${hex[2]}${hex[2]}${hex[3]}${hex[3]}`
    : hex;
  if (!/^#([0-9a-fA-F]{6})$/.test(normalized)) return null;
  const r = parseInt(normalized.slice(1, 3), 16);
  const g = parseInt(normalized.slice(3, 5), 16);
  const b = parseInt(normalized.slice(5, 7), 16);
  return { r, g, b };
};

const normalizeNearbyDistance = (value: unknown): string => {
  if (typeof value === 'number' && Number.isFinite(value)) {
    if (value < 1) return value.toFixed(1);
    if (value < 10) return value.toFixed(1);
    return value.toFixed(0);
  }

  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase().replace(/km/g, '').trim();
    const parsed = Number(normalized);
    if (Number.isFinite(parsed)) {
      if (parsed < 1) return parsed.toFixed(1);
      if (parsed < 10) return parsed.toFixed(1);
      return parsed.toFixed(0);
    }
  }

  return '-';
};

const formatNearbyDistanceLabel = (distance: string) => (
  distance && distance !== '-' ? `${distance} km` : null
);


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
        <ExpoImage source={{ uri: user.imageUrl }} style={styles.bubbleImage} contentFit="cover" transition={150} />
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

type RadarUserCardProps = {
    radarUser: any;
    profileUser: any;
    blurPhotos: boolean;
    onDismiss: () => void;
    onLike: () => void;
    onDislike: () => void;
    onChat: () => void;
};

const RadarUserCard = memo(({ radarUser, profileUser, blurPhotos, onDismiss, onLike, onDislike, onChat }: RadarUserCardProps) => {
    const { colors, dark } = useTheme();
    const insets = useSafeAreaInsets();
    const [isExpanded, setIsExpanded] = useState(false);
    const animationProgress = useSharedValue(0);

    useEffect(() => {
        setIsExpanded(false);
        animationProgress.value = 0;
    }, [radarUser?.id, animationProgress]);

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
        if (action === 'like') onLike();
        if (action === 'dislike') onDislike();
        if (action === 'chat') onChat();
        onDismiss();
    };

    const handleClose = () => {
        onDismiss();
    };

    const animatedBlurStyle = useAnimatedStyle(() => ({
        opacity: interpolate(animationProgress.value, [0, 0.5, 1], [0.8, 0.9, 1]),
    }));

    const collapsedY = SCREEN_HEIGHT / 2 - (CARD_DIAMETER / 2) - 60;
    const expandedY = insets.top + 20;

    const animatedImageContainerStyle = useAnimatedStyle(() => ({
        transform: [{ translateY: interpolate(animationProgress.value, [0, 1], [collapsedY, expandedY]) }],
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
        const imageContainerTranslateY = interpolate(animationProgress.value, [0, 1], [collapsedY, expandedY]);
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
        const imageContainerTranslateY = interpolate(animationProgress.value, [0, 1], [collapsedY, expandedY]);
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

    const profileContentTopInset = Math.max(
        0,
        expandedY +
            EXPANDED_AVATAR_SIZE +
            15 +
            NAME_AGE_HEIGHT_ESTIMATE +
            25 +
            (ACTION_BUTTON_SIZE + 10) -
            PROFILE_BANNER_HEIGHT +
            20
    );

    const iconColor = dark ? '#FFFFFF' : '#000000';
    const premiumAccent = '#7C4DFF';
    const displayName = radarUser?.displayname || radarUser?.name || radarUser?.username || 'User';
    const distanceText = formatNearbyDistanceLabel(radarUser?.distance ?? '');
    const ageText = radarUser?.age ? `${radarUser.age}` : '';
    const imageUrl =
        getSafeImageURLEx(radarUser?.public_id ?? radarUser?.id, radarUser?.avatar ?? radarUser?.avatar_url ?? radarUser?.imageUrl, 'large') ||
        radarUser?.imageUrl;

    return (
        <View style={styles.cardWrapper} pointerEvents="auto">
            <AnimatedBlurView 
              style={[StyleSheet.absoluteFill, { backgroundColor: dark ? 'rgba(0,0,0,0.8)' : 'rgba(255,255,255,0.9)' }, animatedBlurStyle]} 
              tint={dark ? 'dark' : 'light'} 
              intensity={Platform.OS === 'ios' ? 40 : 100}
            />
            
            <Animated.View style={[styles.detailsContainer, animatedDetailsStyle]} pointerEvents={isExpanded ? 'auto' : 'none'}>
                <FullProfileView
                    user={profileUser}
                    isMe={false}
                    showActions={false}
                    hideHeader
                    hideTabs
                    defaultTab="about"
                    showCover
                    contentTopInset={profileContentTopInset}
                />
            </Animated.View>

            <Animated.View style={[styles.imageContainer, animatedImageContainerStyle]}>
                <Pressable
                    onPress={handleToggleExpand}
                    onPressIn={() => Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light)}
                    style={({ pressed }) => ({ opacity: pressed ? 0.9 : 1 })}
                >
                    <AnimatedExpoImage
                        source={{ uri: imageUrl }} 
                        style={[styles.cardImage, { borderColor: dark ? '#222' : '#EEE' }, animatedImageStyle]} 
                        contentFit="cover"
                        transition={200}
                        blurRadius={blurPhotos ? 20 : 0}
                    />
                    <Animated.View style={[styles.cardOverlay, animatedImageStyle, animatedOverlayStyle]} />
                    <View style={styles.premiumBadge}>
                        <MaterialCommunityIcons name="star" size={14} color="#FFF" />
                    </View>
                </Pressable>
            </Animated.View>

            <Animated.View style={[animatedNameAgePositionStyle]}>
                <Text style={[styles.cardName, { color: colors.text }]}>
                    {displayName}{ageText ? `, ${ageText}` : ''}
                </Text>
                <View style={styles.badgeRow}>
                    <View style={[styles.verifiedBadge, { backgroundColor: dark ? '#333' : '#EEE' }]}>
                        <MaterialCommunityIcons name="check-decagram" size={14} color={premiumAccent} />
                        <Text style={[styles.badgeText, { color: colors.text }]}>Verified</Text>
                    </View>
                    {!!distanceText && (
                        <Text style={[styles.cardDistance, { color: colors.text, opacity: 0.5 }]}>• {distanceText}</Text>
                    )}
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
});
RadarUserCard.displayName = 'RadarUserCard';

export default function MatchScreen() {
    const { colors, dark } = useTheme();
    const insets = useSafeAreaInsets();
    const router = useRouter();
    const blurPhotos = useAppSelector(state => state.system.blurPhotos);
    const [selectedUser, setSelectedUser] = useState<any>(null);
    const [profileFetchedUser, setProfileFetchedUser] = useState<any | null>(null);
    const lastProfileFetchKeyRef = useRef<string | null>(null);
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
    const [cursor, setCursor] = useState<string | null>(null);
    const [location, setLocation] = useState<{ lat: number; lng: number } | null>(null);

    const normalizeName = (value?: string) => (typeof value === 'string' ? value.trim() : '');
    const isGenericName = (value: string) => {
        const lower = value.toLowerCase();
        return lower === 'chat' || lower === 'user' || lower === 'unknown' || lower === 'me';
    };
    const isValidUsername = (value?: string) => {
        const name = normalizeName(value);
        if (!name) return false;
        if (isGenericName(name)) return false;
        if (/\s/.test(name)) return false;
        return true;
    };
    const isValidNickname = (value?: string) => {
        const name = normalizeName(value);
        if (!name) return false;
        if (isGenericName(name)) return false;
        return true;
    };

    const profileFallback = useMemo(() => selectedUser ? {
        id: String(selectedUser?.id ?? ''),
        name: selectedUser?.displayname || selectedUser?.name || selectedUser?.username,
        username: selectedUser?.username,
        avatar: selectedUser?.imageUrl,
    } : undefined, [selectedUser]);

    const profileFetchUsername = useMemo(() => {
        if (!selectedUser) return null;
        const candidate = selectedUser?.username || selectedUser?.raw?.username || profileFallback?.username;
        return isValidUsername(candidate) ? normalizeName(candidate) : null;
    }, [selectedUser, profileFallback]);

    const profileFetchNickname = useMemo(() => {
        if (!selectedUser || profileFetchUsername) return null;
        const candidate = selectedUser?.raw?.nickname;
        return isValidNickname(candidate) ? normalizeName(candidate) : null;
    }, [selectedUser, profileFetchUsername]);

    const profileIdentityKey =
        selectedUser?.id ||
        selectedUser?.public_id ||
        selectedUser?.raw?.id ||
        selectedUser?.raw?.public_id ||
        profileFallback?.id ||
        profileFallback?.username ||
        null;

    useEffect(() => {
        setProfileFetchedUser(null);
        lastProfileFetchKeyRef.current = null;
    }, [profileIdentityKey]);

    useEffect(() => {
        if (!selectedUser) return;
        const fetchKey = profileFetchUsername || profileFetchNickname;
        if (!fetchKey || lastProfileFetchKeyRef.current === fetchKey) return;
        lastProfileFetchKeyRef.current = fetchKey;
        let isActive = true;
        const run = async () => {
            try {
                const response = profileFetchUsername
                    ? await api.fetchProfile(profileFetchUsername)
                    : await api.fetchProfileByNickname(profileFetchNickname as string);
                const payload = (response as any)?.data ?? response;
                const profile =
                    payload?.user ||
                    payload?.data?.user ||
                    payload?.profile ||
                    payload?.data?.profile ||
                    payload?.data ||
                    payload;
                if (isActive && profile) setProfileFetchedUser(profile);
            } catch {
                // ignore
            }
        };
        run();
        return () => {
            isActive = false;
        };
    }, [selectedUser, profileFetchUsername, profileFetchNickname]);

    const resolvedProfileUser = useMemo(
        () => selectedUser ? normalizeProfileUser(profileFetchedUser ?? selectedUser, profileFallback) : null,
        [profileFetchedUser, selectedUser, profileFallback]
    );

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
        try {
            const { status } = await Location.requestForegroundPermissionsAsync();
            if (status !== 'granted') {
                setLocation(DEFAULT_COORDS);
                return DEFAULT_COORDS;
            }
            try {
                const loc = await Location.getCurrentPositionAsync({ accuracy: Location.Accuracy.Balanced });
                const coords = { lat: loc.coords.latitude, lng: loc.coords.longitude };
                setLocation(coords);
                return coords;
            } catch {
                const lastKnown = await Location.getLastKnownPositionAsync({});
                if (lastKnown?.coords) {
                    const coords = { lat: lastKnown.coords.latitude, lng: lastKnown.coords.longitude };
                    setLocation(coords);
                    return coords;
                }
                setLocation(DEFAULT_COORDS);
                return DEFAULT_COORDS;
            }
        } catch {
            setLocation(DEFAULT_COORDS);
            return DEFAULT_COORDS;
        }
    }, [location]);

    const mapRadarUser = useCallback((raw: any, coords: { lat: number; lng: number }) => {
        const latRaw =
            raw?.lat ??
            raw?.latitude ??
            raw?.location_point?.lat ??
            raw?.location_point?.latitude ??
            raw?.location?.lat ??
            raw?.location?.latitude ??
            raw?.location?.location_point?.lat ??
            raw?.location_data?.lat ??
            raw?.location_data?.latitude ??
            raw?.location_data?.location_point?.lat;
        const lngRaw =
            raw?.lng ??
            raw?.lon ??
            raw?.longitude ??
            raw?.location_point?.lng ??
            raw?.location_point?.lon ??
            raw?.location_point?.longitude ??
            raw?.location?.lng ??
            raw?.location?.lon ??
            raw?.location?.longitude ??
            raw?.location?.location_point?.lng ??
            raw?.location_data?.lng ??
            raw?.location_data?.lon ??
            raw?.location_data?.longitude ??
            raw?.location_data?.location_point?.lng;
        const lat = typeof latRaw === 'string' ? parseFloat(latRaw) : latRaw;
        const lng = typeof lngRaw === 'string' ? parseFloat(lngRaw) : lngRaw;
        const hasCoordinates = Number.isFinite(lat) && Number.isFinite(lng);
        const fallbackDistanceRaw =
            raw?.distance ??
            raw?.distance_km ??
            raw?.distanceKm ??
            raw?.location?.distance ??
            raw?.location_data?.distance ??
            null;
        const distanceText = hasCoordinates
            ? formatDistance(calcDistanceKm(coords.lat, coords.lng, lat as number, lng as number))
            : normalizeNearbyDistance(fallbackDistanceRaw);
        const ageValue = typeof raw?.date_of_birth === 'string' ? calculateAge(raw.date_of_birth) : '-';
        const imageUrl =
            getSafeImageURLEx(raw?.public_id ?? raw?.id, raw?.avatar ?? raw?.avatar_url ?? raw?.avatarUrl, 'medium') || '';
        const id = String(raw?.id ?? raw?.public_id ?? '');
        return {
            ...raw,
            id,
            name: raw?.displayname ?? raw?.username ?? 'User',
            displayname: raw?.displayname ?? raw?.username ?? 'User',
            username: raw?.username ?? '',
            age: typeof ageValue === 'number' ? ageValue : '-',
            imageUrl,
            distance: distanceText,
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

    const sendReaction = useCallback(async (reaction: 'like' | 'dislike') => {
        if (!selectedUser) return;
        const targetId = selectedUser?.public_id ?? selectedUser?.id;
        if (!targetId) return;
        try {
            await api.createMatch(targetId, reaction);
            Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
        } catch (error) {
            console.error('Radar reaction failed', error);
        }
    }, [selectedUser]);

    const handleLike = useCallback(() => {
        void sendReaction('like');
    }, [sendReaction]);

    const handleDislike = useCallback(() => {
        void sendReaction('dislike');
    }, [sendReaction]);

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

    const radarAccent = useMemo(() => {
        const parsed = parseHexColor(colors.primary) ?? parseHexColor(colors.text) ?? DEFAULT_RADAR_COLOR;
        const rgb = parsed || DEFAULT_RADAR_COLOR;
        return {
            rgb,
            solid: `rgb(${rgb.r},${rgb.g},${rgb.b})`,
            rgba: (alpha: number) => `rgba(${rgb.r},${rgb.g},${rgb.b},${alpha})`,
        };
    }, [colors.primary, colors.text]);

    const handleChat = useCallback(async (user: any) => {
        const userId = user?.id;
        if (!userId) return;
        try {
            const response = await api.createChat([userId]);
            const chatId = (response as { chat?: { id?: string } })?.chat?.id ?? userId;
            router.push({
                pathname: '/ChatDetail',
                params: {
                    chatId,
                    name: user.displayname || user.name || user.username,
                    username: user.username,
                    avatar: user.imageUrl,
                    status: 'online',
                    profile: encodeProfileParam(user),
                },
            });
        } catch (error) {
            console.error('Radar create chat failed', error);
            router.push({
                pathname: '/ChatDetail',
                params: {
                    chatId: userId,
                    name: user.displayname || user.name || user.username,
                    username: user.username,
                    avatar: user.imageUrl,
                    status: 'online',
                    profile: encodeProfileParam(user),
                },
            });
        } finally {
        }
    }, [router]);

    const bottomBarHeight = Platform.OS === 'ios' ? 88 : 68;

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
                            <RadarBackdrop accent={radarAccent.solid} centerX={centerXJs} centerY={centerYJs} />

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
                    <RadarUserCard
                        radarUser={selectedUser}
                        profileUser={resolvedProfileUser ?? selectedUser}
                        blurPhotos={Boolean(blurPhotos)}
                        onDismiss={() => setSelectedUser(null)}
                        onLike={handleLike}
                        onDislike={handleDislike}
                        onChat={() => {
                            if (selectedUser) handleChat(selectedUser);
                        }}
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
  radarViewport: { position:"relative", flex: 1, justifyContent: 'center', alignItems: 'center', overflow: 'hidden' },
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
  cardWrapper: { ...StyleSheet.absoluteFillObject, zIndex: 1000 },
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
  cardName: { fontSize: 34, fontFamily: 'Outfit-Black', letterSpacing: -1.5, marginBottom: 4 },
  badgeRow: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  verifiedBadge: { 
    flexDirection: 'row', 
    alignItems: 'center', 
    gap: 4, 
    paddingHorizontal: 10, 
    paddingVertical: 4, 
    borderRadius: 12 
  },
  badgeText: { fontSize: 12, fontFamily: 'Inter-Bold' },
  cardDistance: { fontSize: 14, fontFamily: 'Inter-SemiBold' },
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
