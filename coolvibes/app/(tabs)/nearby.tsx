import React, { useState, useRef, useCallback } from 'react';
import {
    View,
    Text,
    StyleSheet,
    TouchableOpacity,
    FlatList,
    Dimensions,
    StatusBar,
    Platform,
    Modal,
    ScrollView,
} from 'react-native';
import { useTheme } from '@react-navigation/native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { LinearGradient } from 'expo-linear-gradient';
import MapView, { Marker, PROVIDER_GOOGLE } from 'react-native-maps';
import * as Location from 'expo-location';
import * as Haptics from 'expo-haptics';
import { useNavigation } from '@react-navigation/native';

const { width, height } = Dimensions.get('window');

const GLOBAL_HEADER_HEIGHT = 60;
const TAB_BAR_HEIGHT = Platform.OS === 'ios' ? 88 : 68;
const H_PAD = 12;
const GRID_GAP = 8;

type ViewModeType = 'grid' | 'list' | 'map';
type GridColsType = 2 | 3 | 4;

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
    { id: 'u1', username: 'ayse_vibes',   displayname: 'Ayşe',   lat: 41.0082, lng: 28.9784, imageUrl: 'https://picsum.photos/seed/nb1/400/600', age: 24, distance: '0.3', online: true },
    { id: 'u2', username: 'memo_cool',    displayname: 'Mehmet', lat: 41.0122, lng: 28.9764, imageUrl: 'https://picsum.photos/seed/nb2/400/600', age: 27, distance: '0.8', online: true },
    { id: 'u3', username: 'can_the_man',  displayname: 'Can',    lat: 41.0052, lng: 28.9854, imageUrl: 'https://picsum.photos/seed/nb3/400/600', age: 25, distance: '1.2', online: false },
    { id: 'u4', username: 'elif_sun',     displayname: 'Elif',   lat: 41.0152, lng: 28.9954, imageUrl: 'https://picsum.photos/seed/nb4/400/600', age: 23, distance: '1.9', online: true },
    { id: 'u5', username: 'zeynep_star',  displayname: 'Zeynep', lat: 41.0252, lng: 28.9654, imageUrl: 'https://picsum.photos/seed/nb5/400/600', age: 26, distance: '2.4', online: false },
    { id: 'u6', username: 'burak_off',    displayname: 'Burak',  lat: 41.0352, lng: 28.9554, imageUrl: 'https://picsum.photos/seed/nb6/400/600', age: 28, distance: '3.1', online: true },
    { id: 'u7', username: 'selin_k',      displayname: 'Selin',  lat: 41.0452, lng: 28.9454, imageUrl: 'https://picsum.photos/seed/nb7/400/600', age: 22, distance: '4.2', online: false },
    { id: 'u8', username: 'cem_x',       displayname: 'Cem',    lat: 41.0182, lng: 28.9884, imageUrl: 'https://picsum.photos/seed/nb8/400/600', age: 30, distance: '4.8', online: true },
    { id: 'u9', username: 'berk_atl',    displayname: 'Berk',   lat: 41.0282, lng: 28.9684, imageUrl: 'https://picsum.photos/seed/nb9/400/600', age: 29, distance: '5.5', online: true },
    { id: 'u10', username: 'naz_k',      displayname: 'Naz',    lat: 41.0382, lng: 28.9784, imageUrl: 'https://picsum.photos/seed/nb10/400/600', age: 21, distance: '6.0', online: false },
    { id: 'u11', username: 'tuna_d',     displayname: 'Tuna',   lat: 41.0482, lng: 28.9884, imageUrl: 'https://picsum.photos/seed/nb11/400/600', age: 33, distance: '6.8', online: true },
    { id: 'u12', username: 'irem_b',     displayname: 'İrem',   lat: 41.0582, lng: 28.9984, imageUrl: 'https://picsum.photos/seed/nb12/400/600', age: 25, distance: '7.1', online: false },
];

/* ── GRID CARD (adapts size + detail based on column count) ── */
const GridCard = React.memo(({
    user, dark, cols, onPress,
}: {
    user: NearbyUser; dark: boolean; cols: GridColsType; onPress: () => void;
}) => {
    const cardW = (width - H_PAD * 2 - GRID_GAP * (cols - 1)) / cols;
    const cardH = cols === 2 ? cardW * 1.45 : cols === 3 ? cardW * 1.5 : cardW * 1.6;
    const nameSize = cols === 2 ? 13 : cols === 3 ? 11 : 9;
    const metaSize = cols === 2 ? 11 : 9;

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
            />
            <LinearGradient
                colors={['transparent', 'rgba(0,0,0,0.82)']}
                style={styles.gridGrad}
            >
                <Text style={[styles.gridName, { fontSize: nameSize }]} numberOfLines={1}>
                    {user.displayname}{cols < 4 ? `, ${user.age}` : ''}
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
    user, dark, colors, onChat, onLike, onDislike, onProfile,
}: {
    user: NearbyUser; dark: boolean; colors: any;
    onChat: () => void; onLike: () => void; onDislike: () => void; onProfile: () => void;
}) => {
    const divider = dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.06)';
    const sub = dark ? '#666' : '#AAA';
    const btnBg = dark ? '#1C1C1C' : '#F0F0F0';

    return (
        <View style={[styles.listRow, { borderBottomColor: divider }]}>
            <TouchableOpacity onPress={onProfile} activeOpacity={0.85}>
                <View>
                    <Image source={{ uri: user.imageUrl }} style={styles.listAvatar} contentFit="cover" />
                    {user.online && <View style={[styles.listOnlineDot, { borderColor: colors.background }]} />}
                </View>
            </TouchableOpacity>

            <TouchableOpacity style={styles.listInfo} onPress={onProfile} activeOpacity={0.7}>
                <Text style={[styles.listName, { color: colors.text }]} numberOfLines={1}>
                    {user.displayname}, {user.age}
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
const MapPin = React.memo(({ user, dark }: { user: NearbyUser; dark: boolean }) => (
    <View>
        <View style={[styles.pinRing, { borderColor: dark ? '#FFF' : '#000' }]}>
            <Image source={{ uri: user.imageUrl }} style={styles.pinImg} contentFit="cover" />
        </View>
        {user.online && <View style={[styles.pinOnline, { borderColor: dark ? '#111' : '#FFF' }]} />}
    </View>
));

/* ════════════════════════ MAIN SCREEN ════════════════════════ */
export default function NearbyScreen() {
    const { colors, dark } = useTheme();
    const insets = useSafeAreaInsets();
    const navigation = useNavigation();
    const mapRef = useRef<MapView>(null);

    const [viewMode, setViewMode] = useState<ViewModeType>('grid');
    const [gridCols, setGridCols] = useState<GridColsType>(2);
    const [users, setUsers] = useState<NearbyUser[]>(MOCK_USERS);
    const [selectedUser, setSelectedUser] = useState<NearbyUser | null>(null);

    const contentPaddingTop = GLOBAL_HEADER_HEIGHT + insets.top;
    const borderColor = dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.07)';
    const toggleBg = dark ? '#111' : '#F0F0F0';

    const goToChat = useCallback((user: NearbyUser) => {
        Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
        (navigation as any).navigate('ChatDetail', {
            chatId: user.id,
            name: user.displayname || user.username,
            avatar: user.imageUrl,
            status: user.online ? 'online' : `${user.distance} km away`,
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
        const { status } = await Location.requestForegroundPermissionsAsync();
        if (status !== 'granted') return;
        const loc = await Location.getCurrentPositionAsync({});
        mapRef.current?.animateToRegion({
            latitude: loc.coords.latitude,
            longitude: loc.coords.longitude,
            latitudeDelta: 0.015,
            longitudeDelta: 0.015,
        });
    };

    const renderGridItem = useCallback(({ item }: { item: NearbyUser }) => (
        <GridCard user={item} dark={dark} cols={gridCols} onPress={() => setSelectedUser(item)} />
    ), [dark, gridCols]);

    const renderListItem = useCallback(({ item }: { item: NearbyUser }) => (
        <ListRow
            user={item} dark={dark} colors={colors}
            onChat={() => goToChat(item)}
            onLike={() => handleLike(item.id)}
            onDislike={() => handleDislike(item.id)}
            onProfile={() => setSelectedUser(item)}
        />
    ), [dark, colors, goToChat, handleLike, handleDislike]);

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
                            initialRegion={{ latitude: 41.0082, longitude: 28.9784, latitudeDelta: 0.06, longitudeDelta: 0.06 }}
                        >
                            {users.map(u => (
                                <Marker
                                    key={u.id}
                                    coordinate={{ latitude: u.lat, longitude: u.lng }}
                                    onPress={() => setSelectedUser(u)}
                                    tracksViewChanges={false}
                                >
                                    <MapPin user={u} dark={dark} />
                                </Marker>
                            ))}
                        </MapView>
                        <TouchableOpacity
                            style={[styles.myLocBtn, { backgroundColor: colors.text }]}
                            onPress={handleMyLocation}
                            activeOpacity={0.85}
                        >
                            <MaterialCommunityIcons name="crosshairs-gps" size={22} color={colors.background} />
                        </TouchableOpacity>
                    </View>
                )}
            </View>

            {/* ── Profile Bottom Sheet ── */}
            {selectedUser !== null && (
                <Modal visible transparent animationType="slide" onRequestClose={() => setSelectedUser(null)}>
                    {/* backdrop tap to close */}
                    <TouchableOpacity
                        style={styles.backdrop}
                        activeOpacity={1}
                        onPress={() => setSelectedUser(null)}
                    />
                    <View style={[styles.sheet, {
                        backgroundColor: dark ? '#0A0A0A' : '#FFF',
                        borderTopColor: borderColor,
                        paddingBottom: insets.bottom + 28,
                    }]}>
                        {/* Handle */}
                        <View style={styles.sheetHandleWrap}>
                            <View style={[styles.sheetHandleBar, { backgroundColor: dark ? 'rgba(255,255,255,0.2)' : 'rgba(0,0,0,0.15)' }]} />
                        </View>

                        <ScrollView showsVerticalScrollIndicator={false}>
                            {/* User row */}
                            <View style={styles.sheetUserRow}>
                                <Image source={{ uri: selectedUser.imageUrl }} style={styles.sheetAvatar} contentFit="cover" />
                                <View style={styles.sheetUserInfo}>
                                    <Text style={[styles.sheetName, { color: colors.text }]}>{selectedUser.displayname}, {selectedUser.age}</Text>
                                    <Text style={[styles.sheetUsername, { color: dark ? '#666' : '#AAA' }]}>@{selectedUser.username}</Text>
                                    <View style={styles.sheetMetaRow}>
                                        <MaterialCommunityIcons name="map-marker-outline" size={12} color={dark ? '#666' : '#AAA'} />
                                        <Text style={[styles.sheetMetaText, { color: dark ? '#666' : '#AAA' }]}>{selectedUser.distance} km</Text>
                                        {selectedUser.online && (
                                            <>
                                                <View style={styles.sheetOnlineDot} />
                                                <Text style={[styles.sheetMetaText, { color: '#34C759' }]}>Online</Text>
                                            </>
                                        )}
                                    </View>
                                </View>
                                <TouchableOpacity
                                    onPress={() => setSelectedUser(null)}
                                    style={[styles.closeBtn, { backgroundColor: dark ? '#1A1A1A' : '#F0F0F0' }]}
                                >
                                    <MaterialCommunityIcons name="close" size={20} color={colors.text} />
                                </TouchableOpacity>
                            </View>

                            {/* Action buttons */}
                            <View style={[styles.sheetActions, { borderTopColor: borderColor }]}>
                                <TouchableOpacity
                                    style={[styles.sheetBtn, { backgroundColor: dark ? '#1A1A1A' : '#F0F0F0' }]}
                                    onPress={() => { handleDislike(selectedUser.id); setSelectedUser(null); }}
                                    activeOpacity={0.8}
                                >
                                    <MaterialCommunityIcons name="close" size={22} color={dark ? '#888' : '#AAA'} />
                                    <Text style={[styles.sheetBtnLabel, { color: dark ? '#888' : '#AAA' }]}>Skip</Text>
                                </TouchableOpacity>

                                <TouchableOpacity
                                    style={[styles.sheetBtn, { backgroundColor: dark ? '#1A1A1A' : '#F0F0F0' }]}
                                    onPress={() => { handleLike(selectedUser.id); }}
                                    activeOpacity={0.8}
                                >
                                    <MaterialCommunityIcons name="heart" size={22} color={colors.text} />
                                    <Text style={[styles.sheetBtnLabel, { color: colors.text }]}>Like</Text>
                                </TouchableOpacity>

                                <TouchableOpacity
                                    style={[styles.sheetBtnPrimary, { backgroundColor: colors.text }]}
                                    onPress={() => { setSelectedUser(null); goToChat(selectedUser!); }}
                                    activeOpacity={0.85}
                                >
                                    <MaterialCommunityIcons name="message-text" size={22} color={colors.background} />
                                    <Text style={[styles.sheetBtnLabel, { color: colors.background }]}>Message</Text>
                                </TouchableOpacity>
                            </View>
                        </ScrollView>
                    </View>
                </Modal>
            )}
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
    pinRing: { width: 48, height: 48, borderRadius: 24, borderWidth: 2.5, overflow: 'hidden', padding: 2 },
    pinImg: { width: '100%', height: '100%', borderRadius: 20 },
    pinOnline: { position: 'absolute', bottom: 0, right: 0, width: 13, height: 13, borderRadius: 6.5, backgroundColor: '#34C759', borderWidth: 2.5 },
    myLocBtn: { position: 'absolute', bottom: 28, right: 16, width: 50, height: 50, borderRadius: 25, alignItems: 'center', justifyContent: 'center', elevation: 8, shadowColor: '#000', shadowOffset: { width: 0, height: 4 }, shadowOpacity: 0.3, shadowRadius: 8 },

    // Bottom Sheet
    backdrop: { ...StyleSheet.absoluteFillObject, backgroundColor: 'rgba(0,0,0,0.55)' },
    sheet: { position: 'absolute', bottom: 0, left: 0, right: 0, borderTopLeftRadius: 26, borderTopRightRadius: 26, borderTopWidth: StyleSheet.hairlineWidth, maxHeight: height * 0.6 },
    sheetHandleWrap: { alignItems: 'center', paddingTop: 12, paddingBottom: 6 },
    sheetHandleBar: { width: 38, height: 4, borderRadius: 2 },
    sheetUserRow: { flexDirection: 'row', alignItems: 'flex-start', paddingHorizontal: 20, paddingTop: 10, paddingBottom: 16, gap: 14 },
    sheetAvatar: { width: 68, height: 68, borderRadius: 16 },
    sheetUserInfo: { flex: 1 },
    sheetName: { fontSize: 17, fontFamily: 'Outfit-Black', letterSpacing: -0.3 },
    sheetUsername: { fontSize: 12, fontFamily: 'Inter-Medium', marginTop: 2 },
    sheetMetaRow: { flexDirection: 'row', alignItems: 'center', gap: 5, marginTop: 6 },
    sheetMetaText: { fontSize: 12, fontFamily: 'Inter-Regular' },
    sheetOnlineDot: { width: 7, height: 7, borderRadius: 3.5, backgroundColor: '#34C759' },
    closeBtn: { width: 34, height: 34, borderRadius: 17, alignItems: 'center', justifyContent: 'center' },
    sheetActions: { flexDirection: 'row', gap: 10, paddingHorizontal: 20, paddingVertical: 16, borderTopWidth: StyleSheet.hairlineWidth },
    sheetBtn: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingVertical: 18, borderRadius: 16, gap: 6 },
    sheetBtnPrimary: { flex: 1.3, alignItems: 'center', justifyContent: 'center', paddingVertical: 18, borderRadius: 16, gap: 6 },
    sheetBtnLabel: { fontSize: 13, fontFamily: 'Inter-Bold' },
});
