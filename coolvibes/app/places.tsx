import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  ActivityIndicator,
  FlatList,
  Pressable,
  RefreshControl,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from 'react-native';
import { useTheme } from '@react-navigation/native';
import { useRouter } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import MaterialCommunityIcons from '@expo/vector-icons/MaterialCommunityIcons';
import MapView, { Marker, PROVIDER_GOOGLE, Region } from 'react-native-maps';
import * as Location from 'expo-location';
import { Image } from 'expo-image';

import { Constants } from '@/constants/Constants';
import {
  extractPlacesResponse,
  filterPlaces,
  getPlaceCategories,
  getPlaceCoordinates,
  getPlaceDescription,
  getPlaceImage,
  getPlaceLocationText,
  getPlacePrimaryTag,
  getPlaceTitle,
} from '@/helpers/places';
import { api } from '@/services/apiService';

type PlacesCursor = {
  next: string | null;
  distance: string | number | null;
} | null;

type Coordinates = {
  latitude: number;
  longitude: number;
};

const ISTANBUL_COORDS: Coordinates = {
  latitude: 41.0082,
  longitude: 28.9784,
};

const MAP_DELTA = {
  latitudeDelta: 0.12,
  longitudeDelta: 0.12,
};

function getPlaceKey(place: any): string {
  return String(place?.public_id ?? place?.id ?? '');
}

export default function PlacesScreen() {
  const { colors, dark } = useTheme();
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const mapRef = useRef<MapView>(null);

  const [viewMode, setViewMode] = useState<'grid' | 'map'>('grid');
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('all');
  const [places, setPlaces] = useState<any[]>([]);
  const [cursor, setCursor] = useState<PlacesCursor>(null);
  const [location, setLocation] = useState<Coordinates | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState('');
  const [isUsingFallbackLocation, setIsUsingFallbackLocation] = useState(false);
  const [selectedPlaceId, setSelectedPlaceId] = useState<string | null>(null);

  const borderColor = dark ? 'rgba(255,255,255,0.08)' : 'rgba(15,23,42,0.08)';
  const mutedText = dark ? 'rgba(255,255,255,0.58)' : 'rgba(15,23,42,0.58)';
  const cardBackground = dark ? 'rgba(255,255,255,0.04)' : '#FFFFFF';
  const surfaceBackground = dark ? 'rgba(255,255,255,0.06)' : '#F8FAFC';

  const categories = useMemo(() => getPlaceCategories(places), [places]);
  const filteredPlaces = useMemo(
    () => filterPlaces(places, selectedCategory, searchQuery),
    [places, searchQuery, selectedCategory]
  );

  const mapPlaces = useMemo(
    () =>
      filteredPlaces
        .map((place) => {
          const coordinates = getPlaceCoordinates(place);
          if (!coordinates) return null;
          return { place, coordinates };
        })
        .filter(Boolean) as { place: any; coordinates: Coordinates }[],
    [filteredPlaces]
  );

  const selectedMapPlace = useMemo(() => {
    if (!selectedPlaceId) return mapPlaces[0]?.place ?? null;
    return mapPlaces.find((entry) => getPlaceKey(entry.place) === selectedPlaceId)?.place ?? mapPlaces[0]?.place ?? null;
  }, [mapPlaces, selectedPlaceId]);

  const mapRegion = useMemo<Region>(() => {
    const selectedCoordinates = selectedMapPlace ? getPlaceCoordinates(selectedMapPlace) : null;
    const center = selectedCoordinates ?? location ?? ISTANBUL_COORDS;
    return {
      latitude: center.latitude,
      longitude: center.longitude,
      ...MAP_DELTA,
    };
  }, [location, selectedMapPlace]);

  const openPlaceDetail = useCallback((place: any) => {
    const publicId = getPlaceKey(place);
    if (!publicId) return;

    router.push({
      pathname: '/place-detail',
      params: {
        publicId,
        title: getPlaceTitle(place),
      },
    });
  }, [router]);

  const fetchPlaces = useCallback(
    async ({
      center,
      refresh = false,
      append = false,
      cursorArg = null,
      distanceArg = null,
    }: {
      center: Coordinates;
      refresh?: boolean;
      append?: boolean;
      cursorArg?: string | null;
      distanceArg?: string | number | null;
    }) => {
      try {
        if (append) setLoadingMore(true);
        else if (refresh) setRefreshing(true);
        else setLoading(true);

        setError('');

        const response = await api.fetchNearbyPlaces(
          center.latitude,
          center.longitude,
          append ? cursorArg : null,
          append && distanceArg !== null && distanceArg !== undefined ? String(distanceArg) : null,
          Constants.defaultLimit
        );

        const payload = extractPlacesResponse(response);

        setPlaces((current) => {
          if (!append) return payload.places;

          const existing = new Set(current.map((place) => getPlaceKey(place)));
          const incoming = payload.places.filter((place) => !existing.has(getPlaceKey(place)));
          return incoming.length > 0 ? [...current, ...incoming] : current;
        });

        const next = payload.cursor?.next ? String(payload.cursor.next) : null;
        setCursor(next ? { next, distance: payload.cursor?.distance ?? null } : null);

        if (!append) {
          const firstPlaceId = getPlaceKey(payload.places[0]);
          setSelectedPlaceId(firstPlaceId || null);
        }
      } catch {
        if (!append) setPlaces([]);
        setError('Places could not be loaded.');
        setCursor(null);
      } finally {
        setLoading(false);
        setRefreshing(false);
        setLoadingMore(false);
      }
    },
    []
  );

  const bootstrapPlaces = useCallback(async () => {
    let center = ISTANBUL_COORDS;
    let fallback = true;

    try {
      const permission = await Location.requestForegroundPermissionsAsync();
      if (permission.status === 'granted') {
        const current = await Location.getCurrentPositionAsync({
          accuracy: Location.Accuracy.Balanced,
        });
        center = {
          latitude: current.coords.latitude,
          longitude: current.coords.longitude,
        };
        fallback = false;
      }
    } catch {
      fallback = true;
    }

    setLocation(center);
    setIsUsingFallbackLocation(fallback);
    await fetchPlaces({ center });
  }, [fetchPlaces]);

  useEffect(() => {
    void bootstrapPlaces();
  }, [bootstrapPlaces]);

  useEffect(() => {
    if (viewMode !== 'map' || !selectedMapPlace) return;
    const coordinates = getPlaceCoordinates(selectedMapPlace);
    if (!coordinates) return;

    mapRef.current?.animateToRegion(
      {
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
        ...MAP_DELTA,
      },
      280
    );
  }, [selectedMapPlace, viewMode]);

  const handleRefresh = useCallback(() => {
    const center = location ?? ISTANBUL_COORDS;
    void fetchPlaces({ center, refresh: true });
  }, [fetchPlaces, location]);

  const handleLoadMore = useCallback(() => {
    if (loading || loadingMore || !cursor?.next) return;
    const center = location ?? ISTANBUL_COORDS;
    void fetchPlaces({
      center,
      append: true,
      cursorArg: cursor.next,
      distanceArg: cursor.distance,
    });
  }, [cursor, fetchPlaces, loading, loadingMore, location]);

  const renderPlaceCard = useCallback(({ item }: { item: any }) => {
    const title = getPlaceTitle(item);
    const description = getPlaceDescription(item);
    const locationText = getPlaceLocationText(item);
    const primaryTag = getPlacePrimaryTag(item);
    const image = getPlaceImage(item);

    return (
      <Pressable
        style={({ pressed }) => [
          styles.card,
          {
            backgroundColor: cardBackground,
            borderColor,
            opacity: pressed ? 0.94 : 1,
            transform: [{ scale: pressed ? 0.988 : 1 }],
          },
        ]}
        onPress={() => openPlaceDetail(item)}
      >
        <Image source={{ uri: image }} style={styles.cardImage} contentFit="cover" transition={140} />
        <View style={styles.cardBody}>
          <View style={styles.cardTopRow}>
            <Text style={[styles.cardTitle, { color: colors.text }]} numberOfLines={2}>
              {title}
            </Text>
            <MaterialCommunityIcons name="chevron-right" size={18} color={colors.text} />
          </View>

          {!!primaryTag && (
            <View style={[styles.tagChip, { backgroundColor: surfaceBackground, borderColor }]}>
              <Text style={[styles.tagChipText, { color: colors.text }]} numberOfLines={1}>
                #{primaryTag}
              </Text>
            </View>
          )}

          {!!locationText && (
            <View style={styles.locationRow}>
              <MaterialCommunityIcons name="map-marker-outline" size={16} color={mutedText} />
              <Text style={[styles.locationText, { color: mutedText }]} numberOfLines={1}>
                {locationText}
              </Text>
            </View>
          )}

          {!!description && (
            <Text style={[styles.descriptionText, { color: mutedText }]} numberOfLines={3}>
              {description}
            </Text>
          )}
        </View>
      </Pressable>
    );
  }, [borderColor, cardBackground, colors.text, mutedText, openPlaceDetail, surfaceBackground]);

  return (
    <View style={[styles.container, { backgroundColor: colors.background }]}>
      <View style={[styles.controlsWrap, { borderBottomColor: borderColor }]}>
        <View style={[styles.heroCard, { backgroundColor: surfaceBackground, borderColor }]}>
          <Text style={[styles.heroTitle, { color: colors.text }]}>LGBTQ+ friendly places</Text>
          <Text style={[styles.heroText, { color: mutedText }]}>
            Explore bars, cafes, venues and safe community spaces nearby.
          </Text>
          {isUsingFallbackLocation ? (
            <Text style={[styles.heroHint, { color: colors.text }]}>
              Location is unavailable. Showing Istanbul as the default area.
            </Text>
          ) : null}
        </View>

        <View style={[styles.searchBar, { backgroundColor: cardBackground, borderColor }]}>
          <MaterialCommunityIcons name="magnify" size={20} color={mutedText} />
          <TextInput
            value={searchQuery}
            onChangeText={setSearchQuery}
            placeholder="Search places"
            placeholderTextColor={mutedText}
            style={[styles.searchInput, { color: colors.text }]}
            autoCapitalize="none"
            autoCorrect={false}
          />
          {searchQuery ? (
            <TouchableOpacity onPress={() => setSearchQuery('')} activeOpacity={0.8}>
              <MaterialCommunityIcons name="close-circle" size={18} color={mutedText} />
            </TouchableOpacity>
          ) : null}
        </View>

        <View style={styles.segmentRow}>
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            contentContainerStyle={styles.chipRow}
          >
            {categories.map((category) => {
              const active = selectedCategory === category.key;
              return (
                <TouchableOpacity
                  key={category.key}
                  style={[
                    styles.categoryChip,
                    {
                      backgroundColor: active ? colors.text : surfaceBackground,
                      borderColor,
                    },
                  ]}
                  activeOpacity={0.82}
                  onPress={() => setSelectedCategory(category.key)}
                >
                  <Text
                    style={[
                      styles.categoryChipText,
                      { color: active ? colors.background : colors.text },
                    ]}
                  >
                    {category.label}
                  </Text>
                </TouchableOpacity>
              );
            })}
          </ScrollView>

          <View style={[styles.viewToggle, { backgroundColor: surfaceBackground, borderColor }]}>
            <TouchableOpacity
              style={[
                styles.viewToggleButton,
                viewMode === 'grid' && { backgroundColor: colors.text },
              ]}
              activeOpacity={0.85}
              onPress={() => setViewMode('grid')}
            >
              <MaterialCommunityIcons
                name="view-grid-outline"
                size={18}
                color={viewMode === 'grid' ? colors.background : colors.text}
              />
            </TouchableOpacity>
            <TouchableOpacity
              style={[
                styles.viewToggleButton,
                viewMode === 'map' && { backgroundColor: colors.text },
              ]}
              activeOpacity={0.85}
              onPress={() => setViewMode('map')}
            >
              <MaterialCommunityIcons
                name="map-outline"
                size={18}
                color={viewMode === 'map' ? colors.background : colors.text}
              />
            </TouchableOpacity>
          </View>
        </View>

        <View style={styles.summaryRow}>
          <Text style={[styles.summaryText, { color: mutedText }]}>
            {filteredPlaces.length} place{filteredPlaces.length === 1 ? '' : 's'}
          </Text>
          <TouchableOpacity onPress={handleRefresh} activeOpacity={0.8}>
            <Text style={[styles.summaryAction, { color: colors.text }]}>Refresh</Text>
          </TouchableOpacity>
        </View>
      </View>

      {loading && places.length === 0 ? (
        <View style={styles.centerState}>
          <ActivityIndicator size="small" color={colors.text} />
          <Text style={[styles.stateText, { color: mutedText }]}>Loading places...</Text>
        </View>
      ) : error && places.length === 0 ? (
        <View style={styles.centerState}>
          <Text style={[styles.errorText, { color: '#DC2626' }]}>{error}</Text>
          <TouchableOpacity
            style={[styles.retryButton, { backgroundColor: colors.text }]}
            activeOpacity={0.85}
            onPress={handleRefresh}
          >
            <Text style={[styles.retryButtonText, { color: colors.background }]}>Try again</Text>
          </TouchableOpacity>
        </View>
      ) : viewMode === 'map' ? (
        <View style={styles.mapContainer}>
          <MapView
            ref={mapRef}
            provider={PROVIDER_GOOGLE}
            style={StyleSheet.absoluteFill}
            initialRegion={mapRegion}
            showsUserLocation={!isUsingFallbackLocation}
            showsMyLocationButton={!isUsingFallbackLocation}
          >
            {mapPlaces.map(({ place, coordinates }) => (
              <Marker
                key={getPlaceKey(place)}
                coordinate={coordinates}
                title={getPlaceTitle(place)}
                description={getPlaceLocationText(place)}
                onPress={() => setSelectedPlaceId(getPlaceKey(place))}
              />
            ))}
          </MapView>

          {selectedMapPlace ? (
            <Pressable
              style={[
                styles.mapPreviewCard,
                {
                  backgroundColor: cardBackground,
                  borderColor,
                  bottom: insets.bottom + 20,
                },
              ]}
              onPress={() => openPlaceDetail(selectedMapPlace)}
            >
              <Image
                source={{ uri: getPlaceImage(selectedMapPlace) }}
                style={styles.mapPreviewImage}
                contentFit="cover"
                transition={120}
              />
              <View style={styles.mapPreviewBody}>
                <Text style={[styles.mapPreviewTitle, { color: colors.text }]} numberOfLines={1}>
                  {getPlaceTitle(selectedMapPlace)}
                </Text>
                <Text style={[styles.mapPreviewSubtitle, { color: mutedText }]} numberOfLines={2}>
                  {getPlaceLocationText(selectedMapPlace) || getPlaceDescription(selectedMapPlace)}
                </Text>
              </View>
              <MaterialCommunityIcons name="chevron-right" size={20} color={colors.text} />
            </Pressable>
          ) : null}
        </View>
      ) : (
        <FlatList
          data={filteredPlaces}
          key="places-grid"
          numColumns={2}
          keyExtractor={(item) => getPlaceKey(item)}
          renderItem={renderPlaceCard}
          columnWrapperStyle={styles.columnWrapper}
          contentContainerStyle={[
            styles.listContent,
            { paddingBottom: insets.bottom + 28 },
          ]}
          refreshControl={
            <RefreshControl
              refreshing={refreshing}
              onRefresh={handleRefresh}
              tintColor={colors.text}
            />
          }
          onEndReached={handleLoadMore}
          onEndReachedThreshold={0.45}
          showsVerticalScrollIndicator={false}
          ListEmptyComponent={
            <View style={styles.emptyState}>
              <Text style={[styles.stateText, { color: mutedText }]}>
                No places match the current filters.
              </Text>
            </View>
          }
          ListFooterComponent={
            loadingMore ? (
              <View style={styles.footerLoader}>
                <ActivityIndicator size="small" color={colors.text} />
              </View>
            ) : null
          }
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  controlsWrap: {
    paddingHorizontal: 16,
    paddingTop: 16,
    paddingBottom: 14,
    borderBottomWidth: StyleSheet.hairlineWidth,
    gap: 14,
  },
  heroCard: {
    borderWidth: 1,
    borderRadius: 22,
    paddingHorizontal: 16,
    paddingVertical: 16,
    gap: 6,
  },
  heroTitle: {
    fontSize: 20,
    fontFamily: 'Outfit-Bold',
  },
  heroText: {
    fontSize: 14,
    lineHeight: 20,
    fontFamily: 'Inter-Regular',
  },
  heroHint: {
    fontSize: 12,
    lineHeight: 18,
    fontFamily: 'Inter-SemiBold',
    marginTop: 2,
  },
  searchBar: {
    height: 48,
    borderRadius: 16,
    borderWidth: 1,
    paddingHorizontal: 14,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  searchInput: {
    flex: 1,
    fontSize: 15,
    fontFamily: 'Inter-Regular',
  },
  segmentRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  chipRow: {
    paddingRight: 12,
    gap: 8,
  },
  categoryChip: {
    height: 36,
    borderRadius: 18,
    borderWidth: 1,
    paddingHorizontal: 14,
    alignItems: 'center',
    justifyContent: 'center',
  },
  categoryChipText: {
    fontSize: 13,
    fontFamily: 'Inter-SemiBold',
  },
  viewToggle: {
    marginLeft: 'auto',
    padding: 4,
    borderRadius: 16,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 4,
  },
  viewToggleButton: {
    width: 36,
    height: 36,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  summaryRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  summaryText: {
    fontSize: 13,
    fontFamily: 'Inter-SemiBold',
  },
  summaryAction: {
    fontSize: 13,
    fontFamily: 'Inter-SemiBold',
  },
  centerState: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 24,
    gap: 12,
  },
  emptyState: {
    paddingTop: 44,
    alignItems: 'center',
  },
  stateText: {
    fontSize: 14,
    fontFamily: 'Inter-Regular',
    textAlign: 'center',
  },
  errorText: {
    fontSize: 14,
    fontFamily: 'Inter-SemiBold',
    textAlign: 'center',
  },
  retryButton: {
    borderRadius: 14,
    paddingHorizontal: 18,
    paddingVertical: 12,
  },
  retryButtonText: {
    fontSize: 14,
    fontFamily: 'Inter-SemiBold',
  },
  listContent: {
    paddingHorizontal: 16,
    paddingTop: 16,
  },
  columnWrapper: {
    gap: 12,
    marginBottom: 12,
  },
  card: {
    flex: 1,
    borderWidth: 1,
    borderRadius: 22,
    overflow: 'hidden',
  },
  cardImage: {
    width: '100%',
    aspectRatio: 1.2,
    backgroundColor: '#E5E7EB',
  },
  cardBody: {
    paddingHorizontal: 14,
    paddingVertical: 14,
    gap: 8,
  },
  cardTopRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 8,
  },
  cardTitle: {
    flex: 1,
    fontSize: 16,
    lineHeight: 20,
    fontFamily: 'Outfit-Bold',
  },
  tagChip: {
    alignSelf: 'flex-start',
    borderRadius: 14,
    borderWidth: 1,
    paddingHorizontal: 10,
    paddingVertical: 6,
  },
  tagChipText: {
    fontSize: 11,
    fontFamily: 'Inter-SemiBold',
  },
  locationRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  locationText: {
    flex: 1,
    fontSize: 12,
    fontFamily: 'Inter-Regular',
  },
  descriptionText: {
    fontSize: 13,
    lineHeight: 18,
    fontFamily: 'Inter-Regular',
  },
  footerLoader: {
    paddingVertical: 16,
    alignItems: 'center',
  },
  mapContainer: {
    flex: 1,
  },
  mapPreviewCard: {
    position: 'absolute',
    left: 16,
    right: 16,
    borderRadius: 22,
    borderWidth: 1,
    padding: 12,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  mapPreviewImage: {
    width: 64,
    height: 64,
    borderRadius: 16,
    backgroundColor: '#E5E7EB',
  },
  mapPreviewBody: {
    flex: 1,
    gap: 4,
  },
  mapPreviewTitle: {
    fontSize: 15,
    fontFamily: 'Outfit-Bold',
  },
  mapPreviewSubtitle: {
    fontSize: 13,
    lineHeight: 18,
    fontFamily: 'Inter-Regular',
  },
});
