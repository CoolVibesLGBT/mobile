import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/core/appearance.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/components/location_attachment.dart';
import 'package:coolvibes/components/game_map.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/vendor/liquid_glass_widgets/liquid_glass_widgets.dart'
    as liquid;
import '../test/emoji_panel_expand_test.dart' as expansion;
import '../test/chat_list_presentation_test.dart' as list;
import '../test/support/ui_driver.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await liquid.LiquidGlassWidgets.initialize(enablePerformanceMonitor: false);
    await AppearanceCatalog.load();
  });
  expansion.main();
  list.main();
  testWidgets(
    'map bubble releases its platform view after its real map frame arrives',
    (tester) async {
      final session =
          Session(PreviewApi(PreviewState.empty), persistPreferences: false)
            ..ready = true
            ..user = previewSelf;
      var opened = 0;
      await tester.pumpWidget(
        CoolvibesApp(
          session: session,
          home: Scaffold(
            body: Center(
              child: LocationAttachment(
                location: const {'latitude': 41.0082, 'longitude': 28.9784},
                onPressed: () => opened++,
              ),
            ),
          ),
        ),
      );
      await pumpUI(tester);
      final map = find.byType(GameMap);
      expect(tester.widget<GameMap>(map).snapshotOnly, isTrue);
      final raster = find.descendant(of: map, matching: find.byType(RawImage));
      for (var i = 0; i < 25 && raster.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 1)),
        );
        await tester.pump();
      }
      if (raster.evaluate().isEmpty) {
        final dynamic state = tester.state(map);
        debugPrint(
          'MAP_DIAGNOSTIC error=${state.error} web=${state.web != null}',
        );
        final WebViewController? web = state.web;
        if (web != null) {
          final status = await web.runJavaScriptReturningResult(
            "JSON.stringify({booted:window.__gmBooted,sdk:typeof maplibregl,canvas:!!document.querySelector('canvas'),width:document.querySelector('canvas')?.width,height:document.querySelector('canvas')?.height})",
          );
          debugPrint('MAP_DIAGNOSTIC $status');
        }
      }
      expect(
        raster,
        findsOneWidget,
        reason: 'The canvas must reach Flutter through the native JS channel.',
      );
      expect(tester.widget<RawImage>(raster).image!.width, greaterThan(200));
      expect(
        find.byType(WebViewWidget),
        findsNothing,
        reason:
            'No platform view may escape the bubble clip or cover the header, input or menu.',
      );
      await tester.tap(find.byType(LocationAttachment));
      await tester.pump();
      expect(opened, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}
