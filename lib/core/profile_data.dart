import 'api.dart';
import 'chat_data.dart';

bool profileFlag(dynamic value) => const [true, 1, '1', 'true'].contains(value);

Json profileUser(dynamic value) {
  var record = object(value);
  for (var depth = 0; depth < 4; depth++) {
    final nested = record['user'] ?? record['profile'] ?? record['data'];
    if (nested is! Map) break;
    record = object(nested);
  }
  return record;
}

String profileUsername(Json value) =>
    [value['username'], value['nickname'], value['user_name']]
        .map(string)
        .map((v) => v.trim())
        .firstWhere((v) => v.isNotEmpty, orElse: () => '');

String? profileCover(Json user) {
  for (final key in [
    'cover',
    'cover_image',
    'cover_photo',
    'cover_image_url',
    'cover_url',
    'banner_url',
  ]) {
    final source = user[key];
    final media = object(source), file = object(media['file']);
    final images = object(
      object(file['variants'] ?? media['variants'])['image'],
    );
    for (final candidate in [
      if (source is String) source.trim(),
      images['original'],
      file['url'],
      media['url'],
      media['src'],
      images['large'],
      images['medium'],
      images['small'],
      images['thumbnail'],
    ]) {
      final url = assetUrl(candidate);
      if (url.isNotEmpty) return url;
    }
  }
  return null;
}

bool profileBelongsTo(Json value, Json self) {
  final user = profileUser(value), current = profileUser(self);
  if (userIdentities(user).intersection(userIdentities(current)).isNotEmpty) {
    return true;
  }
  final name = profileUsername(user).toLowerCase();
  return name.isNotEmpty && name == profileUsername(current).toLowerCase();
}

bool profileFollowing(Json user) => profileFlag(
  user['is_following'] ?? user['isFollowing'] ?? user['followed'],
);
bool profileBlocked(Json user) =>
    profileFlag(user['is_blocked'] ?? user['is_blocking'] ?? user['blocked']);

bool canViewProfileActivity(
  Json user, {
  required bool own,
  required bool authenticated,
}) {
  if (own) return true;
  if (!authenticated || profileBlocked(user)) return false;
  final follows = profileFollowing(user);
  final mutual =
      follows &&
      [
        'is_followed_by',
        'followed_by_current_user',
        'is_follower',
        'follows_viewer',
        'viewer_is_followed_by_user',
      ].any((key) => profileFlag(user[key]));
  return switch (user['privacy_level']) {
    null || 'public' => true,
    'followers_only' => follows,
    'friends_only' || 'mutuals_only' => mutual,
    _ => false,
  };
}

String profileLocationLabel(dynamic location) {
  if (location is String) return location;
  final data = object(location);
  return [
        data['display'],
        data['address'],
        data['name'],
        data['formatted_address'],
      ]
      .map(string)
      .firstWhere((value) => value.trim().isNotEmpty, orElse: () => '');
}

String profileBioText(dynamic bio) => plainText(bio)
    .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'</(?:p|div|li|h[1-6])>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&amp;', '&')
    .trim();
