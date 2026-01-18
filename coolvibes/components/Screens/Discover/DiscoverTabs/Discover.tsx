import React, { useCallback, useRef, useState, useEffect, useMemo } from 'react';
import { View, StyleSheet, ScrollView, Image, TouchableOpacity, Dimensions, Animated, Easing, LayoutAnimation, Platform, UIManager, KeyboardAvoidingView } from 'react-native';
import { FlashList } from '@shopify/flash-list';
const MasonryFlashListAny: any = FlashList;

import { useNavigation } from '@react-navigation/native';
import { useAppDispatch, useAppSelector } from '@/store/hooks';
import { fetchNearbyPlaces, resetPlaces } from '@/store/slice/places';
import { PlaceItem } from './PlaceItem';
import { Constants } from '@/constants/Constants';
import { getCurrentLocation } from '@/utils/location';


if (Platform.OS === 'android') {
    if (UIManager.setLayoutAnimationEnabledExperimental) {
        UIManager.setLayoutAnimationEnabledExperimental(true);
    }
}





export default function DiscoverTab() {
    const navigation = useNavigation();
    const dispatch = useAppDispatch();
    const { places, loading, cursor, error } = useAppSelector(
        (state) => state.nearbyPlaces
    );
    const locationRef = useRef<{ latitude: number; longitude: number } | null>(null);
    useEffect(() => {
        loadPlaces();
    }, [dispatch]);


    const loadPlaces = useCallback(async () => {
        try {
            dispatch(resetPlaces());

            const location = await getCurrentLocation();
            locationRef.current = location;

            dispatch(
                fetchNearbyPlaces({
                    latitude: location.latitude,
                    longitude: location.longitude,
                    limit: Constants.defaultLimit,
                })
            );
        } catch (e) {
            console.log('Location error', e);
        }
    }, [dispatch]);

    const loadMorePlaces = useCallback(() => {
        if (loading) return;
        if (!cursor) return;
        if (!locationRef.current) return;

        dispatch(
            fetchNearbyPlaces({
                latitude: locationRef.current.latitude,
                longitude: locationRef.current.longitude,
                limit: Constants.defaultLimit,
                cursor: cursor,
            })
        );
    }, [dispatch, loading, cursor]);

    useEffect(() => {
    }, [places, loading, error]);




    return (
        <View style={styles.container}>

            <MasonryFlashListAny
                style={{ flex: 1 }}
                data={places}
                numColumns={1}
                masonry
                onEndReached={loadMorePlaces}
                onEndReachedThreshold={0.5}
                estimatedItemSize={160}
                keyExtractor={(i: { id: string }) => i.id}
                renderItem={({ item, index }: any) => (
                    <PlaceItem key={`placeItem${index}`} item={item} />
                )}
                showsVerticalScrollIndicator={false}
                contentContainerStyle={{ paddingHorizontal: 4, paddingTop: 4 }}
            />
        </View>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
    },
});