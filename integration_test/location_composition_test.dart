import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/screens/location_picker.dart';
import 'package:coolvibes/screens/chat.dart';
import 'package:coolvibes/components/attachment_controls.dart';
import 'package:coolvibes/components/location_attachment.dart';
import 'package:coolvibes/core/attachments.dart';
import 'package:coolvibes/screens/feed.dart';
import 'package:coolvibes/screens/discover.dart';
import 'package:coolvibes/screens/composer.dart';
import 'package:coolvibes/components/game_map.dart';
import 'package:coolvibes/components/message_field.dart';
import 'package:coolvibes/components/record_list.dart';
import 'package:coolvibes/components/app_pressable.dart';
import 'package:coolvibes/components/app_button.dart';
import 'package:coolvibes/components/navigation.dart';
import '../test/support/flow_api.dart';

Finder action(String label) =>
    find.byWidgetPredicate((w) => w is AppPressable && w.label == label);
Finder get editor => find.descendant(
  of: find.byType(MessageField),
  matching: find.byType(TextField),
);
Future<void> frames(WidgetTester tester, [int count = 12]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> capture(WidgetTester tester, String name) async {
  await frames(tester, 3);
  await IntegrationTestWidgetsFlutterBinding.instance.takeScreenshot(name);
}

Session makeSession(FlowApi api) => Session(api, persistPreferences: false)
  ..ready = true
  ..user = previewSelf
  ..system = previewSystem;
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native location map loads, queued recenter reaches JS and returns the moved point',
    (tester) async {
      final api = FlowApi(), session = makeSession(FlowApi());
      final active = makeSession(api);
      Json? result;
      await tester.pumpWidget(
        CoolvibesApp(
          session: active,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: AppButton.text(
                  onPressed: () async {
                    result = await sheet<Json>(
                      context,
                      const LocationPickerScreen(
                        initial: {'latitude': 41.0082, 'longitude': 28.9784},
                      ),
                    );
                  },
                  child: const Text('Konum seç'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Konum seç'));
      await frames(tester);
      final map = tester.widget<GameMap>(find.byType(GameMap)).controller!;
      // Invoke before ready as well: this command used to be silently dropped.
      await map.flyTo(40.99, 29.04, zoom: 14);
      for (var i = 0; i < 250 && !map.isReady; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        map.isReady,
        isTrue,
        reason: 'The actual WKWebView/MapLibre must load',
      );
      await frames(tester, 20);
      expect(find.text('40.99000, 29.04000'), findsOneWidget);
      await capture(tester, 'ios-location-picker-map');
      await tester.tap(find.text('Seçilen konumu gönder'));
      await frames(tester);
      expect(result?['latitude'], closeTo(40.99, .00001));
      expect(result?['longitude'], closeTo(29.04, .00001));
      await tester.pumpWidget(const SizedBox());
      active.dispose();
      session.dispose();
    },
  );
  testWidgets(
    'native location search switches map to venues and preserves selected address',
    (tester) async {
      final session = makeSession(FlowApi());
      Json? result;
      await tester.pumpWidget(
        CoolvibesApp(
          session: session,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: AppButton.text(
                  onPressed: () async {
                    result = await sheet<Json>(
                      context,
                      const LocationPickerScreen(
                        initial: {'latitude': 41.0082, 'longitude': 28.9784},
                      ),
                    );
                  },
                  child: const Text('Konum seç'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Konum seç'));
      await frames(tester);
      await tester.enterText(find.byType(EditableText).first, 'Moda');
      await frames(tester);
      expect(find.byType(GameMap), findsNothing);
      await capture(tester, 'ios-location-picker-search');
      await tester.tap(find.text('Moda Sahili'));
      await frames(tester);
      expect(result?['address'], 'Kadıköy, İstanbul');
      expect(result?['latitude'], 40.98);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  testWidgets(
    'native inline comment preserves rejected content and retries under the parent post',
    (tester) async {
      final api = FlowApi()..reject = true;
      final session = makeSession(api);
      await tester.pumpWidget(
        CoolvibesApp(
          session: session,
          home: PostDetailScreen(post: previewPost),
        ),
      );
      await frames(tester);
      await tester.enterText(editor, 'iOS yorum testi');
      await tester.pump();
      await tester.tap(action('Gönder'));
      await frames(tester);
      expect(
        tester.widget<TextField>(editor).controller!.text,
        'iOS yorum testi',
      );
      expect(find.text('Gönderilemedi'), findsOneWidget);
      api.reject = false;
      await tester.tap(action('Gönder'));
      await frames(tester);
      expect(
        api.calls
            .where((c) => c['action'] == 'post.create')
            .last['body']['parentPostId'],
        previewPost['public_id'],
      );
      expect(tester.widget<TextField>(editor).controller!.text, isEmpty);
      await capture(tester, 'ios-inline-comment');
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  testWidgets(
    'native check-in tag radar submits through shared input and returns to the list',
    (tester) async {
      final api = FlowApi(), session = makeSession(FlowApi());
      final active = makeSession(api);
      await tester.pumpWidget(
        CoolvibesApp(session: active, home: const CheckInsScreen()),
      );
      await frames(tester);
      final create = find.byWidgetPredicate(
        (w) => w is AppIconButton && w.tooltip == 'Check-in yap',
      );
      await tester.tap(create);
      await frames(tester);
      expect(find.byType(ComposerScreen), findsOneWidget);
      await tester.tap(action('Kahve'));
      await frames(tester, 4);
      await capture(tester, 'ios-checkin-tag-composer');
      await tester.enterText(editor, 'Kadıköy kahve molası');
      await tester.pump();
      await tester.tap(action('Gönder'));
      await frames(tester, 20);
      expect(find.byType(ComposerScreen), findsNothing);
      expect(find.byType(RecordList), findsOneWidget);
      final body =
          api.calls.where((c) => c['action'] == 'user.check_in').single['body']
              as Json;
      expect(body['tags'], ['coffee']);
      expect(body['latitude'], 41.0082);
      await capture(tester, 'ios-checkin-list');
      await tester.pumpWidget(const SizedBox());
      active.dispose();
      session.dispose();
    },
  );
  testWidgets(
    'native selected venue returns to the real chat draft and sends the same coordinates',
    (tester) async {
      final api = FlowApi(), session = makeSession(FlowApi());
      final active = makeSession(api);
      await tester.pumpWidget(
        CoolvibesApp(
          session: active,
          home: ChatScreen(chat: previewChat),
        ),
      );
      await frames(tester);
      final dynamic state = tester.state(find.byType(ChatScreen));
      final attachments = state.attachments as AttachmentController;
      final chosen = pickLocation(
        tester.element(find.byType(ChatScreen)),
        attachments,
      );
      await frames(tester);
      await tester.tap(find.text('Moda Sahili'));
      await frames(tester);
      await chosen;
      expect(attachments.location?['address'], 'Kadıköy, İstanbul');
      expect(find.byType(LocationAttachment), findsOneWidget);
      await capture(tester, 'ios-chat-location-draft');
      await tester.tap(action('Gönder'));
      await frames(tester, 20);
      final body =
          api.calls
                  .where((c) => c['action'] == 'chat.send_message')
                  .single['body']
              as Json;
      expect(body['content'], 'https://maps.google.com/?q=40.98,29.02');
      expect(body['location[lat]'], 40.98);
      expect(body['location[lng]'], 29.02);
      expect(body['location[address]'], 'Kadıköy, İstanbul');
      expect(attachments.location, isNull);
      await tester.pumpWidget(const SizedBox());
      active.dispose();
      session.dispose();
    },
  );
}
