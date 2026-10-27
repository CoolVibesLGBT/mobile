import 'dart:convert';
import 'dart:ui' as ui;
import 'package:coolvibes/app.dart';
import 'package:coolvibes/components/app_lottie.dart';
import 'package:coolvibes/components/components.dart';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/design/app_design.dart';
import 'package:coolvibes/screens/emoticons.dart';
import 'package:coolvibes/vendor/liquid_glass_widgets/liquid_glass_widgets.dart'
    as liquid;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/ui_driver.dart';
import 'support/source_assets.dart';

class _SearchApi extends PreviewApi {
  _SearchApi() : super(PreviewState.empty);
  final queries = <String>[];
  @override
  Future<Json> call(
    String action, {
    Json body = const {},
    bool get = false,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    Duration? receiveTimeout,
  }) async {
    if (action == 'chat.media.gifs') {
      queries.add(string(body['query']));
      return {
        'data': {'documents': [], 'nextOffset': ''},
      };
    }
    return super.call(
      action,
      body: body,
      get: get,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      receiveTimeout: receiveTimeout,
    );
  }
}

void main() {
  testWidgets('original search icons remain visible with reduced motion', (
    tester,
  ) async {
    final manifest =
        jsonDecode(
              await rootBundle.loadString(
                'assets/animations/emoji_search/sources.json',
              ),
            )
            as Map;
    final names = (manifest['icons'] as Map).keys.cast<String>().toList();
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: JsonAssets(),
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Center(
              child: RepaintBoundary(
                key: boundaryKey,
                child: SizedBox(
                  width: names.length * 24,
                  height: 24,
                  child: Row(
                    children: [
                      for (final name in names)
                        AppLottie(
                          asset: 'assets/animations/emoji_search/$name.json',
                          size: 24,
                          color: Colors.black,
                          loop: false,
                          staticProgress: 1,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final ink = await tester.runAsync(() async {
      final frame = await boundary.toImage();
      final pixels = (await frame.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final counts = List.filled(names.length, 0);
      for (var y = 0; y < frame.height; y++) {
        for (var x = 0; x < frame.width; x++) {
          if (pixels.getUint8((y * frame.width + x) * 4 + 3) > 16) {
            counts[x ~/ 24]++;
          }
        }
      }
      frame.dispose();
      return counts;
    });
    for (var i = 0; i < names.length; i++) {
      expect(
        ink![i],
        greaterThan(10),
        reason: '${names[i]} must paint its original shape',
      );
    }
    expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final variant in [(false, 'tr'), (true, 'tr'), (false, 'ar')]) {
    final (dark, language) = variant;
    testWidgets(
      'media search keeps glass, original animations and filtering: $dark/$language',
      (tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        final api = _SearchApi();
        final session = Session(api, persistPreferences: false)
          ..ready = true
          ..user = previewSelf
          ..locale = Locale(language)
          ..themeMode = dark ? ThemeMode.dark : ThemeMode.light;
        await tester.pumpWidget(
          DefaultAssetBundle(
            bundle: JsonAssets(),
            child: CoolvibesApp(
              session: session,
              home: Builder(
                builder: (context) => AppScaffold(
                  body: TextButton(
                    onPressed: () =>
                        EmoticonPicker.show(context, initialTab: 'emoji'),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await pumpUI(tester);
        final modal = tester.widget<liquid.GlassModalSheetScaffold>(
          find.byType(liquid.GlassModalSheetScaffold),
        );
        expect(
          modal.settings!.glassColor,
          dark ? AppDesign.inputMediaPanelDark : AppDesign.inputMediaPanelLight,
        );
        final bar = find.byKey(const ValueKey('emoji.search'));
        final love = find.byKey(const ValueKey('emoji.group.love'));
        expect(tester.getSize(bar).height, 36);
        expect(
          find.descendant(of: bar, matching: find.text('❤️')),
          findsNothing,
        );
        final animation = tester.widget<AppLottie>(
          find.descendant(of: love, matching: find.byType(AppLottie)),
        );
        expect(animation.asset, 'assets/animations/emoji_search/love.json');
        expect(animation.size, 24);
        expect(animation.loop, isFalse);
        await tester.ensureVisible(love);
        await pumpUI(tester);
        await tester.tap(love);
        await pumpUI(tester);
        expect(tester.widget<AppPressable>(love).selected, isTrue);
        expect(find.text('😀').hitTestable(), findsNothing);
        expect(find.text('💛').hitTestable(), findsWidgets);
        final selectedAnimation = tester.widget<AppLottie>(
          find.descendant(of: love, matching: find.byType(AppLottie)),
        );
        expect(
          selectedAnimation.color,
          AppDesign.emojiSearchColors(tester.element(bar)).selected,
        );
        await tester.tap(find.byKey(const ValueKey('emoji.search.status')));
        await pumpUI(tester);
        expect(tester.widget<AppPressable>(love).selected, isFalse);
        await tester.tap(find.byKey(const ValueKey('emoji.search.activate')));
        await pumpUI(tester);
        expect(
          find.byKey(const ValueKey('emoji.search.cancel')),
          findsOneWidget,
        );
        expect(love, findsNothing);
        await tester.enterText(find.byType(TextField), 'kalp');
        await pumpUI(tester);
        expect(find.text('😀').hitTestable(), findsNothing);
        await tester.tap(find.byKey(const ValueKey('emoji.search.cancel')));
        await pumpUI(tester);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty,
        );
        expect(love, findsOneWidget);
        await tester.ensureVisible(find.bySemanticsLabel('GIF'));
        await pumpUI(tester);
        await tester.tap(find.bySemanticsLabel('GIF'));
        await pumpUI(tester);
        expect(api.queries, ['']);
        await tester.ensureVisible(love);
        await pumpUI(tester);
        await tester.tap(love);
        await pumpUI(tester);
        expect(api.queries, ['', 'love']);
        final segments = tester.widget<AppSegments<String>>(
          find.byType(AppSegments<String>),
        );
        final stickerLabel = (segments.values['stickers'] as Text).data!;
        await tester.ensureVisible(find.bySemanticsLabel(stickerLabel));
        await pumpUI(tester);
        await tester.tap(find.bySemanticsLabel(stickerLabel));
        await pumpUI(tester);
        expect(
          tester
              .widget<AppSegments<String>>(find.byType(AppSegments<String>))
              .selected,
          'stickers',
        );
        expect(tester.widget<AppPressable>(love).selected, isFalse);
        expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        session.dispose();
      },
    );
  }
}
