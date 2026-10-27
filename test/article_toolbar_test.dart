import 'package:coolvibes/app.dart';
import 'package:coolvibes/components/article_editor.dart';
import 'package:coolvibes/components/app_tab_bar.dart';
import 'package:coolvibes/components/components.dart';
import 'package:coolvibes/components/glass_surface.dart';
import 'package:coolvibes/core/article.dart';
import 'package:coolvibes/core/attachments.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/design/app_design.dart';
import 'package:coolvibes/screens/shell.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/ui_driver.dart';

void main() {
  testWidgets('Telegram vectors render at original point sizes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Wrap(
            children: [
              for (final name in AppSymbol.assets.keys.where(
                (name) => name.startsWith('article.'),
              ))
                AppSymbol.native(name),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final name in AppSymbol.assets.keys.where(
      (name) => name.startsWith('article.'),
    )) {
      expect(
        tester.getSize(
          find.byWidgetPredicate((w) => w is AppSymbol && w.name == name),
        ),
        Size.square(AppSymbol.assets[name]!.$2),
      );
    }
    expect(tester.takeException(), isNull);
  });
  for (final dark in [false, true]) {
    testWidgets('article chrome floats without an opaque footer, dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(bottom: 102);
      tester.view.viewPadding = const FakeViewPadding(bottom: 102);
      addTearDown(tester.view.reset);
      final session =
          Session(PreviewApi(PreviewState.populated), persistPreferences: false)
            ..ready = true
            ..user = previewSelf
            ..themeMode = dark ? ThemeMode.dark : ThemeMode.light;
      final controller = ArticleController(),
          attachments = AttachmentController();
      final sending = ValueNotifier(false);
      var sendCount = 0;
      await tester.pumpWidget(
        CoolvibesApp(session: session, home: const Shell()),
      );
      await pumpUI(tester);
      final nativeTabs = find.byWidgetPredicate(
        (w) => w is UiKitView && w.viewType == 'coolvibes/tabbar',
      );
      final nativeTab = AppTabBar.native
          ? tester.widget<UiKitView>(nativeTabs)
          : null;
      sheet(
        tester.element(find.byType(Shell)),
        ValueListenableBuilder<bool>(
          valueListenable: sending,
          builder: (context, busy, _) => ArticleEditor(
            controller: controller,
            attachments: attachments,
            sending: busy,
            onSend: () => sendCount++,
          ),
        ),
      );
      await pumpUI(tester);
      if (nativeTab != null) {
        expect(
          nativeTabs,
          findsNothing,
          reason:
              'The underlying native tab bar must not paint through the sheet',
        );
      }
      final send = find.byKey(const ValueKey('article.send'));
      expect(
        tester.getRect(send).right,
        closeTo(390 - AppDesign.articleRestingSideInset, .1),
      );
      expect(
        tester.widget<AppIconButton>(send).backgroundColor,
        AppDesign.articleDisabledSend,
      );
      expect(tester.widget<AppIconButton>(send).onPressed, isNull);
      final scaffold = tester.widget<AppScaffold>(
        find.descendant(
          of: find.byType(ArticleEditor),
          matching: find.byType(AppScaffold),
        ),
      );
      expect(scaffold.bottomNavigationBar, isNull);
      expect(scaffold.body, isNot(isA<ColoredBox>()));
      final toolbar = find.byWidgetPredicate(
        (w) => w is GlassSurface && w.hostsScrolling,
      );
      expect(
        tester.widget<GlassSurface>(toolbar).role,
        GlassSurfaceRole.control,
      );
      expect(tester.getSize(toolbar).height, 44);
      final boundaryFinder = find
          .ancestor(
            of: find.byType(ArticleEditor),
            matching: find.byType(RepaintBoundary),
          )
          .last;
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        boundaryFinder,
      );
      final origin = boundary.localToGlobal(Offset.zero);
      Future<void> expectSendFill({required bool active}) async {
        final rect = tester.getRect(send).shift(-origin);
        final samples = await tester.runAsync(() async {
          final frame = await boundary.toImage(pixelRatio: 3);
          final bytes = (await frame.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          List<int> at(double x, double y) {
            final offset =
                ((y * 3).round() * frame.width + (x * 3).round()) * 4;
            return [for (var c = 0; c < 3; c++) bytes.getUint8(offset + c)];
          }

          final result = [
            at(rect.left + 4, rect.center.dy),
            at(rect.right + 8, rect.center.dy),
          ];
          frame.dispose();
          return result;
        });
        final fill = samples![0], outside = samples[1];
        expect(
          [
            for (var c = 0; c < 3; c++) (fill[c] - outside[c]).abs(),
          ].reduce((a, b) => a + b),
          greaterThan(35),
          reason:
              'Send surface must be visible: fill=$fill, outside=$outside, active=$active, sending=${sending.value}',
        );
      }

      await expectSendFill(active: false);
      await tester.tap(send);
      expect(sendCount, 0);
      controller.insert('Gönderi');
      await pumpUI(tester);
      await expectSendFill(active: true);
      await tester.tap(send);
      expect(sendCount, 1);
      sending.value = true;
      await pumpUI(tester);
      await expectSendFill(active: true);
      await tester.tap(send);
      expect(sendCount, 1);
      sending.value = false;
      controller.input.clear();
      await pumpUI(tester);
      final top = tester.getRect(toolbar).top - origin.dy;
      final samples = await tester.runAsync(() async {
        final frame = await boundary.toImage(pixelRatio: 3);
        final bytes = await frame.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        final values = <List<int>>[];
        for (final x in [6, 24, frame.width - 27, frame.width - 9]) {
          for (final y in [((top - 3) * 3).round(), ((top + 3) * 3).round()]) {
            final offset = (y * frame.width + x) * 4;
            values.add([
              for (var c = 0; c < 3; c++) bytes!.getUint8(offset + c),
            ]);
          }
        }
        frame.dispose();
        return values;
      });
      for (var i = 0; i < samples!.length; i += 2) {
        for (var c = 0; c < 3; c++) {
          expect(
            (samples[i][c] - samples[i + 1][c]).abs(),
            lessThanOrEqualTo(3),
            reason: 'outside glass: ${samples[i]} → ${samples[i + 1]}',
          );
        }
      }
      final list = find.byWidgetPredicate(
        (w) => w is AppSymbol && w.name == 'article.list',
      );
      expect(tester.getSize(list), const Size(30, 30));
      final press = find.ancestor(
        of: toolbar,
        matching: find.byWidgetPredicate(
          (w) =>
              w is AppPressable &&
              w.observeOnly &&
              w.style == AppPressStyle.glass,
        ),
      );
      expect(press, findsOneWidget);
      final oldSize = tester.getSize(toolbar);
      final gesture = await tester.startGesture(tester.getCenter(list));
      await tester.pump(const Duration(milliseconds: 140));
      expect(tester.getRect(toolbar).width, greaterThan(oldSize.width));
      await gesture.cancel();
      await pumpUI(tester);
      expect(tester.getRect(toolbar).width, closeTo(oldSize.width, 1));
      tester.view.viewInsets = const FakeViewPadding(bottom: 900);
      tester.view.padding = FakeViewPadding.zero;
      await pumpUI(tester);
      expect(
        tester.getRect(send).right,
        closeTo(390 - AppDesign.articleSideInset, .1),
      );
      controller.insert('Metin');
      controller.input.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 5,
      );
      await pumpUI(tester);
      await tapUI(
        tester,
        find.byWidgetPredicate(
          (w) => w is AppIconButton && w.tooltip == 'Kalın',
        ),
      );
      await pumpUI(tester);
      final bold = tester.widget<AppIconButton>(
        find.byWidgetPredicate(
          (w) => w is AppIconButton && w.tooltip == 'Kalın',
        ),
      );
      expect(bold.color, Colors.white);
      expect(controller.input.selectedMark.format & 1, 1);
      expect(tester.takeException(), isNull);
      tester.view.viewInsets = FakeViewPadding.zero;
      tester.view.padding = const FakeViewPadding(bottom: 102);
      await pumpUI(tester);
      Navigator.of(tester.element(find.byType(ArticleEditor))).pop();
      await pumpUI(tester);
      if (nativeTab != null) {
        expect(nativeTabs, findsOneWidget);
        expect(tester.widget<AppTabBar>(find.byType(AppTabBar)).selected, 0);
      }
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      attachments.dispose();
      sending.dispose();
      session.dispose();
    });
  }
}
