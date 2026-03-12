import { defaultServiceServerId, serviceURL } from '@/config';

export function getSafeImageURL(attachment: any, variant = 'small'): string | null {
  const serviceUri = serviceURL[defaultServiceServerId];

  if (!attachment) return null;

  // If attachment is already a full URL string, return it clean
  if (typeof attachment === 'string') {
    if (attachment.startsWith('http')) return attachment;
    const cleanPath = attachment.startsWith('./') ? attachment.substring(2) : attachment;
    try {
        return new URL(cleanPath.startsWith('/') ? cleanPath : `/${cleanPath}`, serviceUri).href;
    } catch { return null; }
  }

  try {
    // Basic variant normalization
    let target = variant;
    if (variant === 'thumb') target = 'thumbnail';

    const variants = attachment?.file?.variants?.image || attachment?.variants?.image ||
                     attachment?.file?.variants?.video || attachment?.variants?.video;

    // If no variants but it has a url at top level
    const topLevelUrl = attachment?.file?.url || attachment?.url;
    
    if (!variants && topLevelUrl) {
        return getSafeImageURL(topLevelUrl, variant);
    }

    if (!variants) return null;

    // Try requested variant, then common fallbacks
    const path = variants[target]?.url || 
                 variants['small']?.url || 
                 variants['thumbnail']?.url || 
                 variants['medium']?.url ||
                 variants['original']?.url;

    if (!path) return topLevelUrl ? getSafeImageURL(topLevelUrl, variant) : null;

    // Clean path and ensure it's a valid URL
    const cleanPath = path.startsWith('./') ? path.substring(2) : path;
    const url = cleanPath.startsWith('http') ? new URL(cleanPath) : new URL(cleanPath.startsWith('/') ? cleanPath : `/${cleanPath}`, serviceUri);

    return url.href;
  } catch (error) {
    console.warn('getSafeImageURL error:', error);
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
