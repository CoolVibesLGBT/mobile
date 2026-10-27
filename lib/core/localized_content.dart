import 'dart:convert';
import 'api.dart';

dynamic decodeContent(dynamic value) {
  for (var depth = 0; depth < 12 && value is String; depth++) {
    final text = value.trim();
    if (!text.startsWith('{') &&
        !text.startsWith('[') &&
        !text.startsWith('"')) {
      break;
    }
    try {
      value = jsonDecode(text);
    } catch (_) {
      break;
    }
  }
  return value;
}

bool contentIsPresent(dynamic raw) {
  final value = decodeContent(raw);
  if (value is String) return value.trim().isNotEmpty;
  if (value is List) return value.any(contentIsPresent);
  if (value is! Map) return false;
  if (value['root'] != null) return contentIsPresent(value['root']);
  if (value['type'] != null) {
    if (contentIsPresent(value['text'])) return true;
    if ([
      'image',
      'inline-image',
      'video',
      'youtube',
      'horizontalrule',
    ].contains(value['type'])) {
      return true;
    }
    return contentIsPresent(value['children']);
  }
  return value.values.any(contentIsPresent);
}

/// Requested locale, source default, then the first available translation.
dynamic localizedContent(
  dynamic raw, {
  required String language,
  String? defaultLanguage,
}) {
  final value = decodeContent(raw);
  if (value is! Map || value.containsKey('root') || value.containsKey('type')) {
    return value;
  }
  String normalize(String key) => key.toLowerCase().replaceAll('_', '-');
  final translations = {
    for (final entry in value.entries) normalize('${entry.key}'): entry.value,
  };
  for (final locale in [language, ?defaultLanguage]) {
    final key = normalize(locale);
    for (final candidate in [key, key.split('-').first]) {
      final translated = translations[candidate];
      if (contentIsPresent(translated)) return decodeContent(translated);
    }
  }
  for (final translated in translations.values) {
    if (contentIsPresent(translated)) return decodeContent(translated);
  }
  return '';
}

String localizedText(
  dynamic value, {
  required String language,
  String? defaultLanguage,
}) => plainText(
  localizedContent(value, language: language, defaultLanguage: defaultLanguage),
).trim();

Json localizedDocument(
  dynamic value, {
  required String language,
  String? defaultLanguage,
}) {
  final selected = localizedContent(
    value,
    language: language,
    defaultLanguage: defaultLanguage,
  );
  final document = object(selected);
  if (document['root'] is Map) return document;
  if (document['type'] == 'root') return {'root': document};
  return lexical(plainText(selected));
}
