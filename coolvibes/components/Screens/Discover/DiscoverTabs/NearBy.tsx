import React, { useCallback, useRef, useState, useEffect, useMemo } from 'react';
import { View, StyleSheet, ScrollView, Image, TouchableOpacity, Dimensions, Animated, Easing, LayoutAnimation, Platform, UIManager, KeyboardAvoidingView } from 'react-native';
import { Colors } from '@/constants/Colors';
import MaterialIcons from '@expo/vector-icons/MaterialIcons';
import { useNavigation } from '@react-navigation/native';
import { useAppDispatch, useAppSelector } from '@/store/hooks';
import { fetchChats, resetChats } from '@/store/slice/chat';
import MapView, { Marker, PROVIDER_GOOGLE } from 'react-native-maps';
import * as Location from 'expo-location';
import * as Haptics from 'expo-haptics';
import { Directions, Gesture, GestureDetector } from 'react-native-gesture-handler';



const mockMapUsers = [
    { id: 'u1', name: 'Ayşe', lat: 41.0082, lng: 28.9784, avatar: 'https://picsum.photos/seed/a/100', color: '#FF2D55' },
    { id: 'u2', name: 'Mehmet', lat: 41.0122, lng: 28.9764, avatar: 'https://picsum.photos/seed/b/100', color: '#5856D6' },
    { id: 'u3', name: 'Can', lat: 41.0052, lng: 28.9854, avatar: 'https://picsum.photos/seed/c/100', color: '#FF9500' },
    { id: 'u4', name: 'Elif', lat: 41.0152, lng: 28.9954, avatar: 'https://picsum.photos/seed/d/100', color: '#AF52DE' },
    { id: 'u5', name: 'Zeynep', lat: 41.0252, lng: 28.9654, avatar: 'https://picsum.photos/seed/e/100', color: '#34C759' },
];

export default function NearBy() {
    const navigation = useNavigation();
    const dispatch = useAppDispatch();
    const mapRef = useRef<MapView>(null);

    const { chats, loading, error, cursor } = useAppSelector(state => state.chat);

    useEffect(() => {
        loadChats();
    }, [dispatch]);

    const loadChats = () => {
        dispatch(resetChats());
        dispatch(fetchChats({ limit: 20 }));
    }

    const loadMoreChats = () => {
        if (!loading && cursor) {
            dispatch(fetchChats({ limit: 20, cursor }));
        }
    };


    useEffect(() => {
        console.log('Chats updated:', { chats, loading, error });
    }, [chats, loading, error]);

    const handleZoomIn = async () => {
        const camera = await mapRef.current?.getCamera();
        if (camera) {
            mapRef.current?.animateCamera({ zoom: (camera.zoom || 15) + 1 });
        }
    };

    const handleZoomOut = async () => {
        const camera = await mapRef.current?.getCamera();
        if (camera) {
            mapRef.current?.animateCamera({ zoom: (camera.zoom || 15) - 1 });
        }
    };

    const handleMyLocation = async () => {
        const { status } = await Location.requestForegroundPermissionsAsync();
        if (status !== 'granted') return;

        const location = await Location.getCurrentPositionAsync({});
        mapRef.current?.animateToRegion({
            latitude: location.coords.latitude,
            longitude: location.coords.longitude,
            latitudeDelta: 0.01,
            longitudeDelta: 0.01,
        });
    };


    return (

        <View style={{ flex: 1 }}>
            <MapView
                ref={mapRef}
                showsUserLocation
                provider={PROVIDER_GOOGLE}
                style={{ flex: 1 }}
                initialRegion={{
                    latitude: 41.0082,
                    longitude: 28.9784,
                    latitudeDelta: 0.0922,
                    longitudeDelta: 0.0421,
                }}
            >
                {mockMapUsers.map(user => (
                    <Marker
                        key={user.id}
                        coordinate={{ latitude: user.lat, longitude: user.lng }}
                        onPress={() => {
                            Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
                            (navigation as any).navigate('ChatDetail', {
                                user: {
                                    id: user.id,
                                    name: user.name,
                                    avatar: user.avatar,
                                },
                            });
                        }}
                    >
                        <View style={styles.markerContainer}>
                            <View style={[styles.markerOuterRing, { backgroundColor: user.color + '50' }]}>
                                <View style={[styles.markerInnerRing, { borderColor: user.color }]}>
                                    <Image source={{ uri: user.avatar }} style={styles.markerAvatar} />
                                    {/* <BlurView intensity={10}  tint="light" style={[StyleSheet.absoluteFill, { borderRadius: 100, overflow:"hidden" }]}  /> */}
                                </View>
                            </View>
                        </View>
                    </Marker>
                ))}
            </MapView>
            <View style={styles.mapControls}>
                <TouchableOpacity style={styles.mapControlBtn} onPress={handleZoomIn}>
                    <MaterialIcons name="add" size={24} color="#fff" />
                </TouchableOpacity>
                <TouchableOpacity style={styles.mapControlBtn} onPress={handleZoomOut}>
                    <MaterialIcons name="remove" size={24} color="#fff" />
                </TouchableOpacity>
                <TouchableOpacity style={[styles.mapControlBtn, { marginTop: 8 }]} onPress={handleMyLocation}>
                    <MaterialIcons name="my-location" size={24} color="#fff" />
                </TouchableOpacity>
            </View>
        </View>

    );
}

const styles = StyleSheet.create({
    markerContainer: {
        alignItems: 'center',
        justifyContent: 'center',
    },
    markerAvatar: {
        width: 50,
        height: 50,
        borderRadius: 100,
    },
    markerOuterRing: {
        padding: 8,
        borderRadius: 100,
    },
    markerInnerRing: {
        borderRadius: 100,
        borderWidth: 3,
    },
    markerBadge: {
        position: 'absolute',
        bottom: 0,
        right: 0,
        width: 14,
        height: 14,
        borderRadius: 7,
        backgroundColor: '#34C759',
        borderWidth: 2,
        borderColor: '#fff',
    },
    mapControls: {
        position: 'absolute',
        top: 16,
        right: 16,
        alignItems: 'center',
    },
    mapControlBtn: {
        width: 44,
        height: 44,
        borderRadius: 22,
        backgroundColor: '#000',
        alignItems: 'center',
        justifyContent: 'center',
        marginBottom: 10,
        shadowColor: "#000",
        shadowOffset: { width: 0, height: 2 },
        shadowOpacity: 0.25,
        shadowRadius: 3.84,
        elevation: 5,
    },
});