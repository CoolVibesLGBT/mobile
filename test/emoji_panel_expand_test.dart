import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/screens/chat.dart';
import 'package:coolvibes/screens/emoticons.dart';
import 'package:coolvibes/components/chat_input.dart';
import 'package:coolvibes/components/app_button.dart';
import 'package:coolvibes/components/app_header.dart';
import 'package:coolvibes/components/glass_surface.dart';
import 'package:coolvibes/design/app_design.dart';
import 'support/source_assets.dart';
import 'support/ui_driver.dart';

void main() {
  for (final close in ['arrow', 'keyboard', 'focus', 'interrupt', 'reduced']) {
    testWidgets('chat back works after emoji expansion closes with $close', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
      addTearDown(tester.view.reset);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: close == 'reduced');
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final session =
          Session(PreviewApi(PreviewState.populated), persistPreferences: false)
            ..ready = true
            ..user = previewSelf;
      await tester.pumpWidget(
        CoolvibesApp(
          session: session,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChatScreen(chat: previewChat),
                  ),
                ),
                child: const Text('Open chat'),
              ),
            ),
          ),
        ),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        session.dispose();
      });
      await tester.tap(find.text('Open chat'));
      await pumpUI(tester);
      await tester.tap(find.bySemanticsLabel(RegExp('Emoji')).first);
      await pumpUI(tester);
      final toggle = find.byKey(const ValueKey('chat.media.expand'));
      await tester.tap(toggle);
      if (close == 'interrupt') {
        await tester.pump(const Duration(milliseconds: 80));
      } else {
        await pumpUI(tester);
      }
      if (close == 'keyboard') {
        await tester.tap(find.bySemanticsLabel('Klavyeyi göster').first);
      } else if (close == 'focus' || close == 'interrupt') {
        tester
            .widget<ChatInput>(find.byType(ChatInput))
            .focusNode!
            .requestFocus();
      } else {
        await tester.tap(toggle);
      }
      await pumpUI(tester);
      final background = tester.widget<Transform>(
        find.byKey(const ValueKey('app.presentation.background')),
      );
      expect(background.transform.isIdentity(), isTrue);
      final back = find
          .descendant(
            of: find.byType(AppHeader),
            matching: find.byType(AppIconButton),
          )
          .first;
      expect(back.hitTestable(), findsOneWidget);
      await tester.tap(back);
      await pumpUI(tester);
      expect(find.byType(ChatScreen), findsNothing);
      expect(find.text('Open chat'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  for (final dark in [false, true]) {
    testWidgets(
      'media arrow keeps full-screen geometry, draft and chat depth in $dark',
      (tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3;
        tester.view.viewPadding = const FakeViewPadding(top: 177, bottom: 102);
        tester.view.padding = const FakeViewPadding(top: 177, bottom: 102);
        addTearDown(tester.view.reset);
        final session =
            Session(
                PreviewApi(PreviewState.populated),
                persistPreferences: false,
              )
              ..ready = true
              ..user = previewSelf
              ..themeMode = dark ? ThemeMode.dark : ThemeMode.light;
        await tester.pumpWidget(
          DefaultAssetBundle(
            bundle: JsonAssets(),
            child: CoolvibesApp(
              session: session,
              home: ChatScreen(chat: previewChat),
            ),
          ),
        );
        await pumpUI(tester);
        final chat = find.byType(ChatInput);
        final input = tester.widget<ChatInput>(chat).controller;
        await tester.tap(find.bySemanticsLabel(RegExp('Emoji')).first);
        await pumpUI(tester);
        final picker = find.byType(EmoticonPicker);
        final collapsed = tester.getSize(picker).height;
        final toggle = find.byKey(const ValueKey('chat.media.expand'));
        final arrow = find.byKey(const ValueKey('chat.media.expand.arrow'));
        final background = find.byKey(
          const ValueKey('app.presentation.background'),
        );
        expect(toggle, findsOneWidget);
        expect(
          tester.widget<Transform>(arrow).transform.storage[5],
          closeTo(-1, .01),
        );
        await tester.tap(toggle);
        await pumpUI(tester);
        expect(tester.widget<EmoticonPicker>(picker).expanded, isTrue);
        expect(tester.getSize(picker).height, greaterThan(collapsed + 250));
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('chat-composer-row'))).dy,
          closeTo(69, 1),
        );
        final matrix = tester.widget<Transform>(background).transform;
        expect(matrix.storage[0], closeTo((390 - 32) / 390, .001));
        expect(matrix.storage[12], closeTo(16, .1));
        expect(matrix.storage[13], closeTo(59, .1));
        expect(
          tester.widget<Transform>(arrow).transform.storage[5],
          closeTo(1, .01),
        );
        final panel = tester
            .widgetList<GlassSurface>(
              find.ancestor(of: picker, matching: find.byType(GlassSurface)),
            )
            .first;
        expect(
          panel.tint,
          dark ? AppDesign.inputMediaPanelDark : AppDesign.inputMediaPanelLight,
        );
        expect(panel.useOwnLayer, isTrue);
        expect(panel.topOnly, isTrue);
        await tester.tap(
          find.descendant(of: picker, matching: find.text('😀')).first,
        );
        await pumpUI(tester);
        expect(input.text, '😀');
        expect(
          toggle,
          findsOneWidget,
          reason: 'Draft content must not remove the collapse action.',
        );
        await tester.tap(toggle);
        await pumpUI(tester);
        expect(tester.widget<EmoticonPicker>(picker).expanded, isFalse);
        expect(tester.getSize(picker).height, closeTo(collapsed, 1));
        expect(
          tester.widget<Transform>(background).transform.storage[0],
          closeTo(1, .001),
        );
        await tester.tap(toggle);
        await pumpUI(tester);
        await tester.tap(find.byKey(const ValueKey('emoji.search.activate')));
        tester.view.viewInsets = const FakeViewPadding(bottom: 900);
        tester.view.padding = const FakeViewPadding(top: 177);
        await pumpUI(tester);
        expect(tester.getRect(picker).bottom, closeTo(544, 1));
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('chat-composer-row'))).dy,
          closeTo(69, 1),
        );
        tester.view.viewInsets = FakeViewPadding.zero;
        tester.view.padding = const FakeViewPadding(top: 177, bottom: 102);
        await tester.tap(find.byKey(const ValueKey('emoji.search.cancel')));
        await pumpUI(tester);
        tester.widget<ChatInput>(chat).focusNode!.requestFocus();
        await pumpUI(tester);
        expect(picker, findsNothing);
        expect(input.text, '😀');
        expect(
          tester.widget<Transform>(background).transform.storage[0],
          closeTo(1, .001),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        session.dispose();
      },
    );
  }
  testWidgets('dragging the emoji grid up expands the panel; pulling down at '
      'the top collapses it', (tester) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final session =
        Session(PreviewApi(PreviewState.populated), persistPreferences: false)
          ..ready = true
          ..user = previewSelf;
    await tester.pumpWidget(
      CoolvibesApp(
        session: session,
        home: ChatScreen(chat: previewChat),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.bySemanticsLabel(RegExp('Emoji')).first);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final picker = find.byType(EmoticonPicker);
    expect(picker, findsOneWidget);
    final collapsed = tester.getSize(picker).height;
    await tester.drag(
      find.descendant(of: picker, matching: find.byType(CustomScrollView)),
      const Offset(0, -120),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final expanded = tester.getSize(picker).height;
    expect(expanded, greaterThan(collapsed + 150));
    await tester.drag(
      find.descendant(of: picker, matching: find.byType(CustomScrollView)),
      const Offset(0, 600),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.getSize(picker).height, lessThan(expanded - 150));
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
}
