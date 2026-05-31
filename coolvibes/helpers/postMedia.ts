import { getSafeImageURL } from '@/helpers/safeUrl';
import { STICKER_BASE_URL } from '@/helpers/stickers';

export type AttachmentVariant =
  | 'icon'
  | 'thumbnail'
  | 'small'
  | 'medium'
  | 'large'
  | 'original'
  | 'poster'
  | 'preview'
  | 'low'
  | 'high';

export const normalizePostFetchResponse = (response: any): any | null => {
  const payload = response?.data ?? response ?? null;
  if (!payload) return null;

  const data = payload?.data ?? payload ?? null;
  const postCandidate =
    data?.post ??
    payload?.post ??
    data?.item ??
    payload?.item ??
    data?.data?.post ??
    payload?.data?.post ??
    null;

  const pick = (value: any) => {
    if (!value || typeof value !== 'object') return null;
    if ('public_id' in value || 'id' in value) return value;
    return null;
  };

  return pick(postCandidate) || pick(data) || pick(payload);
};

export const isAttachmentProcessing = (attachment: any) =>
  attachment?.processing_status === 'pending' || attachment?.processing_status === 'processing';

export const isAttachmentFailed = (attachment: any) =>
  attachment?.processing_status === 'failed';

export const getAttachmentUrl = (
  attachment: any,
  preferredVariants: AttachmentVariant[],
) => {
  if (!attachment || isAttachmentProcessing(attachment)) {
    return null;
  }

  for (const variant of preferredVariants) {
    const variantUrl = getSafeImageURL(attachment, variant);
    if (variantUrl) return variantUrl;
  }

  return attachment?.file?.url || attachment?.url || null;
};

export const getPostAttachments = (post: any): any[] => (
  Array.isArray(post?.attachments) ? post.attachments : []
);

export const getProcessingAttachmentCount = (attachments: any[]) => (
  attachments.filter((attachment) => isAttachmentProcessing(attachment)).length
);

export const getFirstImageAttachment = (attachments: any[]) => (
  attachments.find((attachment) => attachment?.file?.mime_type?.startsWith('image/')) || null
);

const coerceLocalizedContentString = (input: unknown): string => {
  if (typeof input === 'string') return input;
  if (!input || typeof input !== 'object') return '';

  const record = input as Record<string, unknown>;
  const prioritizedKeys = ['en', 'tr'];

  for (const key of prioritizedKeys) {
    const value = record[key];
    if (typeof value === 'string' && value.trim()) return value;
  }

  for (const value of Object.values(record)) {
    if (typeof value === 'string' && value.trim()) return value;
  }

  return '';
};

export const extractFirstLexicalImageNode = (
  input: unknown,
): { src: string; altText?: string } | null => {
  const raw = coerceLocalizedContentString(input).trim();
  if (!raw.startsWith('{')) return null;

  try {
    const parsed = JSON.parse(raw) as any;
    const stack: any[] = [parsed?.root ?? parsed];
    let guard = 0;

    while (stack.length > 0 && guard < 1000) {
      guard += 1;
      const node = stack.pop();
      if (!node || typeof node !== 'object') continue;

      if (node.type === 'image' && typeof node.src === 'string' && node.src.trim()) {
        return {
          src: node.src.trim(),
          altText: typeof node.altText === 'string' ? node.altText.trim() : undefined,
        };
      }

      const children = node.children;
      if (Array.isArray(children)) {
        for (let index = children.length - 1; index >= 0; index -= 1) {
          stack.push(children[index]);
        }
      }
    }
  } catch {
    return null;
  }

  return null;
};

export const getFirstLexicalImageUrl = (content: unknown): string | null => {
  const imageNode = extractFirstLexicalImageNode(content);
  if (!imageNode?.src) return null;
  const normalizedSrc = imageNode.src.trim();

  if (normalizedSrc.startsWith('/stickers/')) {
    return `${STICKER_BASE_URL}/${normalizedSrc.replace(/^\/stickers\//, '')}`;
  }

  if (normalizedSrc.startsWith('stickers/')) {
    return `${STICKER_BASE_URL}/${normalizedSrc.replace(/^stickers\//, '')}`;
  }

  return getSafeImageURL(imageNode.src, 'original') || imageNode.src || null;
};

export const isGifUrl = (value: unknown): boolean => (
  typeof value === 'string' && /\.gif($|\?)/i.test(value)
);

export const isGifAttachment = (attachment: any): boolean => {
  const mimeType =
    attachment?.file?.mime_type ||
    attachment?.mime_type ||
    attachment?.file?.type ||
    '';

  if (typeof mimeType === 'string' && mimeType.toLowerCase() === 'image/gif') {
    return true;
  }

  const originalUrl =
    getAttachmentUrl(attachment, ['original', 'large', 'medium', 'small']) ||
    attachment?.file?.url ||
    attachment?.url ||
    null;

  return isGifUrl(originalUrl);
};
