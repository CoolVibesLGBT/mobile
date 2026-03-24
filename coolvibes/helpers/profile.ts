import { getSafeImageURL, getSafeImageURLEx } from '@/helpers/safeUrl'
import { toSafeBioHtml } from '@/helpers/lexicalPlainText'

type ProfileFallback = {
  id?: string
  name?: string
  username?: string
  avatar?: string
}

type NormalizeOptions = {
  language?: string
}

const LOCATION_PLACEHOLDERS = new Set(['earth', 'world', 'unknown', 'n/a', 'na', '-'])

const looksLikeHtml = (value: string) => /<\s*\/?\s*[a-zA-Z]/.test(value)
const looksLikeJson = (value: string) => {
  const trimmed = value.trim()
  return trimmed.startsWith('{') || trimmed.startsWith('[')
}

const looksLikeLexicalState = (value: any) => {
  if (!value || typeof value !== 'object') return false
  const root = (value as any).root
  return !!root && typeof root === 'object' && Array.isArray((root as any).children)
}

const pickLocalizedText = (value: any, language?: string): string | undefined => {
  if (!value) return undefined
  if (typeof value === 'string') return value
  if (typeof value === 'number') return String(value)
  if (typeof value === 'object') {
    const obj = value as Record<string, any>
    if (language && typeof obj[language] === 'string') return obj[language]
    if (typeof obj.en === 'string') return obj.en
    if (typeof obj.tr === 'string') return obj.tr
    const first = Object.values(obj).find((v) => typeof v === 'string') as string | undefined
    return first
  }
  return undefined
}

const stripHtmlTags = (value: string) => value.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim()

const normalizeLocationLabel = (value?: string) => {
  if (!value) return undefined
  const trimmed = value.trim()
  if (!trimmed) return undefined
  const lower = trimmed.toLowerCase()
  if (LOCATION_PLACEHOLDERS.has(lower)) return undefined
  return trimmed
}

const resolveLocationFromObject = (location: any, language?: string) => {
  if (!location || typeof location !== 'object') return undefined
  const display = normalizeLocationLabel(pickLocalizedText((location as any).display, language))
  const city = normalizeLocationLabel(pickLocalizedText((location as any).city, language))
  const region = normalizeLocationLabel(pickLocalizedText((location as any).region, language))
  const country = normalizeLocationLabel(
    pickLocalizedText((location as any).country ?? (location as any).country_name, language)
  )
  const address = normalizeLocationLabel(pickLocalizedText((location as any).address, language))

  if (display) return display
  const parts = [city, region, country].filter(Boolean)
  if (parts.length) return parts.join(', ')
  return address
}

export const encodeProfileParam = (value: any) => {
  if (!value) return undefined
  try {
    return encodeURIComponent(JSON.stringify(value))
  } catch {
    return undefined
  }
}

export const decodeProfileParam = (value?: string) => {
  if (!value) return null
  try {
    return JSON.parse(value)
  } catch {
    try {
      return JSON.parse(decodeURIComponent(value))
    } catch {
      return null
    }
  }
}

export const normalizeProfileUser = (input?: any, fallback?: ProfileFallback, options: NormalizeOptions = {}) => {
  if (!input && !fallback) return null
  const language = options.language
  const raw = input?.raw ? { ...input, ...input.raw } : (input ?? {})
  const fallbackName = fallback?.name || fallback?.username
  const displayname =
    raw?.displayname ||
    raw?.display_name ||
    input?.displayname ||
    input?.name ||
    fallbackName ||
    'User'
  const username =
    raw?.username ||
    input?.username ||
    fallback?.username ||
    displayname
  const id =
    raw?.id ||
    raw?.public_id ||
    input?.id ||
    fallback?.id ||
    username ||
    'user'
  const publicId = raw?.public_id || input?.public_id || id

  const rawBio =
    raw?.bio ??
    raw?.status_message ??
    raw?.statusMessage ??
    raw?.about ??
    raw?.description ??
    raw?.tagline ??
    raw?.profile?.bio ??
    raw?.profile?.status_message ??
    input?.bio ??
    input?.status_message ??
    input?.statusMessage ??
    input?.about ??
    input?.description ??
    input?.tagline

  const rawBioHtml =
    raw?.bio_html ??
    raw?.bioHtml ??
    raw?.profile?.bio_html ??
    raw?.profile?.bioHtml ??
    input?.bio_html ??
    input?.bioHtml

  const rawBioText = pickLocalizedText(rawBio, language)
  const rawBioHtmlText = pickLocalizedText(rawBioHtml, language)
  const htmlSource =
    rawBioHtmlText ||
    (looksLikeLexicalState(rawBio) ? rawBio : (rawBioText ?? rawBio))

  const shouldUseHtml =
    typeof htmlSource === 'object' ||
    (typeof htmlSource === 'string' && (looksLikeHtml(htmlSource) || looksLikeJson(htmlSource)))

  const bioHtmlCandidate = shouldUseHtml ? toSafeBioHtml(htmlSource) : undefined
  const bioHtmlText = bioHtmlCandidate ? stripHtmlTags(bioHtmlCandidate) : ''
  const bioHtml = bioHtmlText ? bioHtmlCandidate : undefined

  let bioText = rawBioText
  if (bioText && looksLikeJson(bioText)) {
    bioText = undefined
  }
  if (bioText && looksLikeHtml(bioText)) {
    bioText = stripHtmlTags(bioText)
  }
  if (bioText) {
    bioText = bioText.trim()
  }
  if (!bioText && bioHtmlText) {
    bioText = bioHtmlText
  }
  if (!bioText) {
    bioText = undefined
  }

  const rawLocation =
    raw?.location ??
    raw?.location_data ??
    raw?.locationData ??
    raw?.profile?.location ??
    input?.location ??
    input?.location_data ??
    input?.locationData

  const location =
    resolveLocationFromObject(rawLocation, language) ||
    normalizeLocationLabel(typeof rawLocation === 'string' ? rawLocation : undefined) ||
    normalizeLocationLabel(pickLocalizedText(raw?.location_display ?? raw?.locationDisplay, language)) ||
    normalizeLocationLabel(pickLocalizedText(raw?.city, language)) ||
    normalizeLocationLabel(pickLocalizedText(raw?.country, language)) ||
    normalizeLocationLabel(pickLocalizedText(raw?.country_name, language)) ||
    normalizeLocationLabel(pickLocalizedText(raw?.region, language)) ||
    normalizeLocationLabel(pickLocalizedText(raw?.place?.name, language)) ||
    normalizeLocationLabel(typeof input?.location === 'string' ? input.location : undefined)

  const avatarUrl =
    getSafeImageURLEx(publicId, raw?.avatar || raw?.avatar_url || raw?.avatarUrl, 'large') ||
    input?.imageUrl ||
    input?.avatar ||
    fallback?.avatar ||
    raw?.avatar_url ||
    raw?.avatarUrl ||
    ''

  const bannerUrl =
    getSafeImageURL(raw?.cover, 'large') ||
    getSafeImageURL(raw?.cover_image, 'large') ||
    getSafeImageURL(raw?.cover_image_url, 'large') ||
    getSafeImageURL(raw?.banner, 'large') ||
    getSafeImageURL(raw?.banner_url, 'large') ||
    raw?.cover?.file?.url ||
    raw?.cover_image?.file?.url ||
    raw?.cover_image_url ||
    raw?.banner_url ||
    input?.cover_image_url ||
    input?.banner_url

  const pickNumber = (...values: any[]) => {
    for (const value of values) {
      if (value === 0) return 0
      if (value !== undefined && value !== null && value !== '') return Number(value)
    }
    return undefined
  }

  const followersCount = pickNumber(
    raw?.followers_count,
    raw?.followersCount,
    raw?.stats?.followers_count,
    raw?.stats?.followers,
    raw?.engagements?.counts?.follower_count,
    Array.isArray(raw?.followers) ? raw.followers.length : undefined,
  )

  const followingCount = pickNumber(
    raw?.following_count,
    raw?.followingCount,
    raw?.stats?.following_count,
    raw?.stats?.following,
    raw?.engagements?.counts?.following_count,
    Array.isArray(raw?.following) ? raw.following.length : undefined,
  )

  const postsCount = pickNumber(
    raw?.posts_count,
    raw?.postsCount,
    raw?.post_count,
    raw?.postCount,
    raw?.stats?.posts_count,
    raw?.stats?.posts,
    raw?.engagements?.counts?.post_count,
    Array.isArray(raw?.posts) ? raw.posts.length : undefined,
    Array.isArray(raw?.vibes) ? raw.vibes.length : undefined,
  )

  const likeReceivedCount = pickNumber(
    raw?.like_received_count,
    raw?.likeReceivedCount,
    raw?.likes_count,
    raw?.likesCount,
    raw?.stats?.like_received_count,
    raw?.stats?.likes_received,
    raw?.stats?.likes,
    raw?.engagements?.counts?.like_received_count,
  )

  const matchCount = pickNumber(
    raw?.match_count,
    raw?.matchCount,
    raw?.stats?.match_count,
    raw?.stats?.matches,
    raw?.engagements?.counts?.match_count,
  )

  return {
    ...raw,
    id,
    public_id: publicId,
    displayname,
    username,
    avatar_url: avatarUrl,
    banner_url: bannerUrl,
    cover_image_url: bannerUrl,
    bioHtml,
    bio: bioText,
    location,
    followers_count: followersCount ?? raw?.followers_count,
    following_count: followingCount ?? raw?.following_count,
    posts_count: postsCount ?? raw?.posts_count,
    like_received_count: likeReceivedCount ?? raw?.like_received_count,
    likes_count: likeReceivedCount ?? raw?.likes_count,
    match_count: matchCount ?? raw?.match_count,
  }
}
