import 'api.dart';
import 'geo.dart';
import 'localized_content.dart';

Json placeInfo(Json place) =>
    object(object(decodeContent(place['extras']))['place']);
String placeDefaultLanguage(Json place) => [
  place['default_language'],
  object(decodeContent(place['metadata']))['default_language'],
  placeInfo(place)['default_language'],
  object(place['author'])['default_language'],
  'en',
].map(string).firstWhere((value) => value.isNotEmpty);
String placeText(Json place, dynamic value, String language) => localizedText(
  value,
  language: language,
  defaultLanguage: placeDefaultLanguage(place),
);
String placeTitle(Json place, String language) =>
    [place['title'], place['name'], placeInfo(place)['name']]
        .map((value) => placeText(place, value, language))
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
dynamic placeContent(Json place, String language) {
  for (final value in [
    place['content'],
    place['description'],
    placeInfo(place)['description'],
  ]) {
    final selected = localizedContent(
      value,
      language: language,
      defaultLanguage: placeDefaultLanguage(place),
    );
    if (contentIsPresent(selected)) return selected;
  }
  return '';
}

String placeAddress(Json place, String language) =>
    [
          object(place['location'])['address'],
          placeInfo(place)['address'],
          place['address'],
          object(place['location'])['display'],
        ]
        .map((value) => placeText(place, value, language))
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
String placeRegion(Json place, String language) {
  final info = placeInfo(place), location = object(place['location']);
  return [
        location['city'] ?? location['town'] ?? info['town'],
        location['region'] ?? location['province'] ?? info['province'],
        location['country'] ?? info['country'],
      ]
      .map((value) => placeText(place, value, language))
      .where((value) => value.isNotEmpty)
      .toSet()
      .join(', ');
}

Json? placeCoordinates(Json place) =>
    coordinatesOf(place) ?? coordinatesOf(placeInfo(place));
dynamic placeImage(Json place) {
  if (place['localAsset'] != null) return null;
  for (final raw in [
    placeInfo(place)['image'],
    place['image'],
    place['cover'],
  ]) {
    if (raw is Map && raw.isNotEmpty ||
        raw is String && raw.trim().isNotEmpty) {
      return raw;
    }
  }
  final attachments = place['attachments'];
  return attachments is List && attachments.isNotEmpty
      ? attachments.first
      : null;
}

List<String> placeTags(Json place) => [
  for (final tag
      in place['hashtags'] is List ? place['hashtags'] as List : const [])
    string(tag is String ? tag : object(tag)['tag']),
].where((tag) => tag.isNotEmpty).toSet().toList();

Json? placeFromResponse(Json response, String id) {
  final data = response['data'] ?? response;
  final map = object(data);
  final candidates = [
    map['post'],
    map['place'],
    map,
    if (map['places'] is List) ...map['places'] as List,
    if (data is List) ...data,
  ];
  for (final value in candidates) {
    final item = object(value);
    if (recordId(item) == id &&
        id.isNotEmpty &&
        (item['post_kind'] == null || item['post_kind'] == 'place')) {
      return item;
    }
  }
  return null;
}

Uri? placeWebsite(Json place) {
  final info = placeInfo(place), urls = placeInfo(place)['urls'];
  final candidates = [
    if (urls is List) ...urls,
    info['website'],
    place['website'],
  ].map(string).map((value) => value.trim());
  for (final raw in candidates) {
    if (raw.isEmpty || RegExp(r'\s').hasMatch(raw)) continue;
    final uri = Uri.tryParse(raw);
    if (uri == null) continue;
    final parsed = uri.hasScheme ? uri : Uri.tryParse('https://$raw');
    if (parsed != null &&
        ['https', 'http'].contains(parsed.scheme) &&
        parsed.host.isNotEmpty) {
      return parsed;
    }
  }
  return null;
}

Uri? placeDirections(Json place, String language) {
  final point = placeCoordinates(place),
      address = placeAddress(place, language);
  final target = point != null
      ? '${point['latitude']},${point['longitude']}'
      : address;
  if (target.isEmpty) return null;
  return Uri.https('maps.apple.com', '/', {'daddr': target});
}
