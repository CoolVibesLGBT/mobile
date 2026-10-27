import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/screens/chat.dart';
import 'package:coolvibes/screens/shell.dart';
import 'package:coolvibes/screens/discover.dart';
import 'package:coolvibes/components/game_map.dart';
import 'package:coolvibes/components/app_tab_bar.dart';

/// Drives production screens over preview fixtures and holds each state on
/// screen so the simulator can be captured (`xcrun simctl io booted
/// screenshot`). STEP selects the interaction; nothing is written anywhere.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('visual step', (tester) async {
    final semantics = tester.ensureSemantics();
    const step = String.fromEnvironment('STEP', defaultValue: 'emoji');
    final session = Session(
      PreviewApi(PreviewState.populated),
      persistPreferences: false,
    )..ready = true;
    final mapLens = step == 'map-lens';
    await tester.pumpWidget(
      CoolvibesApp(
        session: session,
        home: mapLens
            ? const Shell(initialTab: 1)
            : ChatScreen(chat: previewChat),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));
    if (mapLens) {
      // Nearby → map: the tab bar floats over the WebView map; then the
      // selected tab's lens is held pressed (it grows past the bar).
      final dynamic nearby = tester.state(find.byType(NearbyScreen));
      // ignore: invalid_use_of_protected_member
      nearby.setState(() => nearby.view = 'map');
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(GameMap), findsWidgets);
      if (AppTabBar.native) {
        // UITabBar: synthetic Flutter pointers never reach it; the lens is
        // driven from the simulator itself.
        debugPrint('VISUAL_READY');
        for (var i = 0; i < 120; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        semantics.dispose();
        return;
      }
      // The selected (second) tab of the bar.
      final bar = tester.getRect(find.byType(AppTabBar));
      final tab = Offset(bar.left + bar.width * 3 / 10, bar.center.dy);
      final gesture = await tester.startGesture(tab);
      await gesture.moveBy(const Offset(6, 0));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      debugPrint('VISUAL_READY');
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await gesture.up();
      semantics.dispose();
      return;
    }
    Future<void> hold() async {
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    switch (step) {
      case 'emoji':
        await tester.tap(find.bySemanticsLabel(RegExp('Emoji')).first);
      case 'menu':
        await tester.longPress(
          find.textContaining('Birazdan', findRichText: true).first,
        );
      case 'attach':
        await tester.tap(
          find.bySemanticsLabel(RegExp('Attachments|Ekler')).first,
        );
    }
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
    // Marker for the capture script.
    debugPrint('VISUAL_READY');
    await hold();
    semantics.dispose();
  });
}
