import React, { useCallback, useEffect, useMemo, useState } from 'react';
import {
  ActivityIndicator,
  Linking,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import { useTheme } from '@react-navigation/native';
import { useLocalSearchParams } from 'expo-router';
import MaterialCommunityIcons from '@expo/vector-icons/MaterialCommunityIcons';
import MapView, { Marker, PROVIDER_GOOGLE } from 'react-native-maps';
import { Image } from 'expo-image';

import {
  extractPlaceDetailResponse,
  getPlaceAddress,
  getPlaceCoordinates,
  getPlaceDescription,
  getPlaceEmail,
  getPlaceImage,
  getPlaceLocationText,
  getPlacePrimaryTag,
  getPlaceTelephone,
  getPlaceTitle,
  getPlaceWebsite,
} from '@/helpers/places';
import { api } from '@/services/apiService';

function ensureAbsoluteUrl(url: string): string {
  if (!url) return '';
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  return `https://${url}`;
}

export default function PlaceDetailScreen() {
  const { colors, dark } = useTheme();
  const params = useLocalSearchParams<{ publicId?: string; title?: string }>();

  const publicId = Array.isArray(params.publicId) ? params.publicId[0] : params.publicId;

  const [place, setPlace] = useState<any | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const borderColor = dark ? 'rgba(255,255,255,0.08)' : 'rgba(15,23,42,0.08)';
  const mutedText = dark ? 'rgba(255,255,255,0.58)' : 'rgba(15,23,42,0.58)';
  const cardBackground = dark ? 'rgba(255,255,255,0.04)' : '#FFFFFF';
  const surfaceBackground = dark ? 'rgba(255,255,255,0.06)' : '#F8FAFC';

  const fetchPlaceDetail = useCallback(async () => {
    if (!publicId) {
      setError('Place not found.');
      setLoading(false);
      return;
    }

    try {
      setLoading(true);
      setError('');
      const response = await api.fetchPlace(String(publicId));
      const resolved = extractPlaceDetailResponse(response);
      if (!resolved) {
        setPlace(null);
        setError('Place could not be loaded.');
        return;
      }

      setPlace(resolved);
    } catch {
      setPlace(null);
      setError('Place could not be loaded.');
    } finally {
      setLoading(false);
    }
  }, [publicId]);

  useEffect(() => {
    void fetchPlaceDetail();
  }, [fetchPlaceDetail]);

  const title = useMemo(() => {
    const fallbackTitle = Array.isArray(params.title) ? params.title[0] : params.title;
    return getPlaceTitle(place) || fallbackTitle || 'Place';
  }, [params.title, place]);
  const description = getPlaceDescription(place);
  const locationText = getPlaceLocationText(place);
  const address = getPlaceAddress(place);
  const website = getPlaceWebsite(place);
  const telephone = getPlaceTelephone(place);
  const email = getPlaceEmail(place);
  const tag = getPlacePrimaryTag(place);
  const image = getPlaceImage(place);
  const coordinates = getPlaceCoordinates(place);
  const hashtags = Array.isArray(place?.hashtags) ? place.hashtags : [];

  const handleDirections = useCallback(async () => {
    const destination = address || title;
    if (!destination) return;
    const url = `https://www.google.com/maps/dir/?api=1&destination=${encodeURIComponent(destination)}`;
    await Linking.openURL(url);
  }, [address, title]);

  const handleOpenWebsite = useCallback(async () => {
    const target = ensureAbsoluteUrl(website);
    if (!target) return;
    await Linking.openURL(target);
  }, [website]);

  const handleCall = useCallback(async () => {
    if (!telephone) return;
    await Linking.openURL(`tel:${telephone}`);
  }, [telephone]);

  const handleEmail = useCallback(async () => {
    if (!email) return;
    await Linking.openURL(`mailto:${email}`);
  }, [email]);

  if (loading) {
    return (
      <View style={[styles.centerState, { backgroundColor: colors.background }]}>
        <ActivityIndicator size="small" color={colors.text} />
        <Text style={[styles.stateText, { color: mutedText }]}>Loading place...</Text>
      </View>
    );
  }

  if (error || !place) {
    return (
      <View style={[styles.centerState, { backgroundColor: colors.background }]}>
        <Text style={[styles.errorText, { color: '#DC2626' }]}>{error || 'Place could not be loaded.'}</Text>
      </View>
    );
  }

  return (
    <ScrollView
      style={[styles.container, { backgroundColor: colors.background }]}
      contentContainerStyle={styles.scrollContent}
      showsVerticalScrollIndicator={false}
    >
      <View style={[styles.heroWrap, { backgroundColor: surfaceBackground }]}>
        <Image source={{ uri: image }} style={styles.heroImage} contentFit="cover" transition={140} />
        <View style={styles.heroOverlay} />
        <View style={styles.heroContent}>
          {!!tag && (
            <View style={styles.heroTag}>
              <Text style={styles.heroTagText}>#{tag}</Text>
            </View>
          )}
          <Text style={styles.heroTitle}>{title}</Text>
          {!!locationText && (
            <View style={styles.heroLocationRow}>
              <MaterialCommunityIcons name="map-marker-outline" size={16} color="rgba(255,255,255,0.82)" />
              <Text style={styles.heroLocationText}>{locationText}</Text>
            </View>
          )}
        </View>
      </View>

      <View style={styles.contentWrap}>
        <View style={styles.actionRow}>
          <TouchableOpacity
            style={[styles.primaryAction, { backgroundColor: colors.text }]}
            activeOpacity={0.85}
            onPress={handleDirections}
          >
            <MaterialCommunityIcons name="directions" size={18} color={colors.background} />
            <Text style={[styles.primaryActionText, { color: colors.background }]}>Directions</Text>
          </TouchableOpacity>

          {website ? (
            <TouchableOpacity
              style={[styles.secondaryAction, { backgroundColor: cardBackground, borderColor }]}
              activeOpacity={0.85}
              onPress={handleOpenWebsite}
            >
              <MaterialCommunityIcons name="web" size={18} color={colors.text} />
              <Text style={[styles.secondaryActionText, { color: colors.text }]}>Website</Text>
            </TouchableOpacity>
          ) : null}
        </View>

        {!!description && (
          <View style={[styles.card, { backgroundColor: cardBackground, borderColor }]}>
            <Text style={[styles.cardTitle, { color: colors.text }]}>About</Text>
            <Text style={[styles.cardText, { color: mutedText }]}>{description}</Text>
          </View>
        )}

        <View style={[styles.card, { backgroundColor: cardBackground, borderColor }]}>
          <Text style={[styles.cardTitle, { color: colors.text }]}>Location</Text>
          <View style={styles.infoRow}>
            <MaterialCommunityIcons name="map-marker-outline" size={18} color={mutedText} />
            <Text style={[styles.cardText, { color: mutedText }]}>
              {address || locationText || 'Location details are unavailable.'}
            </Text>
          </View>

          {coordinates ? (
            <View style={[styles.mapPreviewWrap, { borderColor }]}>
              <MapView
                provider={PROVIDER_GOOGLE}
                style={styles.mapPreview}
                initialRegion={{
                  latitude: coordinates.latitude,
                  longitude: coordinates.longitude,
                  latitudeDelta: 0.02,
                  longitudeDelta: 0.02,
                }}
                scrollEnabled={false}
                zoomEnabled={false}
                rotateEnabled={false}
                pitchEnabled={false}
              >
                <Marker coordinate={coordinates} title={title} />
              </MapView>
            </View>
          ) : null}
        </View>

        {(telephone || email || website) && (
          <View style={[styles.card, { backgroundColor: cardBackground, borderColor }]}>
            <Text style={[styles.cardTitle, { color: colors.text }]}>Contact</Text>
            {!!telephone && (
              <TouchableOpacity style={styles.contactRow} activeOpacity={0.82} onPress={handleCall}>
                <MaterialCommunityIcons name="phone-outline" size={18} color={colors.text} />
                <Text style={[styles.contactLabel, { color: colors.text }]}>{telephone}</Text>
              </TouchableOpacity>
            )}
            {!!email && (
              <TouchableOpacity style={styles.contactRow} activeOpacity={0.82} onPress={handleEmail}>
                <MaterialCommunityIcons name="email-outline" size={18} color={colors.text} />
                <Text style={[styles.contactLabel, { color: colors.text }]}>{email}</Text>
              </TouchableOpacity>
            )}
            {!!website && (
              <TouchableOpacity style={styles.contactRow} activeOpacity={0.82} onPress={handleOpenWebsite}>
                <MaterialCommunityIcons name="web" size={18} color={colors.text} />
                <Text style={[styles.contactLabel, { color: colors.text }]} numberOfLines={1}>
                  {website}
                </Text>
              </TouchableOpacity>
            )}
          </View>
        )}

        {hashtags.length > 0 && (
          <View style={[styles.card, { backgroundColor: cardBackground, borderColor }]}>
            <Text style={[styles.cardTitle, { color: colors.text }]}>Tags</Text>
            <View style={styles.hashtagRow}>
              {hashtags.map((item: any, index: number) => {
                const value = typeof item?.tag === 'string' ? item.tag.trim() : '';
                if (!value) return null;

                return (
                  <View
                    key={`${value}-${index}`}
                    style={[styles.hashtagChip, { backgroundColor: surfaceBackground, borderColor }]}
                  >
                    <Text style={[styles.hashtagChipText, { color: colors.text }]}>#{value}</Text>
                  </View>
                );
              })}
            </View>
          </View>
        )}
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  scrollContent: {
    paddingBottom: 32,
  },
  centerState: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 24,
    gap: 12,
  },
  stateText: {
    fontSize: 14,
    fontFamily: 'Inter-Regular',
  },
  errorText: {
    fontSize: 14,
    fontFamily: 'Inter-SemiBold',
    textAlign: 'center',
  },
  heroWrap: {
    height: 280,
  },
  heroImage: {
    width: '100%',
    height: '100%',
  },
  heroOverlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(2,6,23,0.32)',
  },
  heroContent: {
    position: 'absolute',
    left: 20,
    right: 20,
    bottom: 20,
    gap: 8,
  },
  heroTag: {
    alignSelf: 'flex-start',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 999,
    backgroundColor: 'rgba(15,23,42,0.78)',
  },
  heroTagText: {
    color: '#FFFFFF',
    fontSize: 12,
    fontFamily: 'Inter-SemiBold',
  },
  heroTitle: {
    color: '#FFFFFF',
    fontSize: 30,
    lineHeight: 34,
    fontFamily: 'Outfit-Black',
  },
  heroLocationRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  heroLocationText: {
    color: 'rgba(255,255,255,0.82)',
    fontSize: 14,
    fontFamily: 'Inter-SemiBold',
  },
  contentWrap: {
    paddingHorizontal: 16,
    paddingTop: 16,
    gap: 14,
  },
  actionRow: {
    flexDirection: 'row',
    gap: 10,
  },
  primaryAction: {
    flex: 1,
    height: 48,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
    flexDirection: 'row',
    gap: 8,
  },
  primaryActionText: {
    fontSize: 14,
    fontFamily: 'Inter-SemiBold',
  },
  secondaryAction: {
    minWidth: 118,
    height: 48,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
    flexDirection: 'row',
    gap: 8,
    borderWidth: 1,
    paddingHorizontal: 14,
  },
  secondaryActionText: {
    fontSize: 14,
    fontFamily: 'Inter-SemiBold',
  },
  card: {
    borderWidth: 1,
    borderRadius: 22,
    padding: 16,
    gap: 12,
  },
  cardTitle: {
    fontSize: 18,
    fontFamily: 'Outfit-Bold',
  },
  cardText: {
    fontSize: 14,
    lineHeight: 20,
    fontFamily: 'Inter-Regular',
  },
  infoRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 10,
  },
  mapPreviewWrap: {
    height: 180,
    borderRadius: 18,
    overflow: 'hidden',
    borderWidth: 1,
  },
  mapPreview: {
    flex: 1,
  },
  contactRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  contactLabel: {
    flex: 1,
    fontSize: 14,
    fontFamily: 'Inter-SemiBold',
  },
  hashtagRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  hashtagChip: {
    borderWidth: 1,
    borderRadius: 14,
    paddingHorizontal: 10,
    paddingVertical: 8,
  },
  hashtagChipText: {
    fontSize: 12,
    fontFamily: 'Inter-SemiBold',
  },
});
