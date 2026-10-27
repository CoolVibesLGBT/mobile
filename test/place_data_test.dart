import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/core/localized_content.dart';
import 'package:coolvibes/core/place_data.dart';

void main() {
  test(
    'localized content selects locale, source default, then available text',
    () {
      final translated = {'ja': '日本語', 'en': 'English', 'tr': 'Türkçe'};
      expect(localizedText(translated, language: 'tr-TR'), 'Türkçe');
      expect(
        localizedText({'pt_BR': 'Brasil', 'pt': 'Portugal'}, language: 'pt-BR'),
        'Brasil',
      );
      expect(
        localizedText(translated, language: 'ar', defaultLanguage: 'en'),
        'English',
      );
      expect(localizedText(translated, language: 'ar'), '日本語');
      expect(
        localizedText({'tr': '  ', 'en': '', 'ja': '日本語'}, language: 'tr'),
        '日本語',
      );
      expect(localizedText(null, language: 'tr'), '');
      expect(
        localizedText('Plain description', language: 'tr'),
        'Plain description',
      );
    },
  );

  test(
    'encoded translations and blank Lexical documents preserve rich fallback',
    () {
      final document = lexical('Rich fallback');
      final raw = jsonEncode({
        'tr': jsonEncode(lexical('  ')),
        'en': jsonEncode(document),
      });
      expect(localizedDocument(raw, language: 'tr'), document);
      expect(localizedText(raw, language: 'tr'), 'Rich fallback');
      expect(contentIsPresent(lexical('')), isFalse);
      expect(
        contentIsPresent({
          'root': {'type': 'root', 'children': null},
        }),
        isFalse,
      );
      expect(
        localizedText({'ja': jsonEncode(lexical('神戸の公園'))}, language: 'tr'),
        '神戸の公園',
      );
    },
  );

  test(
    'place metadata and source language are shared by every presentation',
    () {
      final place = <String, dynamic>{
        'id': '42',
        'title': {'tr': '', 'ja': '日本語', 'en': 'English'},
        'content': {'tr': '', 'ja': jsonEncode(lexical('日本語の内容'))},
        'default_language': 'ja',
        'extras': jsonEncode({
          'place': {
            'name': 'Venue',
            'address': 'Street 42',
            'town': 'Kobe',
            'country': 'Japan',
            'latitude': 34.6,
            'longitude': 135.2,
            'website': 'example.com/place',
          },
        }),
      };
      expect(placeTitle(place, 'tr'), '日本語');
      expect(plainText(placeContent(place, 'tr')), '日本語の内容');
      expect(placeAddress(place, 'tr'), 'Street 42');
      expect(placeRegion(place, 'tr'), 'Kobe, Japan');
      expect(
        placeDirections(place, 'tr')!.queryParameters['daddr'],
        '34.6,135.2',
      );
      expect(placeWebsite(place).toString(), 'https://example.com/place');
      expect(placeDirections({}, 'tr'), isNull);
      expect(
        placeTitle({
          'extras': {
            'place': {'name': 'Venue'},
          },
        }, 'en'),
        'Venue',
      );
    },
  );

  test('detail response must match the requested public ID and place kind', () {
    final target = <String, dynamic>{'public_id': '42', 'post_kind': 'place'};
    final wrong = <String, dynamic>{'public_id': '11', 'post_kind': 'place'};
    for (final data in [
      target,
      {'post': target},
      {'place': target},
      {
        'places': [wrong, target],
      },
      [wrong, target],
    ]) {
      expect(placeFromResponse({'data': data}, '42'), target);
    }
    for (final data in [
      wrong,
      {
        'places': [wrong],
      },
      {'places': 'invalid'},
      {...target, 'post_kind': 'message'},
    ]) {
      expect(placeFromResponse({'data': data}, '42'), isNull);
    }
    expect(placeFromResponse({'data': target}, ''), isNull);
  });

  test(
    'contact URLs reject unsafe schemes and try the next usable website',
    () {
      for (final value in [
        'javascript:alert(1)',
        'file:///tmp/place',
        'https://',
        'not a website',
      ]) {
        expect(placeWebsite({'website': value}), isNull);
      }
      expect(
        placeWebsite({
          'extras': {
            'place': {
              'urls': ['javascript:bad', 'https://example.com/info'],
            },
          },
        }).toString(),
        'https://example.com/info',
      );
    },
  );
}
