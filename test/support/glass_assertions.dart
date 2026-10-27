import 'package:coolvibes/components/app_button.dart';
import 'package:coolvibes/components/app_header.dart';
import 'package:coolvibes/components/app_tab_bar.dart';
import 'package:coolvibes/components/game_map.dart';
import 'package:coolvibes/components/message_field.dart';
import 'package:coolvibes/design/app_design.dart';
import 'package:coolvibes/vendor/liquid_glass_widgets/liquid_glass_widgets.dart'
    as liquid;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder iconControl(IconData icon) => find.byWidgetPredicate(
  (w) => w is AppIconButton && w.icon is Icon && (w.icon as Icon).icon == icon,
);

Future<void> expectInputGlassPress(WidgetTester tester) async {
  final surface = find
      .descendant(
        of: find.byType(MessageField),
        matching: find.byType(liquid.GlassContainer),
      )
      .first;
  final editor = find.descendant(
    of: find.byType(MessageField),
    matching: find.byType(TextField),
  );
  for (final cancel in [false, true]) {
    final rest = tester.getRect(surface);
    final gesture = await tester.startGesture(tester.getCenter(editor));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    final pressed = tester.getRect(surface);
    expect(pressed.width, greaterThan(rest.width + 2));
    expect(pressed.height, greaterThan(rest.height));
    await gesture.moveBy(const Offset(48, 0));
    await tester.pump();
    final stretched = tester.getRect(surface);
    expect(
      stretched.width / stretched.height,
      greaterThan(rest.width / rest.height),
    );
    if (cancel) {
      await gesture.cancel();
    } else {
      await gesture.up();
    }
    await tester.pump();
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final settled = tester.getRect(surface);
    expect(settled.width, closeTo(rest.width, .1));
    expect(settled.height, closeTo(rest.height, .1));
  }
}

/// Exercise this with the real Shell so an opaque ancestor or an incorrectly
/// inset map cannot pass a test of the glass widget in isolation.
void expectMapTabBar(WidgetTester tester) {
  final target = find.byType(AppTabBar);
  final bounds = tester.getRect(target);
  final bar = tester.widget<liquid.GlassTabBar>(
    find.descendant(of: target, matching: find.byType(liquid.GlassTabBar)),
  );
  expect(bar.platformViewBackdrop, isTrue);
  expect(bar.settings!.glassColor.a, lessThan(.5));
  expect(bar.settings!.blur, AppDesign.glassFrost);
  final dark = Theme.of(tester.element(target)).brightness == Brightness.dark;
  expect(bar.settings!.effectiveShadow, dark ? isEmpty : AppDesign.glassShadow);
  final mapBounds = tester.getRect(find.byType(GameMap));
  expect(mapBounds.top, 0);
  expect(
    mapBounds.bottom,
    tester.view.physicalSize.height / tester.view.devicePixelRatio,
  );
  expect(mapBounds.contains(bounds.center), isTrue);

  final fills = find.descendant(
    of: target,
    matching: find.byType(DecoratedBox),
  );
  for (final element in fills.evaluate()) {
    final box = element.widget as DecoratedBox;
    final decoration = box.decoration;
    final color = switch (decoration) {
      BoxDecoration() => decoration.color,
      ShapeDecoration() => decoration.color,
      _ => null,
    };
    if (tester.getSize(find.byWidget(box)).width > bounds.width * .9) {
      expect(
        color?.a ?? 0,
        lessThan(1),
        reason: 'A solid backplate hides the map',
      );
    }
  }
  final clips = find.descendant(of: target, matching: find.byType(ClipRRect));
  expect(
    clips.evaluate().any((element) {
      final clip = element.widget as ClipRRect;
      final finder = find.byWidget(clip);
      final size = tester.getSize(finder);
      if (size.width < bounds.width * .9 || size.height != AppTabBar.height) {
        return false;
      }
      final rect =
          clip.clipper?.getClip(size) ??
          clip.borderRadius
              .resolve(TextDirection.ltr)
              .toRRect(Offset.zero & size)
              .scaleRadii();
      return (rect.tlRadiusX - AppTabBar.height / 2).abs() < .001 &&
          find
              .descendant(of: finder, matching: find.byType(BackdropFilter))
              .evaluate()
              .isNotEmpty;
    }),
    isTrue,
    reason: 'The complete tab track must blur the map through a capsule clip',
  );
  for (final icon in [Icons.travel_explore, Icons.my_location]) {
    expect(tester.getRect(iconControl(icon)).bottom, lessThan(bounds.top));
  }
}

void expectChatMaterials(WidgetTester tester) {
  final field = tester.widget<liquid.GlassContainer>(
    find
        .descendant(
          of: find.byType(MessageField),
          matching: find.byType(liquid.GlassContainer),
        )
        .first,
  );
  final settings = field.settings!;
  expect(field.quality, liquid.GlassQuality.premium);
  expect(settings.thickness, greaterThan(0));
  expect(settings.lightIntensity, greaterThan(0));
  expect(settings.fresnelStrength, greaterThan(0));
  expect(settings.blur, AppDesign.glassSurfaceBlur);
  expect(settings.glassColor.a, inExclusiveRange(.7, 1));
  expect(settings.standardOpacityMultiplier, 1);
  void expectOpticalSurface(Finder target) {
    // Inspect the active renderer as well as its settings: minimal and
    // accessibility fallbacks never construct either of these shader paths.
    expect(
      find.descendant(
        of: target,
        matching: find.byWidgetPredicate(
          (w) =>
              w is liquid.LiquidGlassLayer ||
              w is liquid.LightweightLiquidGlass,
        ),
      ),
      findsWidgets,
    );
  }

  expectOpticalSurface(find.byWidget(field));
  final dark =
      Theme.of(tester.element(find.byType(MessageField))).brightness ==
      Brightness.dark;
  expect(
    settings.glassColor,
    dark ? AppDesign.glassFrostedDark : AppDesign.glassInputLight,
  );
  expect(settings.effectiveShadow, dark ? isEmpty : AppDesign.glassShadow);
  final controls = [
    ...find
        .descendant(
          of: find.byType(AppHeader),
          matching: find.byType(liquid.GlassButton),
        )
        .evaluate(),
    ...find
        .descendant(
          of: iconControl(Icons.attach_file),
          matching: find.byType(liquid.GlassButton),
        )
        .evaluate(),
  ];
  expect(controls.length, greaterThanOrEqualTo(3));
  for (final element in controls) {
    final button = element.widget as liquid.GlassButton;
    expect(button.settings, settings);
    expect(button.quality, field.quality);
    expect(button.isStationary, isTrue);
    expectOpticalSurface(find.byWidget(button));
  }
  final mic = tester.widget<liquid.GlassContainer>(
    find.descendant(
      of: iconControl(Icons.mic_none),
      matching: find.byType(liquid.GlassContainer),
    ),
  );
  expect(mic.settings, settings);
  expect(mic.quality, field.quality);
  expectOpticalSurface(find.byWidget(mic));
  expect(mic.shape, isA<liquid.LiquidOval>());
}

void expectRoundMapControls(WidgetTester tester) {
  for (final icon in [Icons.travel_explore, Icons.my_location]) {
    final control = iconControl(icon);
    expect(control, findsOneWidget);
    expect(tester.getSize(control), const Size(48, 48));
    final button = tester.widget<liquid.GlassButton>(
      find.descendant(of: control, matching: find.byType(liquid.GlassButton)),
    );
    expect(button.platformViewBackdrop, isTrue);
    final dark =
        Theme.of(tester.element(control)).brightness == Brightness.dark;
    expect(
      button.settings!.effectiveShadow,
      dark ? isEmpty : AppDesign.glassShadow,
    );
    // Verify the actual blur clip passed to the platform compositor, not just
    // the decorative border: 48pt circle, empty corners, included centre.
    final clips = find.descendant(
      of: control,
      matching: find.byType(ClipRRect),
    );
    final diagnostics = <String>[];
    expect(
      clips.evaluate().any((element) {
        final clip = element.widget as ClipRRect;
        final target = find.byWidget(clip);
        if (find
            .descendant(of: target, matching: find.byType(BackdropFilter))
            .evaluate()
            .isEmpty) {
          return false;
        }
        final size = tester.getSize(target);
        final rect =
            clip.clipper?.getClip(size) ??
            clip.borderRadius
                .resolve(TextDirection.ltr)
                .toRRect(Offset.zero & size);
        diagnostics.add('$size: $rect, radius=${rect.tlRadiusX}');
        return size == const Size(48, 48) &&
            (rect.tlRadiusX - 24).abs() < .001 &&
            rect.contains(const Offset(24, 24)) &&
            !rect.contains(const Offset(1, 1));
      }),
      isTrue,
      reason: diagnostics.toString(),
    );
  }
}
