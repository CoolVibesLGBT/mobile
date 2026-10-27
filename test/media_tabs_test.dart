import 'dart:ui' as ui;
import 'package:coolvibes/app.dart';
import 'package:coolvibes/components/components.dart';
import 'package:coolvibes/components/glass_surface.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/screens/emoticons.dart';
import 'package:coolvibes/vendor/liquid_glass_widgets/liquid_glass_widgets.dart'
    as liquid;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/source_assets.dart';
import 'support/ui_driver.dart';

void main() {
  for (final variant in [(false, 'tr'), (true, 'tr'), (false, 'ar')]) {
    final (dark, language) = variant;
    testWidgets(
      'nested media tabs keep their glass lens on press and drag: $dark/$language',
      (tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        final boundaryKey = GlobalKey();
        final scale = ValueNotifier(1.0);
        final emojiOnly = ValueNotifier(false);
        final session =
            Session(PreviewApi(PreviewState.empty), persistPreferences: false)
              ..ready = true
              ..user = previewSelf
              ..locale = Locale(language)
              ..themeMode = dark ? ThemeMode.dark : ThemeMode.light;
        await tester.pumpWidget(
          DefaultAssetBundle(
            bundle: JsonAssets(),
            child: RepaintBoundary(
              key: boundaryKey,
              child: CoolvibesApp(
                session: session,
                home: Builder(
                  builder: (context) => ValueListenableBuilder(
                    valueListenable: scale,
                    builder: (context, textScale, _) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(textScale)),
                      child: AppScaffold(
                        body: DecoratedBox(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xff4ba6af), Color(0xffd2ad69)],
                            ),
                          ),
                          child: Center(
                            child: SizedBox(
                              height: 450,
                              child: GlassSurface(
                                role: GlassSurfaceRole.sheet,
                                radius: 30,
                                child: ValueListenableBuilder(
                                  valueListenable: emojiOnly,
                                  builder: (context, only, _) => EmoticonPicker(
                                    embedded: true,
                                    initialTab: 'emoji',
                                    emojiOnly: only,
                                    onSelected: (_) {},
                                    onKeyboard: () {},
                                    onErase: () {},
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await pumpUI(tester);
        final tabs = find.byKey(const ValueKey('emoji.tabs'));
        final control = find.descendant(
          of: tabs,
          matching: find.byType(liquid.GlassSegmentedControl),
        );
        final emoji = find.descendant(of: tabs, matching: find.text('Emoji'));
        final gif = find.descendant(of: tabs, matching: find.text('GIF'));
        final indicators = find.descendant(
          of: tabs,
          matching: find.byType(liquid.AnimatedGlassIndicator),
        );
        liquid.AnimatedGlassIndicator lens() => tester
            .widgetList<liquid.AnimatedGlassIndicator>(indicators)
            .firstWhere((w) => w.paintGlass);
        expect(tester.getSize(control).height, 40);
        expect(
          tester.getSize(emoji).width + 18,
          closeTo(lens().exactWidth!, .1),
        );
        final inherited = tester
            .element(indicators.last)
            .getInheritedWidgetOfExactType<liquid.InheritedLiquidGlass>();
        expect(
          inherited!.avoidsRefraction,
          isFalse,
          reason: 'The enclosing sheet must not flatten the moving lens.',
        );
        final beforeWidth = lens().exactWidth!;
        final beforeOffset = lens().exactOffset!;
        final tabRect = tester.getRect(control);
        Future<List<int>> pixels() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          return (await tester.runAsync(() async {
            final image = await boundary.toImage();
            final data = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            final result = <int>[];
            for (
              var y = (tabRect.top - 5).floor();
              y < (tabRect.bottom + 5).ceil();
              y++
            ) {
              for (
                var x = tabRect.left.floor();
                x < tabRect.right.ceil();
                x++
              ) {
                final index = (y * image.width + x) * 4;
                result.addAll([
                  data.getUint8(index),
                  data.getUint8(index + 1),
                  data.getUint8(index + 2),
                ]);
              }
            }
            image.dispose();
            return result;
          }))!;
        }

        final resting = await pixels();
        final press = await tester.startGesture(tester.getCenter(emoji));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 160));
        expect(lens().thickness, greaterThan(.3));
        final lifted = await pixels();
        final changed = List.generate(
          resting.length,
          (i) => (resting[i] - lifted[i]).abs(),
        ).where((d) => d > 8).length;
        expect(
          changed,
          greaterThan(60),
          reason: 'A press must visibly lift and refract the lens.',
        );
        await press.cancel();
        await pumpUI(tester);
        expect(lens().thickness, closeTo(0, .02));
        expect(lens().exactWidth, closeTo(beforeWidth, .1));
        expect(lens().exactOffset, closeTo(beforeOffset, .1));
        final stickerText =
            (tester.widget<AppSegments<String>>(tabs).values['stickers']
                    as Text)
                .data!;
        final stickers = find.descendant(
          of: tabs,
          matching: find.text(stickerText),
        );
        await tester.timedDragFrom(
          tester.getCenter(emoji),
          tester.getCenter(stickers) - tester.getCenter(emoji),
          const Duration(milliseconds: 700),
        );
        await pumpUI(tester);
        expect(tester.widget<AppSegments<String>>(tabs).selected, 'stickers');
        await tester.ensureVisible(gif);
        await pumpUI(tester);
        await tester.tap(gif);
        await pumpUI(tester);
        expect(tester.widget<AppSegments<String>>(tabs).selected, 'gif');
        final physicalLensCenter =
            tester.getTopLeft(control).dx +
            4 +
            lens().exactOffset! +
            lens().exactWidth! / 2;
        expect(physicalLensCenter, closeTo(tester.getCenter(gif).dx, 1));
        await tester.ensureVisible(emoji);
        await pumpUI(tester);
        await tester.tap(emoji);
        await pumpUI(tester);
        expect(tester.widget<AppSegments<String>>(tabs).selected, 'emoji');
        final semantics = tester.ensureSemantics();
        expect(
          tester
              .getSemantics(find.bySemanticsLabel('Emoji').last)
              .getSemanticsData()
              .flagsCollection
              .isSelected,
          ui.Tristate.isTrue,
        );
        semantics.dispose();
        scale.value = 2;
        await pumpUI(tester);
        expect(tester.getSize(control).height, greaterThan(40));
        final scroll = find.descendant(
          of: tabs,
          matching: find.byType(SingleChildScrollView),
        );
        expect(scroll, findsOneWidget);
        expect(tester.takeException(), isNull);
        emojiOnly.value = true;
        await pumpUI(tester);
        expect(
          tabs,
          findsNothing,
          reason: 'A single emoji-only page has no tab selector.',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        session.dispose();
        scale.dispose();
        emojiOnly.dispose();
      },
    );
  }
}
