import { LocalizedStringToString } from '@/utils/utils';

export type PlaceCategory = {
  key: string;
  label: string;
};

type PlaceCoordinates = {
  latitude: number;
  longitude: number;
};

function buildPlaceImage(publicId: unknown): string {
  const safeSeed = encodeURIComponent(String(publicId ?? 'place'));
  return `https://api.dicebear.com/9.x/shapes/svg?seed=${safeSeed}`;
}

export function getPlaceImage(place: any): string {
  const direct = place?.extras?.place?.image;
  if (typeof direct === 'string' && direct.startsWith('http')) {
    return direct;
  }
  return buildPlaceImage(place?.public_id ?? place?.id);
}

export function getPlaceTitle(place: any): string {
  return (
    LocalizedStringToString(place?.title) ||
    place?.extras?.place?.name ||
    'Untitled place'
  );
}

export function getPlaceDescription(place: any): string {
  const description = place?.extras?.place?.description;
  if (typeof description === 'string') return description;
  return LocalizedStringToString(place?.content);
}

function toFiniteNumber(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string' && value.trim() !== '') {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return null;
}

export function getPlaceCoordinates(place: any): PlaceCoordinates | null {
  const extras = place?.extras?.place ?? {};
  const location = place?.location ?? {};

  const latitude =
    toFiniteNumber(extras.latitude) ??
    toFiniteNumber(extras.lat) ??
    toFiniteNumber(location.latitude) ??
    toFiniteNumber(location.lat);

  const longitude =
    toFiniteNumber(extras.longitude) ??
    toFiniteNumber(extras.lng) ??
    toFiniteNumber(extras.lon) ??
    toFiniteNumber(location.longitude) ??
    toFiniteNumber(location.lng) ??
    toFiniteNumber(location.lon);

  if (latitude === null || longitude === null) {
    return null;
  }

  return { latitude, longitude };
}

export function getPlaceLocationText(place: any): string {
  const placeData = place?.extras?.place ?? {};
  const location = place?.location ?? {};
  return [
    placeData.town || location.city,
    placeData.province || location.province,
    placeData.country || location.country,
  ]
    .filter(Boolean)
    .join(', ');
}

export function getPlaceAddress(place: any): string {
  const placeData = place?.extras?.place ?? {};
  return [
    placeData.address,
    placeData.town,
    placeData.country,
  ]
    .filter(Boolean)
    .join(', ');
}

export function getPlaceWebsite(place: any): string {
  const placeData = place?.extras?.place ?? {};
  const candidate = placeData.website || placeData.urls?.[0];
  return typeof candidate === 'string' ? candidate : '';
}

export function getPlaceTelephone(place: any): string {
  const value = place?.extras?.place?.telephone;
  return typeof value === 'string' ? value : '';
}

export function getPlaceEmail(place: any): string {
  const value = place?.extras?.place?.email;
  return typeof value === 'string' ? value : '';
}

export function getPlacePrimaryTag(place: any): string {
  const explicit = place?.extras?.place?.tag;
  if (typeof explicit === 'string' && explicit.trim()) return explicit.trim();

  const hashtags = Array.isArray(place?.hashtags) ? place.hashtags : [];
  for (const entry of hashtags) {
    const tag = typeof entry?.tag === 'string' ? entry.tag.trim() : '';
    if (tag) return tag;
  }

  return '';
}

export function extractPlacesResponse(response: any): { places: any[]; cursor: any | null } {
  const payload = response?.data ?? response ?? {};
  const nested = payload?.data ?? {};
  const places =
    payload?.places ??
    nested?.places ??
    payload?.items ??
    nested?.items ??
    [];
  const cursor = payload?.cursor ?? nested?.cursor ?? null;
  return {
    places: Array.isArray(places) ? places : [],
    cursor,
  };
}

export function extractPlaceDetailResponse(response: any): any | null {
  const payload = response?.data ?? response ?? {};
  const nested = payload?.data ?? {};
  const places = payload?.places ?? nested?.places;
  if (Array.isArray(places) && places.length > 0) {
    return places[0];
  }

  const place =
    payload?.place ??
    nested?.place ??
    payload?.item ??
    nested?.item ??
    nested;

  return place && typeof place === 'object' ? place : null;
}

export function getPlaceCategories(places: any[]): PlaceCategory[] {
  const tags = new Set<string>();
  places.forEach((place) => {
    const hashtags = Array.isArray(place?.hashtags) ? place.hashtags : [];
    hashtags.forEach((entry: any) => {
      const tag = typeof entry?.tag === 'string' ? entry.tag.trim() : '';
      if (tag) tags.add(tag);
    });
  });

  return [
    { key: 'all', label: 'All' },
    ...Array.from(tags)
      .slice(0, 12)
      .map((tag) => ({ key: tag, label: `#${tag}` })),
  ];
}

export function filterPlaces(places: any[], category: string, query: string): any[] {
  const normalizedQuery = query.trim().toLowerCase();

  return places.filter((place) => {
    if (category !== 'all') {
      const hashtags = Array.isArray(place?.hashtags) ? place.hashtags : [];
      const matchesCategory = hashtags.some((entry: any) => entry?.tag === category);
      if (!matchesCategory) return false;
    }

    if (!normalizedQuery) return true;

    const haystack = [
      getPlaceTitle(place),
      getPlaceDescription(place),
      getPlaceLocationText(place),
      ...(Array.isArray(place?.hashtags) ? place.hashtags.map((entry: any) => entry?.tag || '') : []),
    ]
      .filter(Boolean)
      .join(' ')
      .toLowerCase();

    return haystack.includes(normalizedQuery);
  });
}
