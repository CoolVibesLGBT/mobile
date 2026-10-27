import 'api.dart';
import 'localized_content.dart';

Json classifiedExtras(Json post) => object(decodeContent(post['extras']));
String classifiedDefaultLanguage(Json post) => string(
  post['default_language'] ??
      classifiedExtras(post)['default_language'] ??
      object(post['author'])['default_language'] ??
      'en',
);
String classifiedTitle(Json post, String language) =>
    [post['title'], classifiedExtras(post)['title']]
        .map(
          (value) => localizedText(
            value,
            language: language,
            defaultLanguage: classifiedDefaultLanguage(post),
          ),
        )
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
String classifiedKind(Json post) => string(post['post_kind'] ?? post['kind']);
List<({String label, String value})> classifiedMetadata(
  Json post,
  String language,
) {
  final raw = decodeContent(
    classifiedExtras(post)['metadata'] ?? post['metadata'],
  );
  final entries = raw is List
      ? raw
      : raw is Map
      ? [
          for (final entry in raw.entries)
            {'key': entry.key, 'value': entry.value},
        ]
      : const [];
  return [
    for (final entry in entries)
      (
        label: localizedText(
          object(entry)['key'],
          language: language,
          defaultLanguage: classifiedDefaultLanguage(post),
        ),
        value: localizedText(
          object(entry)['value'],
          language: language,
          defaultLanguage: classifiedDefaultLanguage(post),
        ),
      ),
  ].where((entry) => entry.label.isNotEmpty && entry.value.isNotEmpty).toList();
}

bool classifiedMatches(Json post, String query, String language) {
  final words = query.trim().toLowerCase().split(RegExp(r'\s+'));
  final searchable = [
    classifiedTitle(post, language),
    localizedText(
      post['content'],
      language: language,
      defaultLanguage: classifiedDefaultLanguage(post),
    ),
    for (final pair in classifiedMetadata(post, language))
      '${pair.label} ${pair.value}',
  ].join(' ').toLowerCase();
  return words.every(searchable.contains);
}

Json? classifiedFromResponse(Json response, String id) {
  final data = response['data'] ?? response;
  final map = object(data);
  for (final raw in [
    map['post'],
    map['item'],
    map['result'],
    map,
    if (data is List) ...data,
  ]) {
    final record = object(raw);
    if (id.isNotEmpty &&
        recordId(record) == id &&
        [
          '',
          'job_offer',
          'job_search',
          'classified',
        ].contains(classifiedKind(record))) {
      return record;
    }
  }
  return null;
}
