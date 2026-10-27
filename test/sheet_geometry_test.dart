import 'package:coolvibes/app.dart';
import 'package:coolvibes/components/components.dart';
import 'package:coolvibes/components/message_field.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/screens/composer.dart';
import 'package:coolvibes/screens/chat.dart';
import 'package:coolvibes/vendor/liquid_glass_widgets/liquid_glass_widgets.dart'
    as liquid;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/ui_driver.dart';

void main() {
  for (final top in [0.0, 24.0, 62.0]) {
    testWidgets('shared sheets use safe top + 10 with $top inset', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = FakeViewPadding(top: top, bottom: 34);
      tester.view.viewPadding = FakeViewPadding(top: top, bottom: 34);
      addTearDown(tester.view.reset);
      final session =
          Session(PreviewApi(PreviewState.populated), persistPreferences: false)
            ..ready = true
            ..user = previewSelf;
      for (final page in [const ComposerScreen(), const ForwardScreen()]) {
        await tester.pumpWidget(
          CoolvibesApp(
            session: session,
            home: Builder(
              builder: (context) => AppScaffold(
                body: TextButton(
                  onPressed: () => sheet(context, page),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await pumpUI(tester);
        final surface = tester.getRect(
          find.byKey(const Key('glass_modal_sheet_fill')),
        );
        final header = tester.getRect(find.byType(AppHeader).last);
        expect(surface.top, closeTo(top + 10, 1));
        expect(header.top, closeTo(surface.top, 1));
        expect(header.height, closeTo(60, 1));
        expect(tester.getRect(find.byWidget(page)).bottom, closeTo(874, 1));
        if (page is ComposerScreen) {
          final field = tester.getRect(find.byType(MessageField).first);
          expect(field.top - header.bottom, closeTo(16, 1));
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          tester.view.padding = FakeViewPadding(top: top);
          await pumpUI(tester);
          expect(
            tester.getRect(find.byKey(const ValueKey('article.send'))).bottom,
            lessThanOrEqualTo(574),
          );
          expect(
            tester.getRect(find.byKey(const Key('glass_modal_sheet_fill'))).top,
            closeTo(top + 10, 1),
          );
          tester.view.resetViewInsets();
          tester.view.padding = FakeViewPadding(top: top, bottom: 34);
        }
        if (top == 62 && page is ForwardScreen) {
          tester.view.physicalSize = const Size(874, 402);
          tester.view.padding = const FakeViewPadding(bottom: 21);
          tester.view.viewPadding = const FakeViewPadding(bottom: 21);
          await pumpUI(tester);
          expect(
            tester.getRect(find.byKey(const Key('glass_modal_sheet_fill'))).top,
            closeTo(0, 1),
          );
        }
        expect(tester.takeException(), isNull);
        final context = tester.element(
          find.byType(liquid.GlassModalSheetScaffold),
        );
        Navigator.of(context).pop();
        await pumpUI(tester);
        await tester.pumpWidget(const SizedBox());
      }
      session.dispose();
    });
  }
}
