export type ComposerMedia = {
  uri?: string;
  type?: 'image' | 'video' | 'document' | 'audio' | 'location' | 'live_location' | 'tag' | 'sticker' | string;
  name?: string;
  mimeType?: string;
  data?: any;
};

const inferMimeType = (media: ComposerMedia, fallback: string) => {
  if (typeof media.mimeType === 'string' && media.mimeType.trim()) return media.mimeType;
  const lowerName = String(media.name || media.uri || '').toLowerCase();
  if (lowerName.endsWith('.png')) return 'image/png';
  if (lowerName.endsWith('.gif')) return 'image/gif';
  if (lowerName.endsWith('.webp')) return 'image/webp';
  if (lowerName.endsWith('.mov')) return 'video/quicktime';
  if (lowerName.endsWith('.m4a')) return 'audio/m4a';
  if (lowerName.endsWith('.aac')) return 'audio/aac';
  if (lowerName.endsWith('.mp3')) return 'audio/mpeg';
  if (lowerName.endsWith('.wav')) return 'audio/wav';
  if (lowerName.endsWith('.pdf')) return 'application/pdf';
  return fallback;
};

const getLocationAddress = (media: ComposerMedia, latitude: number, longitude: number) => {
  const source = media.data ?? {};
  return (
    media.name ||
    source.address ||
    source.display_name ||
    source.formatted_address ||
    [source.name, source.address].filter(Boolean).join(', ') ||
    `Location ${latitude.toFixed(4)}, ${longitude.toFixed(4)}`
  );
};

export function applyComposerMediaToPayload(
  payload: Record<string, any>,
  media: ComposerMedia[] = [],
  prefix: string,
) {
  const imageFiles: any[] = [];
  const videoFiles: any[] = [];
  const audioFiles: any[] = [];
  const documentFiles: any[] = [];
  let selectedLocation: ComposerMedia | null = null;

  media.forEach((item, index) => {
    if (!item || typeof item !== 'object') return;

    if (item.type === 'sticker') return;

    if (item.type === 'location' || item.type === 'live_location') {
      selectedLocation = item;
    }

    const uri = typeof item.uri === 'string' ? item.uri : '';
    if (!uri) return;

    if (item.type === 'image') {
      imageFiles.push({
        uri,
        name: item.name || `${prefix}-image-${Date.now()}-${index}.jpg`,
        type: inferMimeType(item, 'image/jpeg'),
      });
      return;
    }

    if (item.type === 'video') {
      videoFiles.push({
        uri,
        name: item.name || `${prefix}-video-${Date.now()}-${index}.mp4`,
        type: inferMimeType(item, 'video/mp4'),
      });
      return;
    }

    if (item.type === 'audio') {
      audioFiles.push({
        uri,
        name: item.name || `${prefix}-audio-${Date.now()}-${index}.m4a`,
        type: inferMimeType(item, 'audio/m4a'),
      });
      return;
    }

    if (item.type === 'document') {
      documentFiles.push({
        uri,
        name: item.name || `${prefix}-document-${Date.now()}-${index}`,
        type: inferMimeType(item, 'application/octet-stream'),
      });
    }
  });

  if (imageFiles.length > 0) payload['images[]'] = imageFiles;
  if (videoFiles.length > 0) payload['videos[]'] = videoFiles;
  if (audioFiles.length > 0) payload['audios[]'] = audioFiles;
  if (documentFiles.length > 0) payload['documents[]'] = documentFiles;

  if (!selectedLocation) return payload;

  const locationMedia = selectedLocation as ComposerMedia;
  const locationSource = locationMedia.data ?? {};
  const latitude = Number(
    locationSource.latitude ??
      locationSource.lat ??
      locationSource.coords?.latitude
  );
  const longitude = Number(
    locationSource.longitude ??
      locationSource.lng ??
      locationSource.lon ??
      locationSource.coords?.longitude
  );

  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return payload;

  payload['location[address]'] = getLocationAddress(selectedLocation, latitude, longitude);
  payload['location[lat]'] = latitude;
  payload['location[lng]'] = longitude;

  return payload;
}
