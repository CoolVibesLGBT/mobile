import 'api.dart';
import 'localized_content.dart';

/// system.initialSync is the owner of check-in tags and their artwork.
List<Json> checkInTagRecords(Json system, {bool includeHidden = false}) {
  final data = system['data'] is Map ? object(system['data']) : system;
  final raw = data['checkin_tag_types'];
  if (raw is! List) return [];
  final seen = <String>{};
  return raw.map(object).where((tag) {
    final key = string(tag['tag']).trim();
    return key.isNotEmpty &&
        (includeHidden || tag['is_visible'] != false) &&
        seen.add(key);
  }).toList();
}

String checkInTagText(Json tag, String language) {
  final text = localizedText(
    tag['name'],
    language: language,
    defaultLanguage: 'en',
  ).trim();
  return text.isNotEmpty ? text : string(tag['tag']).replaceAll('_', ' ');
}

/// New backend payloads supply thumb/icon URLs. Like the web client, a
/// historical post with only a stable tag slug can resolve public artwork
/// before initial sync finishes. Icon font names are never used as URLs.
String? checkInTagImage(Json tag, {bool thumbnail = true}) {
  for (final key in thumbnail ? ['thumb', 'icon'] : ['icon', 'thumb']) {
    final value = tag[key];
    if (value is! String) continue;
    final raw = value.trim();
    final uri = Uri.tryParse(raw);
    if (uri == null || raw.isEmpty) continue;
    if ((uri.hasScheme &&
            ['https', 'http'].contains(uri.scheme) &&
            uri.host.isNotEmpty) ||
        (!uri.hasAuthority && raw.startsWith('/static/'))) {
      return raw;
    }
  }
  final slug = string(tag['tag']);
  if (!RegExp(r'^[a-z0-9_]+$').hasMatch(slug)) return null;
  return '/static/checkin/${thumbnail ? '256/' : ''}$slug.avif';
}

/// Post.tsx displays checkin extras.tags independently of uploaded media.
/// Historical tags remain readable even after they leave the creation menu.
List<Json> checkInPostTags(Json post, Json system) {
  if (post['post_kind'] != 'checkin' && post['type'] != 'checkin') return [];
  final tags = object(decodeContent(post['extras']))['tags'];
  if (tags is! List) return [];
  final definitions = {
    for (final tag in checkInTagRecords(system, includeHidden: true))
      string(tag['tag']): tag,
  };
  final seen = <String>{};
  return [
    for (final raw in tags)
      if (raw is String && raw.trim().isNotEmpty && seen.add(raw.trim()))
        definitions[raw.trim()] ?? {'tag': raw.trim()},
  ];
}

String _searchText(String text) => text
    .replaceAll('İ', 'i')
    .replaceAll('ı', 'i')
    .toLowerCase()
    .replaceAll('ç', 'c')
    .replaceAll('ğ', 'g')
    .replaceAll('ö', 'o')
    .replaceAll('ş', 's')
    .replaceAll('ü', 'u')
    .replaceAll('_', ' ');

List<Json> searchCheckInTags(List<Json> tags, String query, String language) {
  final terms = _searchText(query).trim().split(RegExp(r'\s+'));
  if (terms.every((term) => term.isEmpty)) return tags;
  return tags.where((tag) {
    final haystack = _searchText(
      [
        checkInTagText(tag, language),
        checkInTagText(tag, 'en'),
        string(tag['tag']),
      ].join(' '),
    );
    return terms.every(haystack.contains);
  }).toList();
}
