import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/vendor/liquid_glass_widgets/liquid_glass_widgets.dart'
    as liquid;
import 'package:coolvibes/components/app_button.dart';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/core/geo.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/core/place_search.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/screens/feed.dart';
import 'package:coolvibes/screens/chat.dart';
import 'package:coolvibes/core/attachments.dart';
import 'package:coolvibes/components/location_attachment.dart';
import 'package:coolvibes/screens/composer.dart';
import 'package:coolvibes/components/navigation.dart';
import 'package:coolvibes/screens/location_picker.dart';
import 'package:coolvibes/components/game_map.dart';
import 'package:coolvibes/components/app_pressable.dart';
import 'package:coolvibes/components/message_field.dart';
import 'support/flow_api.dart';

/// A control by its accessible label: an AppPressable or a glass button.
Finder action(String label) => find.byWidgetPredicate(
  (w) =>
      (w is AppPressable && w.label == label) ||
      (w is liquid.GlassButton && w.label == label),
);
Session sessionFor(FlowApi api) => Session(api, persistPreferences: false)
  ..ready = true
  ..user = previewSelf
  ..system = previewSystem;
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder get editor => find.descendant(
  of: find.byType(MessageField),
  matching: find.byType(TextField),
);

class PendingPlaces extends PlaceSearch {
  final pending = <String, Completer<PlacePage>>{};
  @override
  Future<PlacePage> fetch({
    required double latitude,
    required double longitude,
    String query = '',
    String language = 'en',
    String? page,
    CancelToken? cancelToken,
  }) => (pending[query] = Completer<PlacePage>()).future;
}

void main() {
  test(
    'location-only messages use the source fallback URL and hide only its matching caption',
    () {
      final point = {'latitude': 40.98, 'longitude': 29.02};
      expect(locationMapUrl(point), 'https://maps.google.com/?q=40.98,29.02');
      expect(
        locationMapUrl({'lat': 0, 'lng': 0}),
        'https://maps.google.com/?q=0,0',
      );
      expect(locationMessageText(locationMapUrl(point), point), isEmpty);
      expect(locationMessageText('Açıklama', point), 'Açıklama');
      expect(
        locationMessageText('https://maps.google.com/?q=41,29', point),
        isNotEmpty,
      );
    },
  );
  test(
    'Photon coordinates, bounds, city type and missing geometry are normalized',
    () {
      final place = PlaceSearch.photonPlace({
        'properties': {
          'name': 'İstanbul',
          'type': 'city',
          'osm_id': 1,
          'extent': [28, 42, 30, 40],
        },
        'geometry': {
          'coordinates': [29, 41],
        },
      }, 0)!;
      expect(place['latitude'], 41);
      expect(place['longitude'], 29);
      expect(place['delta'], closeTo(2.3, 1e-10));
      expect(place['kind'], 'region');
      expect(
        PlaceSearch.photonPlace({
          'properties': {'name': 'Bad'},
        }, 0),
        isNull,
      );
    },
  );
  testWidgets('stale place results never replace the newest query', (
    tester,
  ) async {
    final places = PendingPlaces();
    final api = FlowApi(places: places), active = sessionFor(api);
    await tester.pumpWidget(
      CoolvibesApp(
        session: active,
        home: const LocationPickerScreen(initial: {'lat': 41, 'lng': 29}),
      ),
    );
    await tester.pump();
    // Telegram: the glass search button opens a results layer whose input
    // sits at the bottom.
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is AppIconButton && w.tooltip == 'Yer ara',
      ),
    );
    await tester.pump();
    final search = find.byType(EditableText).last;
    await tester.enterText(search, 'Ankara');
    await settle(tester);
    await tester.enterText(search, 'İzmir');
    await settle(tester);
    places.pending['İzmir']!.complete(
      const PlacePage([
        {'id': '2', 'name': 'İzmir', 'latitude': 38.4, 'longitude': 27.1},
      ]),
    );
    await tester.pump();
    places.pending['Ankara']!.complete(
      const PlacePage([
        {'id': '1', 'name': 'Ankara', 'latitude': 39.9, 'longitude': 32.8},
      ]),
    );
    await tester.pump();
    expect(
      find
          .text('İzmir', findRichText: false)
          .evaluate()
          .where((e) => e.widget is Text)
          .length,
      1,
    );
    expect(find.text('Ankara'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    active.dispose();
  });
  testWidgets(
    'comment rejection preserves text and retry sends the correct parentPostId',
    (tester) async {
      final api = FlowApi()..reject = true;
      final active = sessionFor(api);
      await tester.pumpWidget(
        CoolvibesApp(
          session: active,
          home: PostDetailScreen(post: previewPost),
        ),
      );
      await settle(tester);
      expect(editor, findsOneWidget);
      await tester.enterText(editor, 'Yorum denemesi');
      await tester.pump();
      await tester.tap(action('Gönder'));
      await settle(tester);
      expect(
        tester.widget<TextField>(editor).controller!.text,
        'Yorum denemesi',
      );
      expect(find.text('Gönderilemedi'), findsOneWidget);
      expect(
        api.calls
            .where((c) => c['action'] == 'post.create')
            .single['body']['parentPostId'],
        previewPost['public_id'],
      );
      api.reject = false;
      await tester.tap(action('Gönder'));
      await settle(tester);
      expect(tester.widget<TextField>(editor).controller!.text, isEmpty);
      expect(find.text('Yorum denemesi'), findsOneWidget);
      expect(api.comments.length, 1);
      await tester.pumpWidget(const SizedBox());
      active.dispose();
    },
  );
  testWidgets(
    'check-in sends a selected tag with coordinates and waits for acknowledgement',
    (tester) async {
      final api = FlowApi(), session = sessionFor(api);
      await tester.pumpWidget(
        CoolvibesApp(
          session: session,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    sheet(context, const ComposerScreen(checkIn: true)),
                child: const Text('Aç'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Aç'));
      await settle(tester);
      await tester.tap(action('Kahve'));
      await tester.pump();
      expect(action('Gönder'), findsOneWidget);
      await tester.tap(action('Gönder'));
      await settle(tester);
      final body =
          api.calls.where((c) => c['action'] == 'user.check_in').single['body']
              as Json;
      expect(body['tags'], ['coffee']);
      expect(body['extras']['tags'], ['coffee']);
      expect(body['latitude'], 41.0082);
      expect(body['longitude'], 28.9784);
      expect(plainText(body['content']), 'Check-in');
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  testWidgets(
    'a location draft fits above the keyboard on a narrow chat screen',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final session = sessionFor(FlowApi());
      await tester.pumpWidget(
        CoolvibesApp(
          session: session,
          home: ChatScreen(chat: previewChat),
        ),
      );
      await settle(tester);
      final dynamic state = tester.state(find.byType(ChatScreen));
      final attachments = state.attachments as AttachmentController;
      attachments.location = {
        'latitude': 40.98,
        'longitude': 29.02,
        'address': 'Kadıköy, İstanbul',
      };
      attachments.changed();
      await settle(tester);
      expect(find.byType(LocationAttachment), findsOneWidget);
      expect(action('Gönder'), findsOneWidget);
      expect(tester.takeException(), isNull);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  testWidgets(
    'a full-height sheet lays its page out on screen: the picker search input stays visible',
    (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 62, bottom: 34);
      addTearDown(tester.view.reset);
      final session = sessionFor(FlowApi());
      await tester.pumpWidget(
        CoolvibesApp(
          session: session,
          home: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => sheet<Json>(
                  context,
                  const LocationPickerScreen(initial: {'lat': 41, 'lng': 29}),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      // The page ends at the screen edge, not under the submerged corners.
      final page = tester.getRect(find.byType(LocationPickerScreen));
      expect(page.bottom, lessThanOrEqualTo(874.5));
      // Dragging the map enters picking: the send button rests 14pt above
      // the home indicator, inside the screen.
      tester
          .widget<GameMap>(find.byType(GameMap))
          .onMoveStart!(true);
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final send = tester.getRect(action('Konumu Gönder').last);
      expect(send.bottom, closeTo(874 - 34 - 14, 1));
      expect(send.height, closeTo(52, 1));
      tester
          .widget<AppIconButton>(
            find.byWidgetPredicate(
              (w) => w is AppIconButton && w.tooltip == 'Geri',
            ),
          )
          .onPressed!();
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is AppIconButton && w.tooltip == 'Yer ara',
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final input = tester.getRect(find.byType(EditableText).last);
      expect(input.bottom, lessThanOrEqualTo(874 - 34));
      expect(input.top, greaterThan(0));
      expect(tester.takeException(), isNull);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}
