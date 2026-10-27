import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/components/article_content.dart';
import 'package:coolvibes/components/components.dart';
import 'package:coolvibes/components/place_row.dart';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/screens/composer.dart';
import 'package:coolvibes/screens/places.dart';
import 'support/contract_api.dart';
import 'support/ui_driver.dart';

final translatedPlace = <String, dynamic>{
  'id': 'place-id',
  'public_id': 'place-42',
  'post_kind': 'place',
  'default_language': 'en',
  'title': {'tr': 'Sahil Bahçesi', 'en': 'Seaside Garden', 'ar': 'حديقة البحر'},
  'content': {
    'tr': jsonEncode({
      'root': {
        'type': 'root',
        'children': [
          {
            'type': 'heading',
            'tag': 'h2',
            'children': [
              {'type': 'text', 'text': 'Bahçe hakkında'},
            ],
          },
          {
            'type': 'paragraph',
            'children': [
              {'type': 'text', 'text': 'Deniz kenarında ', 'format': 1},
              {
                'type': 'link',
                'url': 'https://example.com',
                'children': [
                  {'type': 'text', 'text': 'bir buluşma noktası.'},
                ],
              },
            ],
          },
        ],
      },
    }),
    'en': jsonEncode(lexical('A garden by the sea.')),
    'ar': jsonEncode(lexical('حديقة على شاطئ البحر.')),
  },
  'extras': {
    'place': {
      'address': 'Sahil Sokak 42',
      'town': 'Kadıköy',
      'country': 'Türkiye',
      'telephone': '+902161234567',
      'website': 'https://example.com/garden',
    },
  },
  'children': <Json>[],
};
final japanesePlace = <String, dynamic>{
  'public_id': 'place-ja',
  'post_kind': 'place',
  'title': {'ja': '神戸の公園'},
  'content': {'ja': jsonEncode(lexical('日本語の案内'))},
  'children': <Json>[],
};

class PlacesApi extends ContractApi {
  List<Json> venueRecords = [japanesePlace, translatedPlace];
  Json? detail;
  bool failDetail = false;
  int details = 0;
  Completer<Json>? pendingReaction, pendingComment;
  final requests = <({String action, Json body})>[];
  @override
  Future<Json> call(
    String action, {
    Json body = const {},
    bool get = false,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    Duration? receiveTimeout,
  }) async {
    requests.add((action: action, body: {...body}));
    if (action == 'place.fetch') {
      return {
        'data': {
          'places': venueRecords,
          'cursor': {'next': null},
        },
      };
    }
    if (action.startsWith('place.')) {
      throw StateError('Unregistered place route: $action');
    }
    if (action == 'post.fetch') {
      details++;
      if (failDetail) throw ApiException.connection('Offline fixture');
      return {
        'data':
            detail ??
            venueRecords.firstWhere((p) => recordId(p) == body['post_id']),
      };
    }
    if (action == 'post.like' || action == 'post.dislike') {
      return pendingReaction?.future ?? Future.value({'success': true});
    }
    if (action == 'post.create' && pendingComment != null) {
      final result = await pendingComment!.future;
      if (result['fixture_error'] != null) {
        throw ApiException.connection(string(result['fixture_error']));
      }
      return result;
    }
    return super.call(
      action,
      body: body,
      get: get,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      receiveTimeout: receiveTimeout,
    );
  }
}

Future<Session> mountPlaces(
  WidgetTester tester,
  PlacesApi api, {
  String language = 'tr',
  Widget home = const PlacesScreen(),
  bool dark = false,
  double scale = 1,
}) async {
  final session = Session(api, persistPreferences: false)
    ..ready = true
    ..user = previewSelf
    ..locale = Locale(language)
    ..themeMode = dark ? ThemeMode.dark : ThemeMode.light;
  await tester.pumpWidget(
    CoolvibesApp(
      session: session,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: home,
        ),
      ),
    ),
  );
  await pumpUI(tester);
  return session;
}

Future<void> closePlaces(WidgetTester tester, Session session) async {
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
  session.dispose();
}

Finder action(String label) => find.byWidgetPredicate(
  (w) => w is AppButton && w.child is Text && (w.child as Text).data == label,
);

void main() {
  testWidgets(
    'list translates on locale change and opens the selected place by post_id',
    (tester) async {
      final api = PlacesApi();
      final session = await mountPlaces(tester, api);
      expect(find.text('Sahil Bahçesi'), findsOneWidget);
      expect(find.text('神戸の公園'), findsOneWidget);
      session.language(const Locale('en'));
      await pumpUI(tester);
      expect(find.text('Seaside Garden'), findsOneWidget);
      expect(find.text('A garden by the sea.'), findsOneWidget);
      await tapUI(tester, find.text('Seaside Garden'));
      await pumpUI(tester);
      expect(api.requests.last.action, 'post.fetch');
      expect(api.requests.last.body, {'post_id': 'place-42'});
      expect(find.byType(PlaceScreen), findsOneWidget);
      expect(find.text('Seaside Garden'), findsOneWidget);
      expect(
        find.text('A garden by the sea.', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('神戸の公園'), findsNothing);
      Navigator.of(tester.element(find.byType(PlaceScreen))).pop();
      await pumpUI(tester);
      expect(find.byType(PlaceRow), findsNWidgets(2));
      await closePlaces(tester, session);
    },
  );

  for (final language in ['tr', 'ar']) {
    testWidgets(
      'detail renders Lexical and contact rows at large text in $language',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final session = await mountPlaces(
          tester,
          PlacesApi(),
          language: language,
          dark: language == 'ar',
          scale: 2,
          home: PlaceScreen(place: translatedPlace),
        );
        final scroll = find
            .descendant(
              of: find.byType(PlaceScreen),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.byType(ArticleContent),
          220,
          scrollable: scroll,
        );
        await pumpUI(tester);
        expect(
          find.text(
            language == 'tr'
                ? 'Deniz kenarında bir buluşma noktası.'
                : 'حديقة على شاطئ البحر.',
            findRichText: true,
          ),
          findsOneWidget,
        );
        if (language == 'tr') {
          final rich = tester.widget<RichText>(
            find.text(
              'Deniz kenarında bir buluşma noktası.',
              findRichText: true,
            ),
          );
          final spans = <TextSpan>[];
          rich.text.visitChildren((span) {
            if (span is TextSpan && span.text != null) spans.add(span);
            return true;
          });
          expect(spans.first.style!.fontWeight, FontWeight.w700);
          expect(spans.last.recognizer, isNotNull);
        }
        await tester.scrollUntilVisible(
          find.text('Sahil Sokak 42'),
          220,
          scrollable: scroll,
        );
        expect(find.text('Sahil Sokak 42'), findsOneWidget);
        await closePlaces(tester, session);
      },
    );
  }

  testWidgets('empty list and missing contact information are usable', (
    tester,
  ) async {
    final api = PlacesApi()..venueRecords = [];
    final session = await mountPlaces(tester, api);
    expect(find.byType(PlaceRow), findsNothing);
    expect(find.byType(ScreenStatus), findsWidgets);
    api.venueRecords = [japanesePlace];
    await tester.pumpWidget(
      CoolvibesApp(
        session: session,
        home: PlaceScreen(place: japanesePlace),
      ),
    );
    await pumpUI(tester);
    expect(find.text('日本語の案内', findRichText: true), findsOneWidget);
    expect(find.text('İletişim bilgisi bulunmuyor.'), findsOneWidget);
    await closePlaces(tester, session);
  });

  testWidgets(
    'offline and wrong-ID detail show retry instead of another place',
    (tester) async {
      final api = PlacesApi()..failDetail = true;
      final session = await mountPlaces(
        tester,
        api,
        home: PlaceScreen(place: translatedPlace),
      );
      expect(find.text('Offline fixture'), findsOneWidget);
      api.failDetail = false;
      api.detail = japanesePlace;
      tester
          .widgetList<ScreenStatus>(find.byType(ScreenStatus))
          .firstWhere((s) => s.retry != null)
          .retry!();
      await pumpUI(tester);
      expect(find.text('Mekân bilgileri yüklenemedi.'), findsOneWidget);
      expect(find.text('神戸の公園'), findsNothing);
      api.detail = null;
      tester
          .widgetList<ScreenStatus>(find.byType(ScreenStatus))
          .firstWhere((s) => s.retry != null)
          .retry!();
      await pumpUI(tester);
      expect(find.text('Sahil Bahçesi'), findsOneWidget);
      expect(api.details, 3);
      await closePlaces(tester, session);
    },
  );

  testWidgets(
    'place comments use the shared composer and reload only after acceptance',
    (tester) async {
      final api = PlacesApi()..pendingComment = Completer<Json>();
      final session = await mountPlaces(
        tester,
        api,
        home: PlaceScreen(place: translatedPlace),
      );
      await tapUI(tester, action('Yorum yap'));
      await pumpUI(tester);
      expect(
        tester.widget<ComposerScreen>(find.byType(ComposerScreen)).replyTo,
        'place-42',
      );
      await tester.enterText(find.byType(TextField).first, 'Güzel bir mekân.');
      await pumpUI(tester);
      await tapUI(tester, action('Gönder'));
      await pumpUI(tester);
      final request = api.requests.singleWhere(
        (r) => r.action == 'post.create',
      );
      expect(request.body['parentPostId'], 'place-42');
      expect(api.details, 1);
      expect(find.byType(ComposerScreen), findsOneWidget);
      api.pendingComment!.complete({'fixture_error': 'Comment offline'});
      await pumpUI(tester);
      expect(find.text('Comment offline'), findsOneWidget);
      expect(find.text('Güzel bir mekân.'), findsOneWidget);
      expect(api.details, 1);
      api.pendingComment = Completer<Json>();
      await tapUI(tester, action('Gönder'));
      await pumpUI(tester);
      api.detail = {
        ...translatedPlace,
        'children': [
          {...previewPost, 'content': lexical('Güzel bir mekân.')},
        ],
      };
      api.pendingComment!.complete({'success': true, 'data': previewPost});
      await pumpUI(tester);
      expect(find.byType(ComposerScreen), findsNothing);
      expect(api.details, 2);
      final scroll = find
          .descendant(
            of: find.byType(PlaceScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Güzel bir mekân.', findRichText: true),
        250,
        scrollable: scroll,
      );
      await closePlaces(tester, session);
    },
  );

  testWidgets(
    'reactions use registered post routes and prevent duplicate taps',
    (tester) async {
      final api = PlacesApi()..pendingReaction = Completer<Json>();
      final session = await mountPlaces(
        tester,
        api,
        home: PlaceScreen(place: translatedPlace),
      );
      final scroll = find
          .descendant(
            of: find.byType(PlaceScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(action('Beğen'), 250, scrollable: scroll);
      await Scrollable.ensureVisible(
        tester.element(action('Beğen')),
        alignment: .5,
      );
      await pumpUI(tester);
      await tapUI(tester, action('Beğen'));
      await pumpUI(tester);
      expect(tester.widget<AppButton>(action('Beğen')).onPressed, isNull);
      expect(tester.widget<AppButton>(action('Beğenme')).onPressed, isNull);
      expect(api.requests.singleWhere((r) => r.action == 'post.like').body, {
        'post_id': 'place-42',
      });
      api.pendingReaction!.complete({'success': true});
      await pumpUI(tester);
      expect(api.details, 2);
      await closePlaces(tester, session);
    },
  );

  testWidgets(
    'malformed Lexical children and uneven tables do not crash detail',
    (tester) async {
      final cell = {
        'type': 'tablecell',
        'children': [object(lexical('Cell')['root'])['children'][0]],
      };
      final api = PlacesApi()
        ..detail = {
          ...translatedPlace,
          'content': {
            'tr': {
              'root': {
                'type': 'root',
                'children': [
                  {'type': 'paragraph', 'children': 'invalid'},
                  {
                    'type': 'table',
                    'children': [
                      {
                        'type': 'tablerow',
                        'children': [cell, cell],
                      },
                      {
                        'type': 'tablerow',
                        'children': [cell],
                      },
                    ],
                  },
                ],
              },
            },
          },
        };
      final session = await mountPlaces(
        tester,
        api,
        home: PlaceScreen(place: translatedPlace),
      );
      expect(find.text('Cell', findRichText: true), findsNWidgets(3));
      await closePlaces(tester, session);
    },
  );
}
