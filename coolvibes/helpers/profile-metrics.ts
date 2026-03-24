import { getSafeImageURLEx } from '@/helpers/safeUrl';

export type ProfileMetricStat = {
  key: string;
  label: string;
  value: number;
  description: string;
};

export type ProfileMetricDetailItem = {
  id: string;
  name: string;
  username: string;
  avatar: string;
  subtitle: string;
};

const hasCountSource = (...values: any[]) => values.some((value) => value !== undefined && value !== null && value !== '');

const pickCount = (...values: any[]) => {
  for (const value of values) {
    if (typeof value === 'number' && Number.isFinite(value)) return value;
    if (typeof value === 'string' && value.trim() !== '' && !Number.isNaN(Number(value))) return Number(value);
  }
  return 0;
};

const buildProfileStat = (
  key: string,
  label: string,
  values: any[],
  description: string,
  alwaysShow = false
) => {
  if (!alwaysShow && !hasCountSource(...values)) return null;
  return {
    key,
    label,
    value: pickCount(...values),
    description,
  };
};

const getMetricSubtitle = (key: string) => {
  switch (key) {
    case 'followers':
      return 'Follows you';
    case 'following':
      return 'You follow';
    case 'matches':
      return 'Matched profile';
    case 'likes-received':
      return 'Liked you';
    case 'views-received':
      return 'Viewed your profile';
    case 'dislikes-received':
      return 'Disliked you';
    case 'likes-given':
      return 'You liked';
    case 'views-given':
      return 'You viewed';
    case 'dislikes-given':
      return 'You disliked';
    case 'blocked':
      return 'Blocked';
    default:
      return 'Profile';
  }
};

const isProfileOwnerEntity = (entity: any, ownerId: string | null, ownerPublicId: string | null) => {
  if (!entity) return false;
  const entityId = entity?.id ? String(entity.id) : null;
  const entityPublicId = entity?.public_id ? String(entity.public_id) : null;
  if (ownerId && entityId && entityId === ownerId) return true;
  if (ownerPublicId && entityPublicId && entityPublicId === ownerPublicId) return true;
  return false;
};

const getEngagementDirection = (detail: any, ownerId: string | null, ownerPublicId: string | null): 'incoming' | 'outgoing' | null => {
  const engager = detail?.engager || detail?.user || detail?.actor;
  const engagee = detail?.engagee || detail?.target || detail?.profile;

  if (engager && isProfileOwnerEntity(engager, ownerId, ownerPublicId) && (!engagee || !isProfileOwnerEntity(engagee, ownerId, ownerPublicId))) {
    return 'outgoing';
  }
  if (engagee && isProfileOwnerEntity(engagee, ownerId, ownerPublicId) && (!engager || !isProfileOwnerEntity(engager, ownerId, ownerPublicId))) {
    return 'incoming';
  }
  return null;
};

const getOtherEngagementUser = (detail: any, ownerId: string | null, ownerPublicId: string | null) => {
  const engager = detail?.engager || detail?.user || detail?.actor;
  const engagee = detail?.engagee || detail?.target || detail?.profile;

  if (engager && !isProfileOwnerEntity(engager, ownerId, ownerPublicId)) return engager;
  if (engagee && !isProfileOwnerEntity(engagee, ownerId, ownerPublicId)) return engagee;
  return engager || engagee || null;
};

const matchesMetricKey = (detail: any, statKey: string, ownerId: string | null, ownerPublicId: string | null) => {
  const kind = String(detail?.kind || detail?.engagement_kind || detail?.type || '').toLowerCase();
  const normalizedKind = kind.replace(/[\s-]+/g, '_');
  const direction = getEngagementDirection(detail, ownerId, ownerPublicId);
  const isLike = kind.includes('like') && !kind.includes('dislike');
  const isDislike = kind.includes('dislike');
  const isView = kind.includes('view');
  const isFollow = kind.includes('follow');
  const isBlock = kind.includes('block');
  const isMatch = kind.includes('match');

  switch (statKey) {
    case 'followers':
      return normalizedKind.includes('follower') || (isFollow && direction === 'incoming');
    case 'following':
      return normalizedKind.includes('following') || normalizedKind.includes('following_user') || (isFollow && direction === 'outgoing');
    case 'matches':
      return isMatch;
    case 'likes-received':
      return normalizedKind.includes('like_received') || normalizedKind.includes('likes_received') || (isLike && direction === 'incoming');
    case 'views-received':
      return normalizedKind.includes('view_received') || normalizedKind.includes('views_received') || (isView && direction === 'incoming');
    case 'dislikes-received':
      return normalizedKind.includes('dislike_received') || normalizedKind.includes('dislikes_received') || (isDislike && direction === 'incoming');
    case 'likes-given':
      return normalizedKind.includes('like_given') || normalizedKind.includes('likes_given') || (isLike && direction === 'outgoing');
    case 'views-given':
      return normalizedKind.includes('view_given') || normalizedKind.includes('views_given') || (isView && direction === 'outgoing');
    case 'dislikes-given':
      return normalizedKind.includes('dislike_given') || normalizedKind.includes('dislikes_given') || (isDislike && direction === 'outgoing');
    case 'blocked':
      return normalizedKind.includes('blocking') || (isBlock && direction === 'outgoing');
    default:
      return false;
  }
};

const normalizeMetricItem = (source: any, statKey: string): ProfileMetricDetailItem | null => {
  const entity = source?.user || source?.profile || source?.target || source?.member || source;
  if (!entity) return null;

  const idCandidate = entity?.id ?? entity?.public_id ?? source?.id ?? source?.public_id ?? entity?.username ?? source?.username;
  const username = String(entity?.username ?? source?.username ?? '').replace(/^@/, '');
  const name = String(
    entity?.displayname ??
    entity?.display_name ??
    entity?.name ??
    source?.displayname ??
    source?.display_name ??
    source?.name ??
    username ??
    'User'
  );
  const publicId = entity?.public_id ?? source?.public_id ?? idCandidate;
  const avatar =
    getSafeImageURLEx(
      publicId,
      entity?.avatar ?? entity?.avatar_url ?? entity?.avatarUrl ?? source?.avatar ?? source?.avatar_url ?? source?.avatarUrl,
      'medium'
    ) ||
    entity?.avatar_url ||
    entity?.avatarUrl ||
    source?.avatar_url ||
    source?.avatarUrl ||
    '';

  if (!idCandidate && !username && !name) return null;

  return {
    id: String(idCandidate ?? username ?? name),
    name,
    username,
    avatar,
    subtitle: getMetricSubtitle(statKey),
  };
};

const dedupeMetricItems = (items: (ProfileMetricDetailItem | null)[]) => {
  const unique = new Map<string, ProfileMetricDetailItem>();
  items.forEach((item) => {
    if (!item || !item.id) return;
    if (!unique.has(item.id)) unique.set(item.id, item);
  });
  return Array.from(unique.values());
};

export const formatCompactMetricCount = (value: number) => {
  if (value >= 1000000) return `${(value / 1000000).toFixed(value >= 10000000 ? 0 : 1)}M`;
  if (value >= 1000) return `${(value / 1000).toFixed(value >= 10000 ? 0 : 1)}K`;
  return String(value);
};

export const formatMetricCount = (value: number, language = 'en') =>
  new Intl.NumberFormat(language === 'tr' ? 'tr-TR' : 'en-US').format(value);

export const buildProfileMetrics = (user: any): ProfileMetricStat[] => {
  const engagementCounts = user?.engagements?.counts || {};

  return [
    buildProfileStat('followers', 'Followers', [
      user?.followers_count,
      user?.followersCount,
      user?.stats?.followers_count,
      user?.stats?.followers,
      engagementCounts?.follower_count,
    ], 'People who follow your profile.', true),
    buildProfileStat('following', 'Following', [
      user?.following_count,
      user?.followingCount,
      user?.stats?.following_count,
      user?.stats?.following,
      engagementCounts?.following_count,
    ], 'Profiles you are following.', true),
    buildProfileStat('posts', 'Posts', [
      user?.posts_count,
      user?.postsCount,
      user?.post_count,
      user?.postCount,
      user?.stats?.posts_count,
      user?.stats?.posts,
      engagementCounts?.post_count,
    ], 'Posts or vibes published from this account.'),
    buildProfileStat('matches', 'Matches', [
      user?.match_count,
      user?.matchCount,
      user?.stats?.match_count,
      user?.stats?.matches,
      engagementCounts?.match_count,
    ], 'Mutual connections created with other users.'),
    buildProfileStat('likes-received', 'Likes', [
      user?.like_received_count,
      user?.likeReceivedCount,
      user?.likes_count,
      user?.likesCount,
      user?.stats?.like_received_count,
      user?.stats?.likes,
      engagementCounts?.like_received_count,
    ], 'Likes received from other users.'),
    buildProfileStat('views-received', 'Views Received', [
      user?.view_received_count,
      user?.viewReceivedCount,
      user?.stats?.view_received_count,
      user?.stats?.views_received,
      engagementCounts?.view_received_count,
    ], 'How many profile or content views you received.'),
    buildProfileStat('dislikes-received', 'Dislikes Received', [
      user?.dislike_received_count,
      user?.dislikeReceivedCount,
      user?.stats?.dislike_received_count,
      user?.stats?.dislikes_received,
      engagementCounts?.dislike_received_count,
    ], 'Negative reactions received from other users.'),
    buildProfileStat('likes-given', 'Likes Given', [
      user?.like_given_count,
      user?.likeGivenCount,
      user?.stats?.like_given_count,
      user?.stats?.likes_given,
      engagementCounts?.like_given_count,
    ], 'Likes you have given to other profiles or content.'),
    buildProfileStat('views-given', 'Views Given', [
      user?.view_given_count,
      user?.viewGivenCount,
      user?.stats?.view_given_count,
      user?.stats?.views_given,
      engagementCounts?.view_given_count,
    ], 'Profiles or content you have viewed.'),
    buildProfileStat('dislikes-given', 'Dislikes Given', [
      user?.dislike_given_count,
      user?.dislikeGivenCount,
      user?.stats?.dislike_given_count,
      user?.stats?.dislikes_given,
      engagementCounts?.dislike_given_count,
    ], 'Dislikes you have sent to other profiles or content.'),
    buildProfileStat('blocked', 'Blocked Users', [
      user?.blocking_count,
      user?.blockingCount,
      user?.stats?.blocking_count,
      engagementCounts?.blocking_count,
    ], 'Users you have blocked from interacting with you.'),
  ].filter(Boolean) as ProfileMetricStat[];
};

export const resolveProfileMetricItems = (user: any, statKey: string): ProfileMetricDetailItem[] => {
  const ownerId = user?.id ? String(user.id) : null;
  const ownerPublicId = user?.public_id ? String(user.public_id) : null;
  const engagementDetails =
    Array.isArray(user?.engagements?.engagement_details) ? user.engagements.engagement_details
    : Array.isArray(user?.engagements) ? user.engagements
    : Array.isArray(user?.engagement_details) ? user.engagement_details
    : [];

  const detailItems = engagementDetails
    .filter((detail: any) => matchesMetricKey(detail, statKey, ownerId, ownerPublicId))
    .map((detail: any) => normalizeMetricItem(getOtherEngagementUser(detail, ownerId, ownerPublicId), statKey));

  const fallbackItemsByKey: Record<string, any[]> = {
    followers:
      (Array.isArray(user?.followers) && user.followers) ||
      (Array.isArray(user?.followers_list) && user.followers_list) ||
      (Array.isArray(user?.follower_users) && user.follower_users) ||
      (Array.isArray(user?.follower_profiles) && user.follower_profiles) ||
      (Array.isArray(user?.engagements?.followers) && user.engagements.followers) ||
      [],
    following:
      (Array.isArray(user?.following) && user.following) ||
      (Array.isArray(user?.following_list) && user.following_list) ||
      (Array.isArray(user?.following_users) && user.following_users) ||
      (Array.isArray(user?.followees) && user.followees) ||
      (Array.isArray(user?.engagements?.following) && user.engagements.following) ||
      [],
    matches:
      (Array.isArray(user?.matches) && user.matches) ||
      (Array.isArray(user?.matched_users) && user.matched_users) ||
      (Array.isArray(user?.engagements?.matches) && user.engagements.matches) ||
      [],
    blocked:
      (Array.isArray(user?.blocked_users) && user.blocked_users) ||
      (Array.isArray(user?.blocking) && user.blocking) ||
      (Array.isArray(user?.blocked) && user.blocked) ||
      (Array.isArray(user?.engagements?.blocking) && user.engagements.blocking) ||
      [],
  };

  const fallbackItems = (fallbackItemsByKey[statKey] || []).map((item: any) => normalizeMetricItem(item, statKey));

  return dedupeMetricItems([...fallbackItems, ...detailItems]);
};
