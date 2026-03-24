import { getSafeImageURL } from '@/helpers/safeUrl';

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
