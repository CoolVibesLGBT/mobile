import 'dart:convert';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/components/app_image.dart';
import 'package:coolvibes/components/checkin_radar.dart';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/core/checkin_data.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/screens/feed.dart';
import 'package:coolvibes/screens/media.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  final coffee = <String, dynamic>{
    'tag': 'coffee_date',
    'name': {'tr': 'Kahve Buluşması', 'en': 'Coffee Date'},
    'icon': '/static/checkin/coffee_date.avif',
    'thumb': '/static/checkin/256/coffee_date.avif',
    'is_visible': true,
  };

  test('initial sync unwraps tags and honors backend visibility', () {
    final system = {
      'checkin_tag_types': [
        coffee,
        {...coffee, 'tag': 'hidden', 'is_visible': false},
        coffee,
        {'tag': ''},
        null,
      ],
    };
    expect(checkInTagRecords(system), [coffee]);
    expect(checkInTagRecords({'data': system}), [coffee]);
    expect(checkInTagRecords({'checkin_tag_types': 'invalid'}), isEmpty);
  });

  test('artwork prefers backend thumbnails and supports legacy icon names', () {
    expect(checkInTagImage(coffee), '/static/checkin/256/coffee_date.avif');
    expect(
      checkInTagImage(coffee, thumbnail: false),
      '/static/checkin/coffee_date.avif',
    );
    expect(
      checkInTagImage({...coffee, 'thumb': null}),
      '/static/checkin/coffee_date.avif',
    );
    expect(checkInTagImage({'icon': 'coffee'}), isNull);
    for (final value in ['javascript:alert(1)', 'file:///secret', '//host/a']) {
      expect(checkInTagImage({'icon': value}), isNull);
    }
    expect(
      checkInTagImage({'icon': 'https://cdn.example.com/coffee.avif'}),
      'https://cdn.example.com/coffee.avif',
    );
    expect(
      assetUrl(checkInTagImage(coffee)),
      Uri.parse(
        Api.baseUrl,
      ).resolve('/static/checkin/256/coffee_date.avif').toString(),
    );
  });

  test('search handles Turkish keyboard variations, words and source tags', () {
    final tags = [
      coffee,
      <String, dynamic>{
        'tag': 'walking',
        'name': {'tr': 'Yürüyüş'},
      },
    ];
    expect(searchCheckInTags(tags, 'kahve bulusmasi', 'tr'), [coffee]);
    expect(searchCheckInTags(tags, 'BULUŞMASI', 'tr'), [coffee]);
    expect(searchCheckInTags(tags, 'coffee_date', 'tr'), [coffee]);
    expect(searchCheckInTags(tags, 'yuruyus', 'tr'), [tags.last]);
    expect(searchCheckInTags(tags, 'unknown', 'tr'), isEmpty);
    expect(searchCheckInTags(tags, '  ', 'tr'), tags);
    expect(checkInTagText({'tag': 'new_friends'}, 'tr'), 'new friends');
  });

  test('check-in posts decode extras and resolve published tag artwork', () {
    final system = {
      'checkin_tag_types': [coffee],
    };
    final extras = {
      'tags': ['coffee_date', 'coffee_date', 'walking', null],
    };
    for (final raw in [extras, jsonEncode(extras)]) {
      final tags = checkInPostTags({
        'post_kind': 'checkin',
        'extras': raw,
      }, system);
      expect(tags, [
        coffee,
        {'tag': 'walking'},
      ]);
      expect(checkInTagImage(tags.last), '/static/checkin/256/walking.avif');
    }
    expect(
      checkInPostTags({'post_kind': 'post', 'extras': extras}, system),
      isEmpty,
    );
    expect(
      checkInPostTags({'post_kind': 'checkin', 'extras': 'bad JSON'}, system),
      isEmpty,
    );
    expect(checkInTagImage({'tag': '../private'}), isNull);
  });

  for (final encoded in [false, true]) {
    testWidgets(
      'production card renders check-in artwork with uploaded media (encoded: $encoded)',
      (tester) async {
        final previousInterval =
            VisibilityDetectorController.instance.updateInterval;
        VisibilityDetectorController.instance.updateInterval = Duration.zero;
        addTearDown(
          () => VisibilityDetectorController.instance.updateInterval =
              previousInterval,
        );
        final session =
            Session(
                PreviewApi(PreviewState.populated),
                persistPreferences: false,
              )
              ..ready = true
              ..user = previewSelf
              ..system = {
                'checkin_tag_types': [coffee],
              };
        final extras = {
          'tags': ['coffee_date', 'walking'],
        };
        final post = <String, dynamic>{
          ...previewPost,
          'post_kind': 'checkin',
          'extras': encoded ? jsonEncode(extras) : extras,
          'attachments': [
            {
              'url': '/static/uploads/checkin-photo.jpg',
              'mime_type': 'image/jpeg',
            },
          ],
        };
        await tester.pumpWidget(
          CoolvibesApp(
            session: session,
            home: Scaffold(
              body: SingleChildScrollView(
                child: PostTile(post: post, reload: () {}),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(CheckInPostTags), findsOneWidget);
        expect(find.byType(MediaAttachments), findsOneWidget);
        expect(find.text('Kahve Buluşması'), findsOneWidget);
        final artwork = tester.widgetList<AppImage>(
          find.descendant(
            of: find.byType(CheckInPostTags),
            matching: find.byType(AppImage),
          ),
        );
        expect(artwork.map((image) => image.source), [
          '/static/checkin/256/coffee_date.avif',
          '/static/checkin/256/walking.avif',
        ]);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        session.dispose();
        await tester.pump();
      },
    );
  }

  testWidgets('backend artwork uses the shared image owner at requested size', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(child: CheckInTagArtwork(tag: coffee, size: 44)),
      ),
    );
    final image = tester.widget<AppImage>(find.byType(AppImage));
    expect(image.source, '/static/checkin/256/coffee_date.avif');
    expect(image.width, 44);
    expect(image.height, 44);
    expect(tester.takeException(), isNull);
  });
}
