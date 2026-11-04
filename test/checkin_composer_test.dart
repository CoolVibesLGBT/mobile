import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:coolvibes/design/app_design.dart';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/components/chat_input.dart';
import 'package:coolvibes/components/components.dart';
import 'package:coolvibes/components/location_attachment.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/screens/composer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/flow_api.dart';
import 'support/ui_driver.dart';

Session sessionFor(FlowApi api) => Session(api, persistPreferences: false)
  ..ready = true
  ..user = previewSelf
  ..system = previewSystem;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Optional local layout review: do not redistribute Apple's font files.
    if (const bool.fromEnvironment('CHECKIN_SCREENSHOTS') && Platform.isMacOS) {
      for (final family in [AppDesign.fontFamily, AppDesign.displayFamily]) {
        final loader = FontLoader(family);
        for (final path in [
          '/System/Library/Fonts/SFNS.ttf',
          '/System/Library/Fonts/SFArabic.ttf',
        ]) {
          loader.addFont(
            File(
              path,
            ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          );
        }
        await loader.load();
      }
      final icons = FontLoader('CupertinoIcons')
        ..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        );
      await icons.load();
    }
  });
  testWidgets('tag-only check-in never submits invented coordinates', (
    tester,
  ) async {
    final api = FlowApi(), session = sessionFor(api);
    await tester.pumpWidget(
      CoolvibesApp(session: session, home: const ComposerScreen(checkIn: true)),
    );
    await pumpUI(tester);
    final tag = find.byKey(const ValueKey('checkin.tag.coffee'));
    await tester.ensureVisible(tag);
    await tester.pump();
    await tester.tap(tag);
    await tester.pump();
    tester.widget<ChatInput>(find.byType(ChatInput)).onSend();
    await pumpUI(tester);
    expect(api.calls.where((c) => c['action'] == 'user.check_in'), isEmpty);
    expect(session.uploads.jobs, isEmpty);
    expect(find.text('Check-in yapmak için bir yer seç.'), findsWidgets);
    expect(
      tester.widget<ChatInput>(find.byType(ChatInput)).attachments.location,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  testWidgets('activity search handles Turkish text and retains selections', (
    tester,
  ) async {
    final session = sessionFor(FlowApi());
    await tester.pumpWidget(
      CoolvibesApp(session: session, home: const ComposerScreen(checkIn: true)),
    );
    await pumpUI(tester);
    final search = find.byType(CupertinoSearchTextField);
    await tester.enterText(search, 'yuruyus');
    await pumpUI(tester);
    expect(find.byKey(const ValueKey('checkin.tag.coffee')), findsNothing);
    final walk = find.byKey(const ValueKey('checkin.tag.walk'));
    expect(walk, findsOneWidget);
    await tester.ensureVisible(walk);
    await tester.pump();
    await tester.tap(walk);
    await tester.pump();
    expect(tester.widget<AppRow>(walk).selected, isTrue);
    await tester.enterText(search, 'coffee');
    await pumpUI(tester);
    expect(find.byKey(const ValueKey('checkin.tag.coffee')), findsOneWidget);
    await tester.enterText(search, '');
    await pumpUI(tester);
    expect(tester.widget<AppRow>(walk).selected, isTrue);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  testWidgets('selected place does not duplicate its map in the input', (
    tester,
  ) async {
    final session = sessionFor(FlowApi());
    await tester.pumpWidget(
      CoolvibesApp(
        session: session,
        home: const ComposerScreen(
          checkIn: true,
          initialLocation: {
            'lat': 40.98,
            'lng': 29.02,
            'address': 'Moda, İstanbul',
          },
        ),
      ),
    );
    await pumpUI(tester);
    expect(find.text('Moda, İstanbul'), findsOneWidget);
    expect(find.byType(LocationAttachment), findsNothing);
    final input = tester.widget<ChatInput>(find.byType(ChatInput));
    expect(input.attachments.location!['latitude'], 40.98);
    expect(input.attachments.location!['longitude'], 29.02);
    expect(input.showLocationPreview, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  for (final rtl in [false, true]) {
    testWidgets('check-in fits 2x text and keyboard rtl=$rtl', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 44, bottom: 34);
      addTearDown(tester.view.reset);
      final session = sessionFor(FlowApi())..locale = Locale(rtl ? 'ar' : 'tr');
      final key = GlobalKey();
      await tester.pumpWidget(
        CoolvibesApp(
          session: session,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: RepaintBoundary(
                key: key,
                child: const ComposerScreen(
                  checkIn: true,
                  initialLocation: {
                    'latitude': 40.98,
                    'longitude': 29.02,
                    'address': 'Moda, İstanbul',
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await pumpUI(tester);
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byType(ChatInput)).bottom,
        lessThanOrEqualTo(544),
      );
      if (const bool.fromEnvironment('CHECKIN_SCREENSHOTS')) {
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          final file = File(
            'build/checkin-review/composer-${rtl ? 'rtl' : 'tr'}-2x.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    });
  }
}
