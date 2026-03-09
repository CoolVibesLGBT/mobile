import { defaultServiceServerId, serviceURL } from '@/config';

export function getSafeImageURL(attachment: any, variant = 'small'): string | null {
  const serviceUri = serviceURL[defaultServiceServerId];

  try {
    const path =
      attachment?.file?.variants?.image?.[variant]?.url ||
      attachment?.variants?.image?.[variant]?.url ||
      attachment?.file?.variants?.video?.[variant]?.url ||
      attachment?.variants?.video?.[variant]?.url;

    if (!path) {
      return null;
    }

    const url = path.startsWith('http') ? new URL(path) : new URL(path, serviceUri);
    if (!['https:', 'http:'].includes(url.protocol)) {
      return null;
    }

    return url.href.toString();
  } catch {
    return null;
  }
}

export function getSafeImageURLEx(publicId: any, attachment: any, variant = 'small'): string | null {
  return getSafeImageURL(attachment, variant) || generateFallbackImage(publicId);
}

export function calculateAge(dateOfBirth: string): number | string {
  const birthDate = new Date(dateOfBirth);
  if (Number.isNaN(birthDate.getTime())) {
    return '-';
  }

  const today = new Date();
  let age = today.getFullYear() - birthDate.getFullYear();
  const monthDiff = today.getMonth() - birthDate.getMonth();

  if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
    age -= 1;
  }

  return age;
}

function generateFallbackImage(seed: any): string {
  const safeSeed = encodeURIComponent(String(seed ?? 'guest'));
  return `https://api.dicebear.com/9.x/thumbs/png?seed=${safeSeed}`;
}
