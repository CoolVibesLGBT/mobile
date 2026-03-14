import React, { useState, useRef, useCallback, useEffect, useMemo } from 'react';
import {
    View,
    Text,
    StyleSheet,
    TouchableOpacity,
    FlatList,
    Dimensions,
    StatusBar,
    Platform,
    TextInput,
    ActivityIndicator,
    Animated,
} from 'react-native';
import { useTheme } from '@react-navigation/native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { Ionicons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { LinearGradient } from 'expo-linear-gradient';
import MapView, { Marker, PROVIDER_GOOGLE, Region } from 'react-native-maps';
import * as Location from 'expo-location';
import * as Haptics from 'expo-haptics';
import { useNavigation } from '@react-navigation/native';
import { useAppSelector } from '@/store/hooks';
import { api } from '@/services/apiService';
import { calculateAge, getSafeImageURLEx } from '@/helpers/safeUrl';
import { encodeProfileParam, normalizeProfileUser } from '@/helpers/profile';
import BaseBottomSheetModal from '@/components/BaseBottomSheetModal';
import { BottomSheetBackdrop, BottomSheetFlatList } from '@gorhom/bottom-sheet';
import type { BottomSheetModal } from '@gorhom/bottom-sheet';
import FullProfileView from '@/components/FullProfileView';
import { GOOGLE_PLACES_KEY } from '@/config';
import { BlurView } from 'expo-blur';

const { width } = Dimensions.get('window');

const GLOBAL_HEADER_HEIGHT = 60;
const TAB_BAR_HEIGHT = Platform.OS === 'ios' ? 88 : 68;
const H_PAD = 12;
const GRID_GAP = 8;
const DEFAULT_COORDS = { lat: 41.0082, lng: 28.9784 };

type ViewModeType = 'grid' | 'list' | 'map';
type GridColsType = 2 | 3 | 4;

interface NearbyUser {
    id: string;
    username: string;
    displayname: string;
    lat: number;
    lng: number;
    imageUrl: string;
    age: number | string;
    distance: string;
    online: boolean;
    raw?: any;
}

/* ── GRID CARD (adapts size + detail based on column count) ── */
const GridCard = React.memo(({
    user, dark, cols, onPress, blurPhotos,
}: {
    user: NearbyUser; dark: boolean; cols: GridColsType; onPress: () => void; blurPhotos: boolean;
}) => {
    const cardW = (width - H_PAD * 2 - GRID_GAP * (cols - 1)) / cols;
    const cardH = cols === 2 ? cardW * 1.45 : cols === 3 ? cardW * 1.5 : cardW * 1.6;
    const nameSize = cols === 2 ? 13 : cols === 3 ? 11 : 9;
    const metaSize = cols === 2 ? 11 : 9;
    const ageLabel = user.age !== '-' ? `, ${user.age}` : '';

    return (
        <TouchableOpacity
            onPress={onPress}
            activeOpacity={0.88}
            style={[styles.gridCard, { width: cardW, height: cardH }]}
        >
            <Image
                source={{ uri: user.imageUrl }}
                style={StyleSheet.absoluteFill}
                contentFit="cover"
                transition={200}
                blurRadius={blurPhotos ? 15 : 0}
            />
            <LinearGradient
                colors={['transparent', 'rgba(0,0,0,0.82)']}
                style={styles.gridGrad}
            >
                <Text style={[styles.gridName, { fontSize: nameSize }]} numberOfLines={1}>
                    {user.displayname}{cols < 4 ? ageLabel : ''}
                </Text>
                {cols <= 3 && (
                    <View style={styles.gridDistRow}>
                        <MaterialCommunityIcons name="map-marker" size={9} color="rgba(255,255,255,0.7)" />
                        <Text style={[styles.gridDistText, { fontSize: metaSize }]}>{user.distance} km</Text>
                    </View>
                )}
            </LinearGradient>
            {user.online && <View style={styles.onlineDot} />}
        </TouchableOpacity>
    );
});

/* ── LIST ROW ── */
const ListRow = React.memo(({
    user, dark, colors, onChat, onLike, onDislike, onProfile, blurPhotos,
}: {
    user: NearbyUser; dark: boolean; colors: any;
    onChat: () => void; onLike: () => void; onDislike: () => void; onProfile: () => void; blurPhotos: boolean;
}) => {
    const divider = dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.06)';
    const sub = dark ? '#666' : '#AAA';
    const btnBg = dark ? '#1C1C1C' : '#F0F0F0';
    const ageLabel = user.age !== '-' ? `, ${user.age}` : '';

    return (
        <View style={[styles.listRow, { borderBottomColor: divider }]}>
            <TouchableOpacity onPress={onProfile} activeOpacity={0.85}>
                <View>
                    <Image source={{ uri: user.imageUrl }} style={styles.listAvatar} contentFit="cover" blurRadius={blurPhotos ? 10 : 0} />
                    {user.online && <View style={[styles.listOnlineDot, { borderColor: colors.background }]} />}
                </View>
            </TouchableOpacity>

            <TouchableOpacity style={styles.listInfo} onPress={onProfile} activeOpacity={0.7}>
                <Text style={[styles.listName, { color: colors.text }]} numberOfLines={1}>
                    {user.displayname}{ageLabel}
                </Text>
                <View style={styles.listMeta}>
                    <MaterialCommunityIcons name="map-marker-outline" size={12} color={sub} />
                    <Text style={[styles.listMetaText, { color: sub }]}>{user.distance} km</Text>
                    {user.online && <Text style={[styles.listMetaText, { color: sub }]}>• Online</Text>}
                </View>
            </TouchableOpacity>

            {/* Action Buttons — 44pt minimum touch targets */}
            <View style={styles.listActions}>
                <TouchableOpacity onPress={onProfile} activeOpacity={0.75} style={[styles.actionBtn, { backgroundColor: btnBg }]}>
                    <MaterialCommunityIcons name="account-outline" size={18} color={sub} />
                </TouchableOpacity>
                <TouchableOpacity onPress={onDislike} activeOpacity={0.75} style={[styles.actionBtn, { backgroundColor: btnBg }]}>
                    <MaterialCommunityIcons name="close" size={18} color={sub} />
                </TouchableOpacity>
                <TouchableOpacity onPress={onLike} activeOpacity={0.75} style={[styles.actionBtn, { backgroundColor: btnBg }]}>
                    <MaterialCommunityIcons name="heart-outline" size={18} color={colors.text} />
                </TouchableOpacity>
                <TouchableOpacity onPress={onChat} activeOpacity={0.8} style={[styles.actionBtnPrimary, { backgroundColor: colors.text }]}>
                    <MaterialCommunityIcons name="message-text" size={18} color={colors.background} />
                </TouchableOpacity>
            </View>
        </View>
    );
});

/* ── MAP PIN ── */
const MapPin = React.memo(({
    user,
    dark,
    blurPhotos,
    isActive,
    isPressed,
    pressTick,
}: {
    user: NearbyUser;
    dark: boolean;
    blurPhotos: boolean;
    isActive: boolean;
    isPressed: boolean;
    pressTick: number;
}) => {
    const scale = useRef(new Animated.Value(1)).current;

    useEffect(() => {
        Animated.spring(scale, {
            toValue: isActive ? 1.18 : 1,
            useNativeDriver: true,
            friction: 6,
            tension: 120,
        }).start();
    }, [isActive, scale]);

    useEffect(() => {
        if (!isPressed) return;
        Animated.sequence([
            Animated.timing(scale, {
                toValue: 1.28,
                duration: 80,
                useNativeDriver: true,
            }),
            Animated.spring(scale, {
                toValue: isActive ? 1.18 : 1,
                useNativeDriver: true,
                friction: 5,
                tension: 120,
            }),
        ]).start();
    }, [isPressed, pressTick, scale, isActive]);

    return (
        <Animated.View style={[styles.pinWrap, { transform: [{ scale }] }]}>
            <View style={[styles.pinRing, { borderColor: dark ? '#FFF' : '#000' }]}>
                <Image source={{ uri: user.imageUrl }} style={styles.pinImg} contentFit="cover" blurRadius={blurPhotos ? 8 : 0} />
            </View>
            {user.online && <View style={[styles.pinOnline, { borderColor: dark ? '#111' : '#FFF' }]} />}
        </Animated.View>
    );
});

/* ════════════════════════ MAIN SCREEN ════════════════════════ */
export default function NearbyScreen() {
    const { colors, dark } = useTheme();
    const insets = useSafeAreaInsets();
    const navigation = useNavigation();
    const mapRef = useRef<MapView>(null);
    const requestRef = useRef(false);
    const cursorRef = useRef<string | null>(null);
    const usersRef = useRef<NearbyUser[]>([]);
    const didInitialFetch = useRef(false);
    const profileSheetRef = useRef<BottomSheetModal>(null);
    const teleportSheetRef = useRef<BottomSheetModal>(null);
    const mapMoveTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
    const lastFetchCenterRef = useRef<{ lat: number; lng: number } | null>(null);
    const isProgrammaticMoveRef = useRef(false);
    const isMapInteractingRef = useRef(false);
    const lastFetchTimeRef = useRef(0);

    const [viewMode, setViewMode] = useState<ViewModeType>('grid');
    const [gridCols, setGridCols] = useState<GridColsType>(2);
    const [users, setUsers] = useState<NearbyUser[]>([]);
    const [cursor, setCursor] = useState<string | null>(null);
    const [loading, setLoading] = useState(false);
    const [loadingMore, setLoadingMore] = useState(false);
    const [refreshing, setRefreshing] = useState(false);
    const [location, setLocation] = useState<{ lat: number; lng: number } | null>(null);
    const [mapRegion, setMapRegion] = useState<Region | null>(null);
    const [selectedUser, setSelectedUser] = useState<NearbyUser | null>(null);
    const [profileFetchedUser, setProfileFetchedUser] = useState<any | null>(null);
    const lastProfileFetchKeyRef = useRef<string | null>(null);
    const [activeMarkerId, setActiveMarkerId] = useState<string | null>(null);
    const [pressedMarkerId, setPressedMarkerId] = useState<string | null>(null);
    const [pressTick, setPressTick] = useState(0);
    const [teleportVisible, setTeleportVisible] = useState(false);
    const [teleportQuery, setTeleportQuery] = useState('');
    const [teleportPlaces, setTeleportPlaces] = useState<any[]>([]);
    const [teleportNextPage, setTeleportNextPage] = useState<string | null>(null);
    const [teleportLoading, setTeleportLoading] = useState(false);
    const [teleportRegion, setTeleportRegion] = useState<Region | null>(null);
    const [teleportSearching, setTeleportSearching] = useState(false);
    const blurPhotos = useAppSelector(state => state.system.blurPhotos);

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
        id: selectedUser.id,
        name: selectedUser.displayname,
        username: selectedUser.username,
        avatar: selectedUser.imageUrl,
    } : undefined, [selectedUser]);

    const profileFetchUsername = useMemo(() => {
        if (!selectedUser) return null;
        const candidate = selectedUser?.username || (selectedUser as any)?.raw?.username || profileFallback?.username;
        return isValidUsername(candidate) ? normalizeName(candidate) : null;
    }, [selectedUser, profileFallback]);

    const profileFetchNickname = useMemo(() => {
        if (!selectedUser || profileFetchUsername) return null;
        const candidate = (selectedUser as any)?.raw?.nickname;
        return isValidNickname(candidate) ? normalizeName(candidate) : null;
    }, [selectedUser, profileFetchUsername]);

    const profileIdentityKey =
        selectedUser?.id ||
        (selectedUser as any)?.raw?.id ||
        (selectedUser as any)?.raw?.public_id ||
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

    useEffect(() => {
        cursorRef.current = cursor;
    }, [cursor]);

    useEffect(() => {
        usersRef.current = users;
    }, [users]);

    const contentPaddingTop = GLOBAL_HEADER_HEIGHT + insets.top;
    const borderColor = dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.07)';
    const toggleBg = dark ? '#111' : '#F0F0F0';
    const stylesVars = {
        mapBtnBg: dark ? 'rgba(0,0,0,0.35)' : 'rgba(255,255,255,0.7)',
        mapBtnBorder: dark ? 'rgba(255,255,255,0.18)' : 'rgba(0,0,0,0.08)',
        mapBtnIcon: dark ? '#FFF' : '#111',
        mapBtnBlurTint: dark ? 'dark' : 'light',
        mapBtnBlurIntensity: Platform.OS === 'ios' ? 30 : 55,
    };

    const formatDistance = useCallback((km: number | null) => {
        if (km === null || !Number.isFinite(km)) return '-';
        if (km < 1) return km.toFixed(1);
        if (km < 10) return km.toFixed(1);
        return km.toFixed(0);
    }, []);

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
                mapRef.current?.animateToRegion({
                    latitude: coords.lat,
                    longitude: coords.lng,
                    latitudeDelta: 0.06,
                    longitudeDelta: 0.06,
                });
                return coords;
            } catch {
                const lastKnown = await Location.getLastKnownPositionAsync({});
                if (lastKnown?.coords) {
                    const coords = { lat: lastKnown.coords.latitude, lng: lastKnown.coords.longitude };
                    setLocation(coords);
                    mapRef.current?.animateToRegion({
                        latitude: coords.lat,
                        longitude: coords.lng,
                        latitudeDelta: 0.06,
                        longitudeDelta: 0.06,
                    });
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

    const mapUser = useCallback((raw: any, coords: { lat: number; lng: number }) => {
        const latRaw = raw?.location?.latitude ?? raw?.location?.location_point?.lat;
        const lngRaw = raw?.location?.longitude ?? raw?.location?.location_point?.lng;
        const lat = typeof latRaw === 'string' ? parseFloat(latRaw) : latRaw;
        const lng = typeof lngRaw === 'string' ? parseFloat(lngRaw) : lngRaw;
        if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
        const distanceKm = calcDistanceKm(coords.lat, coords.lng, lat, lng);
        const ageValue = typeof raw?.date_of_birth === 'string' ? calculateAge(raw.date_of_birth) : '-';
        const imageUrl = getSafeImageURLEx(raw?.public_id ?? raw?.id, raw?.avatar, 'medium') || '';
        return {
            id: String(raw?.id ?? raw?.public_id ?? ''),
            username: String(raw?.username ?? raw?.displayname ?? 'user'),
            displayname: String(raw?.displayname ?? raw?.username ?? 'User'),
            lat,
            lng,
            imageUrl,
            age: typeof ageValue === 'number' ? ageValue : '-',
            distance: formatDistance(distanceKm),
            online: Boolean(raw?.is_online ?? raw?.online),
            raw,
        } as NearbyUser;
    }, [calcDistanceKm, formatDistance]);

    const spreadMarkers = useCallback((items: NearbyUser[]) => {
        const groups = new Map<string, NearbyUser[]>();
        for (const item of items) {
            const key = `${item.lat.toFixed(4)}:${item.lng.toFixed(4)}`;
            const group = groups.get(key);
            if (group) group.push(item);
            else groups.set(key, [item]);
        }
        const output: NearbyUser[] = [];
        for (const group of groups.values()) {
            if (group.length === 1) {
                output.push(group[0]);
                continue;
            }
            const radius = 0.0008;
            const step = (Math.PI * 2) / group.length;
            group.forEach((user, index) => {
                const angle = index * step;
                output.push({
                    ...user,
                    lat: user.lat + Math.cos(angle) * radius,
                    lng: user.lng + Math.sin(angle) * radius,
                });
            });
        }
        return output;
    }, []);

    const fetchNearby = useCallback(async (opts?: { refresh?: boolean; coords?: { lat: number; lng: number } }) => {
        if (requestRef.current) return;
        const refresh = opts?.refresh === true;
        const currentCursor = cursorRef.current;
        const hasUsers = usersRef.current.length > 0;
        if (!refresh && !currentCursor && hasUsers) return;
        requestRef.current = true;
        refresh ? setRefreshing(true) : (currentCursor ? setLoadingMore(true) : setLoading(true));
        try {
            if (refresh) {
                cursorRef.current = null;
                setCursor(null);
            }
            const coords = opts?.coords ?? await resolveLocation();
            const response: any = await api.fetchNearbyUsers(coords.lat, coords.lng, refresh ? null : currentCursor, 100);
            const payload = response?.data ?? response;
            if (response?.success === false || payload?.success === false) {
                throw new Error(response?.message || payload?.message || 'Failed to fetch nearby users');
            }
            const rawUsers = payload?.users ?? response?.users ?? [];
            const nextCursor = payload?.cursor ?? response?.cursor ?? null;
            const mapped = rawUsers
                .map((raw: any) => mapUser(raw, coords))
                .filter((item: NearbyUser | null): item is NearbyUser => item !== null && item.id !== '');

            const resolved = spreadMarkers(mapped);
            setUsers(prev => {
                if (refresh) return resolved;
                const existingIds = new Set(prev.map(u => u.id));
                const merged = [...prev];
                for (const item of resolved) {
                    if (!existingIds.has(item.id)) merged.push(item);
                }
                return merged;
            });
            setCursor(nextCursor);
            lastFetchTimeRef.current = Date.now();
        } catch (error) {
            console.error('Failed to fetch nearby users', error);
        } finally {
            setLoading(false);
            setLoadingMore(false);
            setRefreshing(false);
            requestRef.current = false;
        }
    }, [resolveLocation, mapUser]);

    useEffect(() => {
        if (didInitialFetch.current) return;
        didInitialFetch.current = true;
        fetchNearby({ refresh: true });
    }, [fetchNearby]);

    const stringToColor = useCallback((str: string) => {
        let hash = 0;
        for (let i = 0; i < str.length; i += 1) {
            hash = str.charCodeAt(i) + ((hash << 5) - hash);
        }
        let color = '#';
        for (let i = 0; i < 3; i += 1) {
            const value = (hash >> (i * 8)) & 0xff;
            color += (`00${value.toString(16)}`).slice(-2);
        }
        return color;
    }, []);

    const getPlaceIcon = useCallback((name: string) => ({
        name: 'map-marker',
        color: stringToColor(name),
    }), [stringToColor]);

    const renderBackdrop = useCallback(
        (props: any) => <BottomSheetBackdrop {...props} disappearsOnIndex={-1} appearsOnIndex={0} />,
        []
    );

    const openProfile = useCallback((user: NearbyUser) => {
        setActiveMarkerId(user.id);
        setPressedMarkerId(user.id);
        setPressTick(t => t + 1);
        Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
        setSelectedUser(user);
        requestAnimationFrame(() => {
            profileSheetRef.current?.present();
        });
        setTimeout(() => setPressedMarkerId(null), 180);
    }, []);

    const handleMapRegionChange = useCallback((region: Region) => {
        if (requestRef.current || isProgrammaticMoveRef.current) return;
        setMapRegion(region);
        setActiveMarkerId(null);
        if (mapMoveTimeoutRef.current) clearTimeout(mapMoveTimeoutRef.current);
        mapMoveTimeoutRef.current = setTimeout(() => {
            if (isProgrammaticMoveRef.current || requestRef.current) return;
            isMapInteractingRef.current = false;
            const last = lastFetchCenterRef.current;
            const movedEnough = !last || Math.abs(last.lat - region.latitude) > 0.03 || Math.abs(last.lng - region.longitude) > 0.03;
            if (!movedEnough) return;
            const now = Date.now();
            if (now - lastFetchTimeRef.current < 1200) return;
            lastFetchTimeRef.current = now;
            lastFetchCenterRef.current = { lat: region.latitude, lng: region.longitude };
            setLocation({ lat: region.latitude, lng: region.longitude });
            fetchNearby({ refresh: true, coords: { lat: region.latitude, lng: region.longitude } });
        }, 700);
    }, [fetchNearby]);

    const handleMapRegionStart = useCallback(() => {
        if (isProgrammaticMoveRef.current) return;
        isMapInteractingRef.current = true;
        if (mapMoveTimeoutRef.current) clearTimeout(mapMoveTimeoutRef.current);
    }, []);

    const setProgrammaticRegion = useCallback((next: Region) => {
        isProgrammaticMoveRef.current = true;
        setMapRegion(next);
        mapRef.current?.animateToRegion(next, 250);
        setTimeout(() => {
            isProgrammaticMoveRef.current = false;
        }, 450);
    }, []);

    const zoomTo = useCallback((factor: number) => {
        const region = mapRegion ?? {
            latitude: location?.lat ?? DEFAULT_COORDS.lat,
            longitude: location?.lng ?? DEFAULT_COORDS.lng,
            latitudeDelta: 0.06,
            longitudeDelta: 0.06,
        };
        const next = {
            ...region,
            latitudeDelta: Math.min(120, Math.max(0.002, region.latitudeDelta * factor)),
            longitudeDelta: Math.min(120, Math.max(0.002, region.longitudeDelta * factor)),
        };
        setProgrammaticRegion(next);
    }, [mapRegion, location, setProgrammaticRegion]);

    const openTeleport = useCallback(async () => {
        setTeleportVisible(true);
        setTeleportSearching(false);
        setTeleportQuery('');
        setTeleportPlaces([]);
        setTeleportNextPage(null);
        const coords = await resolveLocation();
        const region = {
            latitude: coords.lat,
            longitude: coords.lng,
            latitudeDelta: 0.02,
            longitudeDelta: 0.02,
        };
        setTeleportRegion(region);
        teleportSheetRef.current?.present();
    }, [resolveLocation]);

    const handleTeleportTo = useCallback((lat: number, lng: number) => {
        const region = {
            latitude: lat,
            longitude: lng,
            latitudeDelta: 0.02,
            longitudeDelta: 0.02,
        };
        setLocation({ lat, lng });
        lastFetchCenterRef.current = { lat, lng };
        setProgrammaticRegion(region);
        fetchNearby({ refresh: true, coords: { lat, lng } });
        teleportSheetRef.current?.dismiss();
    }, [fetchNearby, setProgrammaticRegion]);

    const fetchTeleportPlaces = useCallback(async (lat: number, lon: number, query: string = '', pageToken: string = '') => {
        if (teleportLoading && !pageToken) return;
        setTeleportLoading(true);
        try {
            const q = query.trim();
            let url = '';
            if (q) {
                url = `https://maps.googleapis.com/maps/api/place/textsearch/json?query=${encodeURIComponent(q)}&key=${GOOGLE_PLACES_KEY}`;
                url += `&location=${lat},${lon}&radius=200000`;
            } else {
                url = `https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${lat},${lon}&radius=2000&key=${GOOGLE_PLACES_KEY}`;
                url += `&type=point_of_interest`;
            }
            if (pageToken) {
                url += `&pagetoken=${pageToken}`;
                await new Promise(resolve => setTimeout(resolve, 1200));
            }
            const response = await fetch(url);
            const data = await response.json();
            if (data.status === 'OK' || data.status === 'ZERO_RESULTS') {
                const newPlaces = (data.results || []).map((p: any) => ({
                    id: p.place_id || p.name || Math.random().toString(36),
                    name: p.name || '',
                    address: p.vicinity || p.formatted_address || '',
                    lat: p.geometry?.location?.lat,
                    lng: p.geometry?.location?.lng,
                }));
                setTeleportPlaces(prev => pageToken ? [...prev, ...newPlaces] : newPlaces);
                setTeleportNextPage(data.next_page_token || null);
            }
        } catch (error) {
            console.log('Teleport places error', error);
        } finally {
            setTeleportLoading(false);
        }
    }, [teleportLoading]);

    useEffect(() => {
        if (!teleportVisible) return;
        const region = teleportRegion;
        if (!region) return;
        const timer = setTimeout(() => {
            fetchTeleportPlaces(region.latitude, region.longitude, teleportQuery, '');
        }, 500);
        return () => clearTimeout(timer);
    }, [teleportVisible, teleportRegion, teleportQuery, fetchTeleportPlaces]);

    const goToChat = useCallback((user: NearbyUser) => {
        Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
        (navigation as any).navigate('ChatDetail', {
            chatId: user.id,
            name: user.displayname || user.username,
            username: user.username,
            avatar: user.imageUrl,
            status: user.online ? 'online' : `${user.distance} km away`,
            profile: encodeProfileParam(user.raw ?? user),
        });
    }, [navigation]);

    const handleLike = useCallback((id: string) => {
        Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    }, []);

    const handleDislike = useCallback((id: string) => {
        Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
        setUsers(prev => prev.filter(u => u.id !== id));
    }, []);

    const handleMyLocation = async () => {
        try {
            const { status } = await Location.requestForegroundPermissionsAsync();
            if (status !== 'granted') {
                setLocation(DEFAULT_COORDS);
                return;
            }
            const loc = await Location.getCurrentPositionAsync({ accuracy: Location.Accuracy.Balanced });
            const coords = { lat: loc.coords.latitude, lng: loc.coords.longitude };
            setLocation(coords);
            setMapRegion({
                latitude: coords.lat,
                longitude: coords.lng,
                latitudeDelta: 0.015,
                longitudeDelta: 0.015,
            });
            mapRef.current?.animateToRegion({
                latitude: coords.lat,
                longitude: coords.lng,
                latitudeDelta: 0.015,
                longitudeDelta: 0.015,
            });
        } catch {
            const fallback = await Location.getLastKnownPositionAsync({});
            const coords = fallback?.coords
                ? { lat: fallback.coords.latitude, lng: fallback.coords.longitude }
                : DEFAULT_COORDS;
            setLocation(coords);
            setMapRegion({
                latitude: coords.lat,
                longitude: coords.lng,
                latitudeDelta: 0.015,
                longitudeDelta: 0.015,
            });
            mapRef.current?.animateToRegion({
                latitude: coords.lat,
                longitude: coords.lng,
                latitudeDelta: 0.015,
                longitudeDelta: 0.015,
            });
        }
    };

    const handleLoadMore = useCallback(() => {
        if (loading || loadingMore || refreshing) return;
        if (!cursor) return;
        fetchNearby();
    }, [loading, loadingMore, refreshing, cursor, fetchNearby]);

    const renderGridItem = useCallback(({ item }: { item: NearbyUser }) => (
        <GridCard user={item} dark={dark} cols={gridCols} onPress={() => openProfile(item)} blurPhotos={blurPhotos} />
    ), [dark, gridCols, blurPhotos, openProfile]);

    const renderListItem = useCallback(({ item }: { item: NearbyUser }) => (
        <ListRow
            user={item} dark={dark} colors={colors}
            onChat={() => goToChat(item)}
            onLike={() => handleLike(item.id)}
            onDislike={() => handleDislike(item.id)}
            onProfile={() => openProfile(item)}
            blurPhotos={blurPhotos}
        />
    ), [dark, colors, goToChat, handleLike, handleDislike, blurPhotos, openProfile]);

    const VIEW_ICONS: { key: ViewModeType; icon: string }[] = [
        { key: 'grid', icon: 'view-grid' },
        { key: 'list', icon: 'format-list-bulleted' },
        { key: 'map',  icon: 'map-outline' },
    ];

    const GRID_OPTIONS: { cols: GridColsType; icon: string }[] = [
        { cols: 2, icon: 'view-column' },
        { cols: 3, icon: 'view-grid' },
        { cols: 4, icon: 'view-comfy' },
    ];

    const initialRegion = {
        latitude: location?.lat ?? DEFAULT_COORDS.lat,
        longitude: location?.lng ?? DEFAULT_COORDS.lng,
        latitudeDelta: 0.06,
        longitudeDelta: 0.06,
    };

    useEffect(() => {
        if (!mapRegion) {
            setMapRegion(initialRegion);
        }
    }, [mapRegion, initialRegion]);

    useEffect(() => {
        if (!location || !mapRegion) return;
        if (Math.abs(mapRegion.latitude - location.lat) < 0.000001 && Math.abs(mapRegion.longitude - location.lng) < 0.000001) {
            return;
        }
        const next = {
            ...mapRegion,
            latitude: location.lat,
            longitude: location.lng,
        };
        setProgrammaticRegion(next);
    }, [location, mapRegion, setProgrammaticRegion]);

    return (
        <View style={[styles.container, { backgroundColor: colors.background }]}>
            <StatusBar barStyle={dark ? 'light-content' : 'dark-content'} />

            {/* ── Sub-Header (always rendered below GlobalHeader) ── */}
            <View style={[styles.subHeader, { paddingTop: contentPaddingTop + 6, borderBottomColor: borderColor, backgroundColor: colors.background }]}>
                <View style={styles.subRow}>
                    {/* Title */}
                    <View style={{ flex: 1 }}>
                        <Text style={[styles.title, { color: colors.text }]}>Nearby</Text>
                        <Text style={[styles.subtitle, { color: dark ? '#666' : '#AAA' }]}>
                        {users.length} people nearby
                        </Text>
                    </View>

                    {/* Controls */}
                    <View style={styles.controls}>
                        {/* Grid column selector — only shown in grid mode */}
                        {viewMode === 'grid' && (
                            <View style={[styles.toggle, { backgroundColor: toggleBg, borderColor }]}>
                                {GRID_OPTIONS.map(({ cols, icon }) => {
                                    const active = gridCols === cols;
                                    return (
                                        <TouchableOpacity
                                            key={cols}
                                            onPress={() => { setGridCols(cols); Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light); }}
                                            activeOpacity={0.8}
                                            style={[styles.toggleBtn, active && { backgroundColor: dark ? '#FFF' : '#000' }]}
                                        >
                                            <MaterialCommunityIcons
                                                name={icon as any}
                                                size={16}
                                                color={active ? (dark ? '#000' : '#FFF') : (dark ? '#666' : '#AAA')}
                                            />
                                        </TouchableOpacity>
                                    );
                                })}
                            </View>
                        )}

                        {/* View mode selector */}
                        <View style={[styles.toggle, { backgroundColor: toggleBg, borderColor }]}>
                            {VIEW_ICONS.map(({ key, icon }) => {
                                const active = viewMode === key;
                                return (
                                    <TouchableOpacity
                                        key={key}
                                        onPress={() => { setViewMode(key); Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light); }}
                                        activeOpacity={0.8}
                                        style={[styles.toggleBtn, active && { backgroundColor: dark ? '#FFF' : '#000' }]}
                                    >
                                        <MaterialCommunityIcons
                                            name={icon as any}
                                            size={16}
                                            color={active ? (dark ? '#000' : '#FFF') : (dark ? '#666' : '#AAA')}
                                        />
                                    </TouchableOpacity>
                                );
                            })}
                        </View>
                    </View>
                </View>
            </View>

            {/* ── Content ── */}
            <View style={[styles.content, { paddingBottom: TAB_BAR_HEIGHT }]}>

                {/* GRID */}
                {viewMode === 'grid' && (
                    <FlatList
                        key={`grid-${gridCols}`}   // re-mount when columns change
                        data={users}
                        keyExtractor={u => u.id}
                        renderItem={renderGridItem}
                        numColumns={gridCols}
                        refreshing={refreshing}
                        onRefresh={() => fetchNearby({ refresh: true })}
                        onEndReached={handleLoadMore}
                        onEndReachedThreshold={0.5}
                        showsVerticalScrollIndicator={false}
                        contentContainerStyle={{ padding: H_PAD, paddingBottom: 24, gap: GRID_GAP }}
                        columnWrapperStyle={{ gap: GRID_GAP }}
                        removeClippedSubviews
                        maxToRenderPerBatch={8}
                        windowSize={5}
                    />
                )}

                {/* LIST */}
                {viewMode === 'list' && (
                    <FlatList
                        data={users}
                        keyExtractor={u => u.id}
                        renderItem={renderListItem}
                        refreshing={refreshing}
                        onRefresh={() => fetchNearby({ refresh: true })}
                        onEndReached={handleLoadMore}
                        onEndReachedThreshold={0.5}
                        showsVerticalScrollIndicator={false}
                        contentContainerStyle={{ paddingBottom: 24 }}
                        removeClippedSubviews
                        maxToRenderPerBatch={10}
                    />
                )}

                {/* MAP */}
                {viewMode === 'map' && (
                    <View style={{ flex: 1 }}>
                        <MapView
                            ref={mapRef}
                            style={StyleSheet.absoluteFill}
                            provider={PROVIDER_GOOGLE}
                            showsUserLocation
                            showsMyLocationButton={false}
                            region={mapRegion ?? initialRegion}
                            onRegionChange={handleMapRegionStart}
                            onRegionChangeComplete={handleMapRegionChange}
                        >
                            {users.map(u => (
                                <Marker
                                    key={u.id}
                                    coordinate={{ latitude: u.lat, longitude: u.lng }}
                                    onPress={() => openProfile(u)}
                                    tracksViewChanges={false}
                                >
                                    <MapPin
                                        user={u}
                                        dark={dark}
                                        blurPhotos={blurPhotos}
                                        isActive={activeMarkerId === u.id}
                                        isPressed={pressedMarkerId === u.id}
                                        pressTick={pressTick}
                                    />
                                </Marker>
                            ))}
                        </MapView>
                        <TouchableOpacity
                            style={[styles.myLocBtn, { backgroundColor: stylesVars.mapBtnBg, borderColor: stylesVars.mapBtnBorder }]}
                            onPress={handleMyLocation}
                            activeOpacity={0.85}
                            hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
                        >
                            <BlurView intensity={stylesVars.mapBtnBlurIntensity} tint={stylesVars.mapBtnBlurTint} style={StyleSheet.absoluteFill} />
                            <MaterialCommunityIcons name="crosshairs-gps" size={22} color={stylesVars.mapBtnIcon} />
                        </TouchableOpacity>
                        <View style={styles.mapControls}>
                            <TouchableOpacity
                                style={[styles.mapCtrlBtn, { backgroundColor: stylesVars.mapBtnBg, borderColor: stylesVars.mapBtnBorder }]}
                                onPress={() => zoomTo(0.6)}
                                activeOpacity={0.85}
                                hitSlop={{ top: 6, bottom: 6, left: 6, right: 6 }}
                            >
                                <BlurView intensity={stylesVars.mapBtnBlurIntensity} tint={stylesVars.mapBtnBlurTint} style={StyleSheet.absoluteFill} />
                                <MaterialCommunityIcons name="plus" size={20} color={stylesVars.mapBtnIcon} />
                            </TouchableOpacity>
                            <TouchableOpacity
                                style={[styles.mapCtrlBtn, { backgroundColor: stylesVars.mapBtnBg, borderColor: stylesVars.mapBtnBorder }]}
                                onPress={() => zoomTo(1.6)}
                                activeOpacity={0.85}
                                hitSlop={{ top: 6, bottom: 6, left: 6, right: 6 }}
                            >
                                <BlurView intensity={stylesVars.mapBtnBlurIntensity} tint={stylesVars.mapBtnBlurTint} style={StyleSheet.absoluteFill} />
                                <MaterialCommunityIcons name="minus" size={20} color={stylesVars.mapBtnIcon} />
                            </TouchableOpacity>
                            <TouchableOpacity
                                style={[styles.mapCtrlBtn, { backgroundColor: stylesVars.mapBtnBg, borderColor: stylesVars.mapBtnBorder }]}
                                onPress={openTeleport}
                                activeOpacity={0.85}
                                hitSlop={{ top: 6, bottom: 6, left: 6, right: 6 }}
                            >
                                <BlurView intensity={stylesVars.mapBtnBlurIntensity} tint={stylesVars.mapBtnBlurTint} style={StyleSheet.absoluteFill} />
                                <MaterialCommunityIcons name="map-marker-radius" size={20} color={stylesVars.mapBtnIcon} />
                            </TouchableOpacity>
                        </View>
                    </View>
                )}
            </View>

            {/* ── Profile Bottom Sheet ── */}
            <BaseBottomSheetModal
                ref={profileSheetRef}
                index={0}
                snapPoints={['92%']}
                enableDynamicSizing={false}
                backdropComponent={renderBackdrop}
                onDismiss={() => setSelectedUser(null)}
                backgroundStyle={{ backgroundColor: dark ? '#000' : '#FFF' }}
                handleIndicatorStyle={{ backgroundColor: dark ? '#333' : '#E0E0E0' }}
            >
                {resolvedProfileUser && (
                    <FullProfileView
                        user={resolvedProfileUser}
                        isMe={false}
                        useBottomSheetScroll
                        onMessage={() => {
                            profileSheetRef.current?.dismiss();
                            if (selectedUser) goToChat(selectedUser);
                        }}
                        onFollow={() => {
                            if (selectedUser) handleLike(selectedUser.id);
                        }}
                        onBlock={async () => {
                            const targetId = resolvedProfileUser?.public_id || resolvedProfileUser?.id;
                            if (targetId) await api.toggleBlockUser(String(targetId));
                        }}
                    />
                )}
            </BaseBottomSheetModal>

            {/* ── Teleport Sheet ── */}
            <BaseBottomSheetModal
                ref={teleportSheetRef}
                index={0}
                snapPoints={['90%']}
                enableDynamicSizing={false}
                backdropComponent={renderBackdrop}
                onDismiss={() => { setTeleportVisible(false); setTeleportSearching(false); }}
                backgroundStyle={{ backgroundColor: dark ? '#000' : '#FFF' }}
                handleIndicatorStyle={{ backgroundColor: dark ? '#333' : '#E0E0E0' }}
            >
                <BottomSheetFlatList
                    data={teleportPlaces}
                    keyExtractor={(item: any, index: number) => `${item.id ?? item.name}-${index}`}
                    contentContainerStyle={{ paddingBottom: insets.bottom + 24 }}
                    keyboardShouldPersistTaps="handled"
                    onEndReached={() => {
                        if (teleportNextPage && !teleportLoading && teleportRegion) {
                            fetchTeleportPlaces(teleportRegion.latitude, teleportRegion.longitude, teleportQuery, teleportNextPage);
                        }
                    }}
                    onEndReachedThreshold={0.5}
                    renderItem={({ item }: { item: any }) => {
                        const icon = getPlaceIcon(item.name || '');
                        return (
                            <TouchableOpacity
                                style={[styles.teleportPlaceItem, { borderBottomColor: dark ? '#1A1A1A' : '#F0F0F0' }]}
                                onPress={() => {
                                    if (item.lat && item.lng) handleTeleportTo(item.lat, item.lng);
                                }}
                            >
                                <View style={[styles.teleportPlaceIcon, { backgroundColor: icon.color }]}>
                                    <MaterialCommunityIcons name={icon.name as any} size={18} color="#FFF" />
                                </View>
                                <View style={styles.teleportPlaceText}>
                                    <Text style={[styles.teleportPlaceName, { color: colors.text }]} numberOfLines={1}>{item.name}</Text>
                                    <Text style={[styles.teleportPlaceAddr, { color: dark ? '#777' : '#888' }]} numberOfLines={1}>{item.address}</Text>
                                </View>
                            </TouchableOpacity>
                        );
                    }}
                    ListHeaderComponent={
                        <View style={{ backgroundColor: colors.background }}>
                            <View style={[styles.teleportHeader, { borderBottomColor: dark ? '#1A1A1A' : '#EEE' }]}>
                                {teleportSearching ? (
                                    <View style={styles.teleportSearchRow}>
                                        <TouchableOpacity onPress={() => { setTeleportSearching(false); setTeleportQuery(''); }}>
                                            <Ionicons name="arrow-back" size={22} color={colors.text} />
                                        </TouchableOpacity>
                                        <TextInput
                                            autoFocus
                                            style={[styles.teleportSearchInput, { color: colors.text }]}
                                            placeholder="Search places..."
                                            placeholderTextColor={dark ? '#666' : '#999'}
                                            value={teleportQuery}
                                            onChangeText={setTeleportQuery}
                                        />
                                        {teleportLoading && <ActivityIndicator size="small" color={dark ? '#777' : '#999'} style={{ marginRight: 6 }} />}
                                        {teleportQuery.length > 0 && (
                                            <TouchableOpacity onPress={() => setTeleportQuery('')}>
                                                <Ionicons name="close-circle" size={18} color={dark ? '#777' : '#888'} />
                                            </TouchableOpacity>
                                        )}
                                    </View>
                                ) : (
                                    <>
                                        <TouchableOpacity onPress={() => teleportSheetRef.current?.dismiss()}>
                                            <Ionicons name="close" size={26} color={colors.text} />
                                        </TouchableOpacity>
                                        <Text style={[styles.teleportTitle, { color: colors.text }]}>Teleport</Text>
                                        <TouchableOpacity onPress={() => setTeleportSearching(true)}>
                                            <Ionicons name="search" size={22} color={colors.text} />
                                        </TouchableOpacity>
                                    </>
                                )}
                            </View>

                            <View style={styles.teleportMapContainer}>
                                {teleportRegion ? (
                                    <MapView
                                        provider={PROVIDER_GOOGLE}
                                        style={{ flex: 1 }}
                                        region={teleportRegion}
                                        onRegionChangeComplete={setTeleportRegion}
                                        showsUserLocation
                                        showsMyLocationButton={false}
                                    />
                                ) : (
                                    <ActivityIndicator style={{ flex: 1 }} />
                                )}
                                <View style={styles.teleportMarkerFixed}>
                                    <View style={styles.teleportMarkerCircle} />
                                    <View style={styles.teleportMarkerDot} />
                                </View>
                            </View>

                            <TouchableOpacity
                                style={[styles.teleportActionRow, { borderBottomColor: dark ? '#1A1A1A' : '#F0F0F0' }]}
                                onPress={() => {
                                    if (teleportRegion) {
                                        handleTeleportTo(teleportRegion.latitude, teleportRegion.longitude);
                                    }
                                }}
                            >
                                <View style={[styles.teleportActionIcon, { backgroundColor: '#007AFF' }]}>
                                    <MaterialCommunityIcons name="map-marker-check" size={20} color="#FFF" />
                                </View>
                                <View style={styles.teleportActionTextCol}>
                                    <Text style={[styles.teleportActionTitle, { color: colors.text }]}>Teleport to this area</Text>
                                    <Text style={[styles.teleportActionSub, { color: dark ? '#777' : '#888' }]}>Moves map center and refreshes nearby</Text>
                                </View>
                            </TouchableOpacity>

                            <View style={[styles.teleportDivider, { borderColor: dark ? '#1A1A1A' : '#EEE' }]}>
                                <Text style={styles.teleportDividerText}>OR CHOOSE A PLACE</Text>
                            </View>
                        </View>
                    }
                    ListEmptyComponent={
                        teleportLoading ? (
                            <View style={{ padding: 30, alignItems: 'center' }}>
                                <ActivityIndicator size="small" color={dark ? '#777' : '#999'} />
                            </View>
                        ) : (
                            <View style={{ padding: 30, alignItems: 'center' }}>
                                <Text style={{ color: dark ? '#777' : '#888' }}>No places found</Text>
                            </View>
                        )
                    }
                    ListFooterComponent={
                        teleportLoading && teleportPlaces.length > 0 ? (
                            <View style={{ padding: 20, alignItems: 'center' }}>
                                <ActivityIndicator size="small" color={dark ? '#777' : '#999'} />
                            </View>
                        ) : null
                    }
                    stickyHeaderIndices={[0]}
                />
            </BaseBottomSheetModal>
        </View>
    );
}

/* ────────────────── STYLES ────────────────── */
const styles = StyleSheet.create({
    container: { flex: 1 },

    // Sub-header
    subHeader: { paddingHorizontal: 16, paddingBottom: 12, borderBottomWidth: StyleSheet.hairlineWidth, zIndex: 5 },
    subRow: { flexDirection: 'row', alignItems: 'center', gap: 10 },
    title: { fontSize: 22, fontFamily: 'Outfit-Black', letterSpacing: -0.4 },
    subtitle: { fontSize: 11, fontFamily: 'Inter-Medium', marginTop: 1 },
    controls: { flexDirection: 'row', gap: 6 },
    toggle: { flexDirection: 'row', borderRadius: 10, borderWidth: StyleSheet.hairlineWidth, padding: 3, gap: 2 },
    toggleBtn: { width: 30, height: 30, borderRadius: 7, alignItems: 'center', justifyContent: 'center' },

    // Content
    content: { flex: 1 },

    // Grid card
    gridCard: { borderRadius: 14, overflow: 'hidden', backgroundColor: '#111' },
    gridGrad: { position: 'absolute', bottom: 0, left: 0, right: 0, paddingHorizontal: 9, paddingVertical: 10 },
    gridName: { color: '#FFF', fontFamily: 'Inter-Bold' },
    gridDistRow: { flexDirection: 'row', alignItems: 'center', gap: 2, marginTop: 3 },
    gridDistText: { color: 'rgba(255,255,255,0.72)', fontFamily: 'Inter-Medium' },
    onlineDot: { position: 'absolute', top: 8, right: 8, width: 9, height: 9, borderRadius: 5, backgroundColor: '#34C759', borderWidth: 2, borderColor: '#FFF' },

    // List
    listRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: 11, paddingHorizontal: 16, borderBottomWidth: StyleSheet.hairlineWidth },
    listAvatar: { width: 54, height: 54, borderRadius: 15 },
    listOnlineDot: { position: 'absolute', bottom: -1, right: -1, width: 13, height: 13, borderRadius: 6.5, backgroundColor: '#34C759', borderWidth: 2 },
    listInfo: { flex: 1, marginLeft: 12 },
    listName: { fontSize: 15, fontFamily: 'Inter-Bold' },
    listMeta: { flexDirection: 'row', alignItems: 'center', gap: 3, marginTop: 3 },
    listMetaText: { fontSize: 12, fontFamily: 'Inter-Regular' },
    listActions: { flexDirection: 'row', gap: 7, marginLeft: 8 },
    actionBtn: { width: 44, height: 44, borderRadius: 12, alignItems: 'center', justifyContent: 'center' },
    actionBtnPrimary: { width: 44, height: 44, borderRadius: 12, alignItems: 'center', justifyContent: 'center' },

    // Map
    pinWrap: { alignItems: 'center', justifyContent: 'center', shadowColor: '#000', shadowOffset: { width: 0, height: 3 }, shadowOpacity: 0.18, shadowRadius: 6, elevation: 6 },
    pinRing: { width: 56, height: 56, borderRadius: 28, borderWidth: 2.5, overflow: 'hidden', padding: 2.5, backgroundColor: '#111' },
    pinImg: { width: '100%', height: '100%', borderRadius: 24 },
    pinOnline: { position: 'absolute', bottom: -1, right: -1, width: 14, height: 14, borderRadius: 7, backgroundColor: '#34C759', borderWidth: 2.5 },
    myLocBtn: { position: 'absolute', bottom: 28, right: 16, width: 54, height: 54, borderRadius: 27, alignItems: 'center', justifyContent: 'center', borderWidth: 1, elevation: 8, zIndex: 10, overflow: 'hidden', shadowColor: '#000', shadowOffset: { width: 0, height: 4 }, shadowOpacity: 0.22, shadowRadius: 8 },
    mapControls: { position: 'absolute', bottom: 96, right: 16, gap: 10, zIndex: 10 },
    mapCtrlBtn: { width: 54, height: 54, borderRadius: 27, alignItems: 'center', justifyContent: 'center', borderWidth: 1, elevation: 6, overflow: 'hidden', shadowColor: '#000', shadowOffset: { width: 0, height: 3 }, shadowOpacity: 0.18, shadowRadius: 6 },

    // Teleport
    teleportHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 16, height: 52, borderBottomWidth: StyleSheet.hairlineWidth },
    teleportTitle: { fontSize: 16, fontFamily: 'Inter-Bold' },
    teleportSearchRow: { flex: 1, flexDirection: 'row', alignItems: 'center', gap: 10 },
    teleportSearchInput: { flex: 1, height: 40, fontSize: 16 },
    teleportMapContainer: { height: 260, width: '100%', position: 'relative' },
    teleportMarkerFixed: { position: 'absolute', top: '50%', left: '50%', marginLeft: -15, marginTop: -15, width: 30, height: 30, justifyContent: 'center', alignItems: 'center', pointerEvents: 'none' },
    teleportMarkerCircle: { width: 30, height: 30, borderRadius: 15, backgroundColor: 'rgba(0,122,255,0.15)', borderWidth: 1, borderColor: 'rgba(0,122,255,0.4)' },
    teleportMarkerDot: { width: 8, height: 8, borderRadius: 4, backgroundColor: '#007AFF', position: 'absolute', borderWidth: 2, borderColor: '#FFF' },
    teleportActionRow: { flexDirection: 'row', padding: 16, alignItems: 'center', borderBottomWidth: StyleSheet.hairlineWidth },
    teleportActionIcon: { width: 46, height: 46, borderRadius: 23, alignItems: 'center', justifyContent: 'center', marginRight: 14 },
    teleportActionTextCol: { flex: 1 },
    teleportActionTitle: { fontSize: 16, fontFamily: 'Inter-SemiBold' },
    teleportActionSub: { fontSize: 13, fontFamily: 'Inter-Regular', marginTop: 2 },
    teleportDivider: { backgroundColor: '#F8F8F8', paddingHorizontal: 16, paddingVertical: 8, borderTopWidth: StyleSheet.hairlineWidth, borderBottomWidth: StyleSheet.hairlineWidth },
    teleportDividerText: { fontSize: 11, fontFamily: 'Inter-Bold', color: '#999', letterSpacing: 0.5 },
    teleportPlaceItem: { flexDirection: 'row', padding: 12, alignItems: 'center', borderBottomWidth: StyleSheet.hairlineWidth },
    teleportPlaceIcon: { width: 36, height: 36, borderRadius: 18, alignItems: 'center', justifyContent: 'center', marginRight: 12 },
    teleportPlaceText: { flex: 1 },
    teleportPlaceName: { fontSize: 15, fontFamily: 'Inter-SemiBold' },
    teleportPlaceAddr: { fontSize: 12, fontFamily: 'Inter-Regular', marginTop: 2 },

});
