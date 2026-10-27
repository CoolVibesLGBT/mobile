import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/components/app_button.dart';
import 'package:coolvibes/components/app_segments.dart';
import 'package:coolvibes/components/app_tab_bar.dart';
import 'package:coolvibes/components/glass_surface.dart';
import 'package:coolvibes/components/message_field.dart';
import 'package:coolvibes/components/navigation.dart';
import 'package:coolvibes/core/appearance.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/screens/chat.dart';
import 'package:coolvibes/screens/shell.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:coolvibes/vendor/liquid_glass_widgets/liquid_glass_widgets.dart'
    as liquid;
import '../test/support/contract_api.dart';
import '../test/support/ui_driver.dart';
import '../test/support/glass_assertions.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await liquid.LiquidGlassWidgets.initialize(enablePerformanceMonitor: false);
    await AppearanceCatalog.load();
  });
  late ContractApi api;
  late Session session;
  setUp(() {
    api = ContractApi()..failSend = false;
    session = Session(api, persistPreferences: false)
      ..ready = true
      ..user = previewSelf;
  });
  tearDown(() => session.dispose());
  testWidgets('chat optical input, send and modal work on device', (
    tester,
  ) async {
    await tester.pumpWidget(
      CoolvibesApp(
        session: session,
        home: ChatScreen(chat: {...previewChat, 'id': conversation}),
      ),
    );
    await pumpUI(tester);
    expectChatMaterials(tester);
    await expectInputGlassPress(tester);
    final field = find.descendant(
      of: find.byType(MessageField),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, 'Gönderim testi');
    await pumpUI(tester);
    final send = find.byWidgetPredicate(
      (w) => w is AppIconButton && w.prominent && w.embedded,
    );
    expect(
      tester
          .getRect(find.byType(MessageField))
          .contains(tester.getCenter(send)),
      isTrue,
    );
    final drag = await tester.startGesture(tester.getCenter(send));
    await drag.moveBy(const Offset(-150, -100));
    await drag.up();
    await pumpUI(tester);
    expect(api.calls.where((c) => c.action == 'chat.send_message'), isEmpty);
    await tester.tap(send);
    await pumpUI(tester);
    expect(api.calls.where((c) => c.action == 'chat.send_message').length, 1);
    expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    expectChatMaterials(tester);
    // A fully expanded modal retains its frosted backdrop on Impeller too.
    unawaited(sheet(tester.element(field), const ForwardScreen()));
    await pumpUI(tester);
    expect(find.byType(ForwardScreen), findsOneWidget);
    final fill = tester.widget<DecoratedBox>(
      find.byKey(const Key('glass_modal_sheet_fill')),
    );
    expect((fill.decoration as BoxDecoration).color!.a, 0);
    final modal = find.byType(liquid.GlassModalSheetScaffold);
    final modalSize = tester.getSize(modal);
    expect(
      find
          .descendant(of: modal, matching: find.byType(BackdropFilter))
          .evaluate()
          .any((element) {
            final size = tester.getSize(find.byWidget(element.widget));
            return size.width > modalSize.width * .9 &&
                size.height > modalSize.height * .7;
          }),
      isTrue,
    );
    Navigator.of(tester.element(find.byType(ForwardScreen))).pop();
    await pumpUI(tester);
    expectChatMaterials(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  testWidgets('nearby glass navigation works on device', (tester) async {
    await tester.pumpWidget(
      CoolvibesApp(session: session, home: const Shell(initialTab: 1)),
    );
    await pumpUI(tester);
    expect(PlatformBackdrop.active, isFalse);
    final selector = tester.getRect(find.byType(AppSegments<String>));
    await tester.tapAt(
      Offset(selector.right - selector.width / 6, selector.center.dy),
    );
    await pumpUI(tester);
    expect(find.byType(WebViewWidget), findsOneWidget);
    expectRoundMapControls(tester);
    expectMapTabBar(tester);
    final bar = tester.getRect(find.byType(AppTabBar));
    final nearby = Offset(bar.left + bar.width * 1.5 / 5, bar.center.dy);
    final home = Offset(bar.left + bar.width * .5 / 5, bar.center.dy);
    // Drag the actual lens away from the map, then return. The platform
    // backdrop changes during this animation; both navigation and glass must
    // survive the renderer transition without stale map ownership.
    await tester.dragFrom(nearby, home - nearby);
    await pumpUI(tester);
    expect(tester.widget<AppTabBar>(find.byType(AppTabBar)).selected, 0);
    expect(PlatformBackdrop.active, isFalse);
    await tester.tapAt(nearby);
    await pumpUI(tester);
    expect(tester.widget<AppTabBar>(find.byType(AppTabBar)).selected, 1);
    expectMapTabBar(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
