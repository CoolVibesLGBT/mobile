import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/screens/chat.dart';

void main() {
  testWidgets('pinned bar shows one rule segment per pin and steps back', (
    tester,
  ) async {
    final session =
        Session(PreviewApi(PreviewState.populated), persistPreferences: false)
          ..ready = true
          ..user = previewSelf;
    await tester.pumpWidget(
      CoolvibesApp(session: session, home: ChatScreen(chat: previewChat)),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final bar = find.byType(ChatPinnedBar);
    expect(bar, findsOneWidget);
    final segments = find.descendant(
      of: bar,
      matching: find.byWidgetPredicate(
        (w) => w is DecoratedBox && w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).borderRadius ==
                BorderRadius.circular(1),
      ),
    );
    expect(segments, findsNWidgets(2));
    for (final element in segments.evaluate()) {
      final size = (element.renderObject! as RenderBox).size;
      expect(size.width, 2);
      expect(size.height, greaterThan(10));
    }
    expect(find.text('Sabit Mesaj'), findsOneWidget);
    await tester.tap(bar);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Sabit Mesaj #1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
}
