import React, { useState, useRef, useCallback } from 'react';
import {
    View,
    Text,
    StyleSheet,
    TouchableOpacity,
    FlatList,
    ScrollView,
    Dimensions,
    StatusBar,
    Platform,
    ActivityIndicator,
} from 'react-native';
import { useTheme } from '@react-navigation/native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import MapView, { Marker, PROVIDER_GOOGLE } from 'react-native-maps';
import * as Location from 'expo-location';
import * as Haptics from 'expo-haptics';
import { useNavigation } from '@react-navigation/native';
import { LinearGradient } from 'expo-linear-gradient';

const { width, height } = Dimensions.get('window');
const GRID_COL = 2;
const GRID_GAP = 10;
const ITEM_WIDTH = (width - 32 - GRID_GAP) / GRID_COL;
const ITEM_HEIGHT = ITEM_WIDTH * 1.35;

type ViewModeType = 'grid' | 'list' | 'map';

interface NearbyUser {
    id: string;
    username: string;
    displayname: string;
    lat: number;
    lng: number;
    imageUrl: string;
    age: number;
    distance: string;
    online: boolean;
}

const MOCK_USERS: NearbyUser[] = [
    { id: 'u1', username: 'ayse_vibes',    displayname: 'Ayşe',    lat: 41.0082, lng: 28.9784, imageUrl: 'https://picsum.photos/seed/aa/400/600', age: 24, distance: '0.3', online: true },
    { id: 'u2', username: 'memo_cool',     displayname: 'Mehmet',  lat: 41.0122, lng: 28.9764, imageUrl: 'https://picsum.photos/seed/bb/400/600', age: 27, distance: '0.8', online: true },
    { id: 'u3', username: 'can_the_man',   displayname: 'Can',     lat: 41.0052, lng: 28.9854, imageUrl: 'https://picsum.photos/seed/cc/400/600', age: 25, distance: '1.2', online: false },
    { id: 'u4', username: 'elif_sun',      displayname: 'Elif',    lat: 41.0152, lng: 28.9954, imageUrl: 'https://picsum.photos/seed/dd/400/600', age: 23, distance: '1.9', online: true },
    { id: 'u5', username: 'zeynep_star',   displayname: 'Zeynep',  lat: 41.0252, lng: 28.9654, imageUrl: 'https://picsum.photos/seed/ee/400/600', age: 26, distance: '2.4', online: false },
    { id: 'u6', username: 'burak_off',     displayname: 'Burak',   lat: 41.0352, lng: 28.9554, imageUrl: 'https://picsum.photos/seed/ff/400/600', age: 28, distance: '3.1', online: true },
    { id: 'u7', username: 'selin_k',       displayname: 'Selin',   lat: 41.0452, lng: 28.9454, imageUrl: 'https://picsum.photos/seed/gg/400/600', age: 22, distance: '4.2', online: false },
    { id: 'u8', username: 'cem_x',        displayname: 'Cem',     lat: 41.0182, lng: 28.9884, imageUrl: 'https://picsum.photos/seed/hh/400/600', age: 30, distance: '4.8', online: true },
];

// --- Sub-components ---

const GridCard = React.memo(({ user, dark, onPress }: { user: NearbyUser; dark: boolean; onPress: () => void }) => (
    <TouchableOpacity onPress={onPress} activeOpacity={0.9} style={styles.gridCard}>
        <Image
            source={{ uri: user.imageUrl }}
            style={styles.gridCardImage}
            contentFit="cover"
            transition={200}
        />
        <LinearGradient
            colors={['transparent', 'rgba(0,0,0,0.75)']}
            style={styles.gridCardGradient}
        >
            <Text style={styles.gridCardName} numberOfLines={1}>{user.displayname}, {user.age}</Text>
            <View style={styles.gridCardMeta}>
                <MaterialCommunityIcons name="map-marker" size={11} color="rgba(255,255,255,0.8)" />
                <Text style={styles.gridCardDist}>{user.distance} km</Text>
            </View>
        </LinearGradient>
        {user.online && <View style={styles.onlineDot} />}
    </TouchableOpacity>
));

const ListRow = React.memo(({ user, dark, colors, onPress }: { user: NearbyUser; dark: boolean; colors: any; onPress: () => void }) => (
    <TouchableOpacity onPress={onPress} activeOpacity={0.7} style={[styles.listRow, { borderBottomColor: dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.06)' }]}>
        <View style={styles.listAvatarWrap}>
            <Image source={{ uri: user.imageUrl }} style={styles.listAvatar} contentFit="cover" />
            {user.online && <View style={styles.listOnlineDot} />}
        </View>
        <View style={styles.listInfo}>
            <Text style={[styles.listName, { color: colors.text }]} numberOfLines={1}>{user.displayname}, {user.age}</Text>
            <View style={styles.listMetaRow}>
                <MaterialCommunityIcons name="map-marker-outline" size={13} color={dark ? '#888' : '#AAA'} />
                <Text style={[styles.listDist, { color: dark ? '#888' : '#AAA' }]}>{user.distance} km uzakta</Text>
            </View>
        </View>
        <View style={[styles.listAction, { backgroundColor: dark ? '#1A1A1A' : '#F5F5F5' }]}>
            <MaterialCommunityIcons name="chevron-right" size={20} color={dark ? '#555' : '#BBB'} />
        </View>
    </TouchableOpacity>
));

const MapMarkerPin = ({ user, dark }: { user: NearbyUser; dark: boolean }) => (
    <View style={styles.mapMarker}>
        <View style={[styles.mapMarkerRing, { borderColor: dark ? '#FFF' : '#000', backgroundColor: dark ? 'rgba(0,0,0,0.4)' : 'rgba(255,255,255,0.4)' }]}>
            <Image source={{ uri: user.imageUrl }} style={styles.mapMarkerImg} contentFit="cover" />
        </View>
        {user.online && <View style={[styles.mapOnlineDot, { borderColor: dark ? '#111' : '#FFF' }]} />}
    </View>
);

// --- Main Screen ---

export default function NearbyScreen() {
    const { colors, dark } = useTheme();
    const insets = useSafeAreaInsets();
    const navigation = useNavigation();
    const mapRef = useRef<MapView>(null);

    const [viewMode, setViewMode] = useState<ViewModeType>('grid');
    const [users] = useState<NearbyUser[]>(MOCK_USERS);

    const borderColor = dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.07)';
    const tabBarHeight = Platform.OS === 'ios' ? 88 : 68;

    const handleUserPress = useCallback((user: NearbyUser) => {
        Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
        (navigation as any).navigate('ChatDetail', { user });
    }, [navigation]);

    const handleMyLocation = async () => {
        const { status } = await Location.requestForegroundPermissionsAsync();
        if (status !== 'granted') return;
        const loc = await Location.getCurrentPositionAsync({});
        mapRef.current?.animateToRegion({
            latitude: loc.coords.latitude,
            longitude: loc.coords.longitude,
            latitudeDelta: 0.01,
            longitudeDelta: 0.01,
        });
    };

    const renderGridItem = useCallback(({ item, index }: { item: NearbyUser; index: number }) => (
        <GridCard user={item} dark={dark} onPress={() => handleUserPress(item)} />
    ), [dark, handleUserPress]);

    const renderListItem = useCallback(({ item }: { item: NearbyUser }) => (
        <ListRow user={item} dark={dark} colors={colors} onPress={() => handleUserPress(item)} />
    ), [dark, colors, handleUserPress]);

    const VIEW_MODES: { key: ViewModeType; icon: string }[] = [
        { key: 'grid', icon: 'view-grid' },
        { key: 'list', icon: 'format-list-bulleted' },
        { key: 'map',  icon: 'map-outline' },
    ];

    return (
        <View style={[styles.container, { backgroundColor: colors.background }]}>
            <StatusBar barStyle={dark ? 'light-content' : 'dark-content'} />

            {/* ── STICKY HEADER ── */}
            <View style={[
                styles.header,
                {
                    paddingTop: insets.top + 52,
                    borderBottomColor: borderColor,
                    backgroundColor: colors.background,
                }
            ]}>
                <View style={styles.headerRow}>
                    {/* Title */}
                    <View>
                        <Text style={[styles.title, { color: colors.text }]}>Nearby</Text>
                        <Text style={[styles.subtitle, { color: dark ? '#666' : '#AAA' }]}>
                            {users.length} kişi keşfedildi
                        </Text>
                    </View>

                    {/* View Mode Toggle */}
                    <View style={[styles.modeToggle, { backgroundColor: dark ? '#111' : '#F2F2F2', borderColor }]}>
                        {VIEW_MODES.map(({ key, icon }) => {
                            const active = viewMode === key;
                            return (
                                <TouchableOpacity
                                    key={key}
                                    onPress={() => {
                                        setViewMode(key);
                                        Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                                    }}
                                    style={[
                                        styles.modeBtn,
                                        active && { backgroundColor: dark ? '#FFF' : '#000' },
                                    ]}
                                    activeOpacity={0.8}
                                >
                                    <MaterialCommunityIcons
                                        name={icon as any}
                                        size={18}
                                        color={active ? (dark ? '#000' : '#FFF') : (dark ? '#666' : '#AAA')}
                                    />
                                </TouchableOpacity>
                            );
                        })}
                    </View>
                </View>
            </View>

            {/* ── CONTENT ── */}
            <View style={[styles.content, { paddingBottom: tabBarHeight }]}>

                {/* MAP */}
                {viewMode === 'map' && (
                    <View style={styles.mapWrap}>
                        <MapView
                            ref={mapRef}
                            style={StyleSheet.absoluteFill}
                            provider={PROVIDER_GOOGLE}
                            showsUserLocation
                            showsMyLocationButton={false}
                            initialRegion={{
                                latitude: 41.0082,
                                longitude: 28.9784,
                                latitudeDelta: 0.06,
                                longitudeDelta: 0.06,
                            }}
                        >
                            {users.map((u) => (
                                <Marker
                                    key={u.id}
                                    coordinate={{ latitude: u.lat, longitude: u.lng }}
                                    onPress={() => handleUserPress(u)}
                                    tracksViewChanges={false}
                                >
                                    <MapMarkerPin user={u} dark={dark} />
                                </Marker>
                            ))}
                        </MapView>

                        {/* My Location */}
                        <TouchableOpacity
                            style={[styles.myLocBtn, { backgroundColor: colors.text }]}
                            onPress={handleMyLocation}
                            activeOpacity={0.85}
                        >
                            <MaterialCommunityIcons name="crosshairs-gps" size={22} color={colors.background} />
                        </TouchableOpacity>
                    </View>
                )}

                {/* GRID */}
                {viewMode === 'grid' && (
                    <FlatList
                        data={users}
                        keyExtractor={(u) => u.id}
                        renderItem={renderGridItem}
                        numColumns={GRID_COL}
                        showsVerticalScrollIndicator={false}
                        contentContainerStyle={styles.gridContent}
                        columnWrapperStyle={styles.gridRow}
                        removeClippedSubviews
                        maxToRenderPerBatch={6}
                        windowSize={5}
                    />
                )}

                {/* LIST */}
                {viewMode === 'list' && (
                    <FlatList
                        data={users}
                        keyExtractor={(u) => u.id}
                        renderItem={renderListItem}
                        showsVerticalScrollIndicator={false}
                        contentContainerStyle={styles.listContent}
                        removeClippedSubviews
                        maxToRenderPerBatch={10}
                        windowSize={7}
                    />
                )}
            </View>
        </View>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
    },

    // ── Header ──
    header: {
        paddingHorizontal: 20,
        paddingBottom: 14,
        borderBottomWidth: StyleSheet.hairlineWidth,
        zIndex: 10,
    },
    headerRow: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
    },
    title: {
        fontSize: 26,
        fontFamily: 'Outfit-Black',
        letterSpacing: -0.5,
    },
    subtitle: {
        fontSize: 12,
        fontFamily: 'Inter-Medium',
        marginTop: 2,
    },
    modeToggle: {
        flexDirection: 'row',
        borderRadius: 12,
        borderWidth: StyleSheet.hairlineWidth,
        padding: 3,
        gap: 2,
    },
    modeBtn: {
        width: 36,
        height: 36,
        borderRadius: 9,
        alignItems: 'center',
        justifyContent: 'center',
    },

    // ── Content ──
    content: {
        flex: 1,
    },

    // ── Grid ──
    gridContent: {
        padding: 16,
        paddingBottom: 24,
    },
    gridRow: {
        justifyContent: 'space-between',
        marginBottom: GRID_GAP,
    },
    gridCard: {
        width: ITEM_WIDTH,
        height: ITEM_HEIGHT,
        borderRadius: 18,
        overflow: 'hidden',
        backgroundColor: '#1A1A1A',
    },
    gridCardImage: {
        width: '100%',
        height: '100%',
    },
    gridCardGradient: {
        position: 'absolute',
        bottom: 0,
        left: 0,
        right: 0,
        paddingHorizontal: 12,
        paddingVertical: 14,
    },
    gridCardName: {
        color: '#FFF',
        fontSize: 14,
        fontFamily: 'Inter-Bold',
    },
    gridCardMeta: {
        flexDirection: 'row',
        alignItems: 'center',
        gap: 3,
        marginTop: 3,
    },
    gridCardDist: {
        color: 'rgba(255,255,255,0.75)',
        fontSize: 11,
        fontFamily: 'Inter-Medium',
    },
    onlineDot: {
        position: 'absolute',
        top: 12,
        right: 12,
        width: 10,
        height: 10,
        borderRadius: 5,
        backgroundColor: '#34C759',
        borderWidth: 2,
        borderColor: '#FFF',
    },

    // ── List ──
    listContent: {
        paddingTop: 4,
        paddingBottom: 24,
    },
    listRow: {
        flexDirection: 'row',
        alignItems: 'center',
        paddingVertical: 12,
        paddingHorizontal: 20,
        borderBottomWidth: StyleSheet.hairlineWidth,
    },
    listAvatarWrap: {
        position: 'relative',
    },
    listAvatar: {
        width: 58,
        height: 58,
        borderRadius: 16,
    },
    listOnlineDot: {
        position: 'absolute',
        bottom: 0,
        right: 0,
        width: 12,
        height: 12,
        borderRadius: 6,
        backgroundColor: '#34C759',
        borderWidth: 2,
        borderColor: '#FFF',
    },
    listInfo: {
        flex: 1,
        marginLeft: 14,
    },
    listName: {
        fontSize: 16,
        fontFamily: 'Inter-Bold',
    },
    listMetaRow: {
        flexDirection: 'row',
        alignItems: 'center',
        gap: 3,
        marginTop: 4,
    },
    listDist: {
        fontSize: 13,
        fontFamily: 'Inter-Regular',
    },
    listAction: {
        width: 36,
        height: 36,
        borderRadius: 10,
        alignItems: 'center',
        justifyContent: 'center',
        marginLeft: 10,
    },

    // ── Map ──
    mapWrap: {
        flex: 1,
    },
    mapMarker: {
        alignItems: 'center',
        justifyContent: 'center',
    },
    mapMarkerRing: {
        width: 52,
        height: 52,
        borderRadius: 26,
        borderWidth: 2.5,
        overflow: 'hidden',
        padding: 2,
    },
    mapMarkerImg: {
        width: '100%',
        height: '100%',
        borderRadius: 22,
    },
    mapOnlineDot: {
        position: 'absolute',
        bottom: 0,
        right: 0,
        width: 13,
        height: 13,
        borderRadius: 6.5,
        backgroundColor: '#34C759',
        borderWidth: 2.5,
    },
    myLocBtn: {
        position: 'absolute',
        bottom: 28,
        right: 20,
        width: 52,
        height: 52,
        borderRadius: 26,
        alignItems: 'center',
        justifyContent: 'center',
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 4 },
        shadowOpacity: 0.3,
        shadowRadius: 8,
        elevation: 8,
    },
});
