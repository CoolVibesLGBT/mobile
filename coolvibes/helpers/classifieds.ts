import * as Localization from 'expo-localization';

import { lexicalToPlainText } from '@/helpers/lexicalPlainText';
import { getSafeImageURL, getSafeImageURLEx } from '@/helpers/safeUrl';

export type ClassifiedTab = 'hiring' | 'seeking';
export type ClassifiedKind = 'job_offer' | 'job_search';

export type ClassifiedMetadataItem = {
  key: string;
  value: string;
};

export type ClassifiedAuthor = {
  name: string;
  username: string;
  avatar: string;
};

export type ClassifiedCardItem = {
  id: string;
  kind: ClassifiedKind;
  title: string;
  excerpt: string;
  image?: string;
  metadata: ClassifiedMetadataItem[];
  time: string;
  author: ClassifiedAuthor;
  raw: any;
};

export function tabToClassifiedKind(tab: ClassifiedTab): ClassifiedKind {
  return tab === 'hiring' ? 'job_offer' : 'job_search';
}

export function kindToClassifiedTab(kind: string | null | undefined): ClassifiedTab {
  return kind === 'job_search' ? 'seeking' : 'hiring';
}

function coerceLocalizedText(value: unknown): string {
  if (typeof value === 'string') return value;
  if (!value || typeof value !== 'object') return '';

  const record = value as Record<string, unknown>;
  const locale = Localization.getLocales?.()?.[0];
  const languageCode = locale?.languageCode;
  const regionCode = locale?.regionCode;

  const candidates = [
    languageCode,
    languageCode && regionCode ? `${languageCode}-${regionCode}` : null,
    'en',
  ].filter(Boolean) as string[];

  for (const key of candidates) {
    const localized = record[key];
    if (typeof localized === 'string' && localized.trim()) {
      return localized;
    }
  }

  for (const localized of Object.values(record)) {
    if (typeof localized === 'string' && localized.trim()) {
      return localized;
    }
  }

  return '';
}

function extractFirstImageAltTextFromLexical(input: unknown): string {
  if (typeof input !== 'string') return '';
  const trimmed = input.trim();
  if (!trimmed.startsWith('{')) return '';

  try {
    const parsed = JSON.parse(trimmed) as any;
    const stack: any[] = [parsed?.root ?? parsed];
    let guard = 0;

    while (stack.length && guard < 800) {
      guard += 1;
      const node = stack.pop();
      if (!node || typeof node !== 'object') continue;

      if (node.type === 'image' && typeof node.altText === 'string' && node.altText.trim()) {
        return node.altText.trim();
      }

      if (Array.isArray(node.children)) {
        for (let index = node.children.length - 1; index >= 0; index -= 1) {
          stack.push(node.children[index]);
        }
      }
    }
  } catch {
    // ignore invalid lexical payloads
  }

  return '';
}

export function formatRelativeTime(value: unknown): string {
  if (typeof value !== 'string') return '';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '';

  const delta = Date.now() - date.getTime();
  const minutes = Math.floor(delta / 60000);
  const hours = Math.floor(delta / 3600000);
  const days = Math.floor(delta / 86400000);

  if (minutes < 1) return 'just now';
  if (minutes < 60) return `${minutes} min ago`;
  if (hours < 24) return `${hours} hours ago`;
  if (days < 7) return `${days} days ago`;
  return date.toLocaleDateString();
}

function normalizeMetadataItems(metadata: unknown): ClassifiedMetadataItem[] {
  if (typeof metadata === 'string') {
    try {
      return normalizeMetadataItems(JSON.parse(metadata));
    } catch {
      return [];
    }
  }

  if (!Array.isArray(metadata)) return [];

  return metadata
    .map((entry: any) => {
      const key = typeof entry?.key === 'string' ? entry.key.trim() : '';
      const value = typeof entry?.value === 'string' ? entry.value.trim() : '';
      if (!key || !value) return null;
      return { key, value };
    })
    .filter(Boolean) as ClassifiedMetadataItem[];
}

export function normalizeClassifiedPost(post: any): ClassifiedCardItem | null {
  if (!post || typeof post !== 'object') return null;

  const author = post?.author ?? post?.user ?? {};
  const authorSeed = author?.public_id || author?.id || post?.author_id || post?.public_id || post?.id;
  const attachments = Array.isArray(post?.attachments) ? post.attachments : [];
  const firstAttachment = attachments[0];
  const extras = post?.extras ?? {};
  const localizedContent = coerceLocalizedText(post?.content);
  const plainText = lexicalToPlainText(localizedContent);
  const excerpt =
    plainText && plainText.trim()
      ? plainText.trim()
      : extractFirstImageAltTextFromLexical(localizedContent) || '';

  let resolvedTitle = '';
  if (typeof extras?.title === 'string' && extras.title.trim()) {
    resolvedTitle = extras.title.trim();
    if (resolvedTitle.startsWith('"') && resolvedTitle.endsWith('"')) {
      try {
        const parsedTitle = JSON.parse(resolvedTitle);
        if (typeof parsedTitle === 'string' && parsedTitle.trim()) {
          resolvedTitle = parsedTitle.trim();
        }
      } catch {
        // keep original string
      }
    }
  }

  const title = resolvedTitle || excerpt.split('\n').find((line) => line.trim())?.trim() || 'Untitled listing';

  const image =
    getSafeImageURL(firstAttachment, 'original') ||
    getSafeImageURL(firstAttachment, 'large') ||
    getSafeImageURL(firstAttachment, 'medium') ||
    getSafeImageURL(firstAttachment, 'small') ||
    undefined;

  const id = String(post?.public_id ?? post?.id ?? authorSeed ?? '');
  if (!id) return null;

  return {
    id,
    kind: post?.kind === 'job_search' ? 'job_search' : 'job_offer',
    title,
    excerpt,
    image,
    metadata: normalizeMetadataItems(extras?.metadata),
    time: formatRelativeTime(post?.created_at),
    author: {
      name: author?.displayname || author?.username || 'User',
      username: author?.username || author?.displayname || 'user',
      avatar: getSafeImageURLEx(authorSeed, author?.avatar, 'small') || '',
    },
    raw: post,
  };
}

export function normalizeClassifiedList(posts: unknown): ClassifiedCardItem[] {
  if (!Array.isArray(posts)) return [];
  return posts.map(normalizeClassifiedPost).filter(Boolean) as ClassifiedCardItem[];
}

export function searchClassifieds(items: ClassifiedCardItem[], query: string): ClassifiedCardItem[] {
  const normalizedQuery = query.trim().toLowerCase();
  if (!normalizedQuery) return items;

  return items.filter((item) => {
    if (item.title.toLowerCase().includes(normalizedQuery)) return true;
    if (item.excerpt.toLowerCase().includes(normalizedQuery)) return true;
    if (item.author.name.toLowerCase().includes(normalizedQuery)) return true;
    if (item.author.username.toLowerCase().includes(normalizedQuery)) return true;
    return item.metadata.some((entry) => (
      entry.key.toLowerCase().includes(normalizedQuery) ||
      entry.value.toLowerCase().includes(normalizedQuery)
    ));
  });
}

export function extractClassifiedListResponse(response: any): { posts: any[]; cursor: string | null } {
  const payload = response?.data ?? response ?? {};
  const nested = payload?.data ?? {};
  const posts =
    payload?.posts ??
    payload?.items ??
    nested?.posts ??
    nested?.items ??
    nested?.data ??
    payload?.data ??
    [];
  const rawCursor =
    payload?.cursor ??
    payload?.next_cursor ??
    payload?.nextCursor ??
    nested?.cursor ??
    nested?.next_cursor ??
    nested?.nextCursor ??
    null;
  const cursor =
    rawCursor === null ||
    rawCursor === undefined ||
    rawCursor === '' ||
    rawCursor === '0' ||
    rawCursor === 'null' ||
    rawCursor === 'undefined'
      ? null
      : String(rawCursor);

  return {
    posts: Array.isArray(posts) ? posts : [],
    cursor,
  };
}

export function extractClassifiedDetailResponse(response: any): any | null {
  const payload = response?.data ?? response ?? {};
  const nested = payload?.data ?? {};
  const resolved =
    payload?.post ??
    payload?.item ??
    nested?.post ??
    nested?.item ??
    nested?.result ??
    payload?.data ??
    payload?.result ??
    payload;

  if (Array.isArray(resolved)) return resolved[0] ?? null;
  return resolved && typeof resolved === 'object' ? resolved : null;
}
