import 'package:flutter/material.dart';
import 'package:coolvibes/components/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/screens/radar.dart';
import 'package:coolvibes/screens/discover.dart';
import 'package:coolvibes/components/radar_profile_card.dart';
import 'package:coolvibes/components/glass_surface.dart';
import 'package:coolvibes/l10n/l10n.dart';
import 'package:coolvibes/vendor/liquid_glass_widgets/liquid_glass_widgets.dart'
    as liquid;
import 'package:coolvibes/vendor/liquid_glass_widgets/widgets/effects/progressive_blur.dart'
    show RenderProgressiveBlur;
import 'support/ui_driver.dart';

void main({bool nativeRendering = false}) {
  for (final mode in ['light', 'dark', 'accessible', 'large-rtl']) {
    testWidgets('radar details scroll behind the fixed profile header: $mode', (
      tester,
    ) async {
      if (!nativeRendering &&
          !const bool.fromEnvironment('NATIVE_HOST_TOUCH')) {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3;
        tester.view.viewPadding = const FakeViewPadding(top: 177, bottom: 102);
        tester.view.padding = const FakeViewPadding(top: 177, bottom: 102);
        addTearDown(tester.view.reset);
      }
      final api = PreviewApi(PreviewState.populated);
      if (mode == 'large-rtl') {
        api.profilePeer['displayname'] = 'Uzun profil adı ve soyadı';
      }
      final session = Session(api, persistPreferences: false)
        ..ready = true
        ..user = previewSelf
        ..locale = Locale(mode == 'large-rtl' ? 'ar' : 'tr')
        ..themeMode = mode == 'dark' ? ThemeMode.dark : ThemeMode.light;
      await tester.pumpWidget(
        CoolvibesApp(
          session: session,
          home: liquid.GlassAccessibilityScope(
            reduceTransparency: mode == 'accessible',
            child: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(mode == 'large-rtl' ? 2 : 1),
                ),
                child: const RadarScreen(),
              ),
            ),
          ),
        ),
      );
      await pumpUI(tester);
      final backdrop = find.byKey(const ValueKey('app.header.backdrop'));
      expect(backdrop, findsNothing);
      expect(find.byType(RadarProfileCard), findsNothing);
      await tapUI(tester, find.byKey(const ValueKey('1002')));
      await waitForUI(tester, find.byType(RadarProfileCard));
      await pumpUI(tester);
      expect(find.byType(RadarProfileCard), findsOneWidget);
      final headerBounds = tester.getRect(find.byType(AppHeader));
      expect(tester.getRect(backdrop), headerBounds);
      final blur = find.descendant(
        of: backdrop,
        matching: find.byType(liquid.ProgressiveBlur),
      );
      if (mode == 'accessible') {
        expect(blur, findsNothing);
        final decoration =
            tester
                    .widget<DecoratedBox>(
                      find.descendant(
                        of: backdrop,
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as BoxDecoration;
        expect(decoration.color!.a, 1);
      } else {
        expect(blur, findsOneWidget);
        if (nativeRendering ||
            const bool.fromEnvironment('NATIVE_HOST_TOUCH')) {
          expect(
            tester.allRenderObjects.whereType<RenderProgressiveBlur>(),
            hasLength(1),
            reason: 'iOS must use the compiled progressive shader.',
          );
        }
      }
      final avatar = find.descendant(
        of: find.byType(RadarProfileCard),
        matching: find.byType(Avatar),
      );
      await tapUI(tester, avatar);
      final about = find.byKey(const ValueKey('radar.profile.about'));
      await waitForUI(tester, about);
      await tester.pump(const Duration(seconds: 3));
      await pumpUI(tester);
      final canvas = tester.widget<AppBackdropBlur>(
        find.byKey(const ValueKey('radar.profile.canvas')),
      );
      expect(canvas.tint!.a, lessThan(.3));
      final profileGlass = find.byKey(const ValueKey('radar.profile.backdrop'));
      final material = tester.widget<liquid.GlassContainer>(
        find.descendant(
          of: profileGlass,
          matching: find.byType(liquid.GlassContainer),
        ),
      );
      expect(material.useOwnLayer, isTrue);
      expect(material.quality, liquid.GlassQuality.premium);
      expect(material.settings!.glassColor.a, lessThan(.3));
      expect(material.settings!.thickness, greaterThan(0));
      expect(material.settings!.frost, greaterThan(0));
      expect(material.settings!.lightIntensity, 0);
      expect(material.settings!.fresnelStrength, 0);
      final opticalRenderer = find.descendant(
        of: profileGlass,
        matching: find.byWidgetPredicate(
          (w) =>
              w is liquid.LiquidGlassLayer ||
              w is liquid.LightweightLiquidGlass,
        ),
      );
      expect(
        opticalRenderer,
        mode == 'accessible' ? findsNothing : findsWidgets,
      );
      if (nativeRendering && mode != 'accessible') {
        expect(
          find.descendant(
            of: profileGlass,
            matching: find.byType(liquid.LiquidGlassLayer),
          ),
          findsOneWidget,
          reason: 'The fixed profile header must render the iOS glass shader.',
        );
      }
      final parts = [
        for (final part in ['avatar', 'identity', 'actions', 'about'])
          find.byKey(ValueKey('radar.profile.$part')),
      ];
      final before = parts.map(tester.getRect).toList();
      expect(before[0].top, closeTo(headerBounds.bottom + 20, 1));
      expect(before[0].bottom, lessThanOrEqualTo(before[1].top));
      expect(before[1].bottom, lessThan(before[2].top));
      expect(before[2].bottom, lessThan(before[3].top));
      final close = find.byKey(const ValueKey('radar.profile.close'));
      final closeBounds = tester.getRect(close);
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      final start = Offset(screen.width / 2, screen.height - 140);
      if (const bool.fromEnvironment('NATIVE_HOST_TOUCH')) {
        await nativeTouch(tester, start, start - const Offset(0, 360));
      } else {
        await tester.dragFrom(start, const Offset(0, -360));
      }
      await pumpUI(tester);
      final scroll = find
          .descendant(
            of: find.byKey(const ValueKey('radar.profile.scroll')),
            matching: find.byType(Scrollable),
          )
          .first;
      final offset = tester.state<ScrollableState>(scroll).position.pixels;
      expect(offset, greaterThan(0));
      for (var i = 0; i < parts.length - 1; i++) {
        expect(
          tester.getRect(parts[i]),
          before[i],
          reason: 'Avatar, identity and actions must remain fixed.',
        );
      }
      expect(before.last.top - tester.getRect(about).top, closeTo(offset, 1));
      final profileBackdrop = tester.getRect(
        find.byKey(const ValueKey('radar.profile.backdrop')),
      );
      expect(profileBackdrop.top, lessThanOrEqualTo(before.first.top));
      expect(profileBackdrop.bottom, greaterThan(before[2].bottom));
      expect(tester.getRect(about).top, lessThan(profileBackdrop.bottom));
      expect(tester.getRect(close), closeBounds);
      expect(close.hitTestable(), findsOneWidget);
      expect(tester.getRect(backdrop), headerBounds);
      final l = tester.element(find.byType(RadarScreen)).l10n;
      await tapUI(
        tester,
        find.byWidgetPredicate(
          (w) => w is AppIconButton && w.tooltip == l.search,
        ),
      );
      await pumpUI(tester);
      expect(find.byType(SearchScreen), findsOneWidget);
      expect(backdrop, findsNothing);
      final back = MaterialLocalizations.of(
        tester.element(find.byType(SearchScreen)),
      ).backButtonTooltip;
      await tapUI(
        tester,
        find.byWidgetPredicate((w) => w is AppIconButton && w.tooltip == back),
      );
      await pumpUI(tester);
      await tapUI(
        tester,
        find.byWidgetPredicate((w) => w is AppPressable && w.label == l.close),
      );
      await pumpUI(tester);
      expect(find.byType(RadarProfileCard), findsNothing);
      expect(backdrop, findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    });
  }
  testWidgets('nearby profile stays below header while details scroll', (
    tester,
  ) async {
    if (!nativeRendering && !const bool.fromEnvironment('NATIVE_HOST_TOUCH')) {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      tester.view.viewPadding = const FakeViewPadding(top: 177, bottom: 102);
      tester.view.padding = const FakeViewPadding(top: 177, bottom: 102);
      addTearDown(tester.view.reset);
    }
    final api = PreviewApi(PreviewState.populated);
    final session = Session(api, persistPreferences: false)
      ..ready = true
      ..user = previewSelf
      ..locale = const Locale('tr');
    await tester.pumpWidget(
      CoolvibesApp(session: session, home: const NearbyScreen()),
    );
    await pumpUI(tester);
    await tapUI(tester, find.byType(PersonTile).first);
    await waitForUI(tester, find.byType(RadarProfileCard));
    await pumpUI(tester);
    await tapUI(
      tester,
      find.descendant(
        of: find.byType(RadarProfileCard),
        matching: find.byKey(const ValueKey('radar.profile.avatar')),
      ),
    );
    final about = find.byKey(const ValueKey('radar.profile.about'));
    await waitForUI(tester, about);
    await tester.pump(const Duration(seconds: 3));
    await pumpUI(tester);

    final header = tester.getRect(find.byType(AppHeader));
    final avatar = find.byKey(const ValueKey('radar.profile.avatar'));
    final identity = find.byKey(const ValueKey('radar.profile.identity'));
    final actions = find.byKey(const ValueKey('radar.profile.actions'));
    final before = [
      tester.getRect(avatar),
      tester.getRect(identity),
      tester.getRect(actions),
    ];
    final aboutBefore = tester.getRect(about);
    expect(before.first.top, closeTo(header.bottom + 20, 1));

    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    await tester.dragFrom(
      Offset(screen.width / 2, screen.height - 140),
      const Offset(0, -360),
    );
    await pumpUI(tester);
    final scroll = find
        .descendant(
          of: find.byKey(const ValueKey('radar.profile.scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    final offset = tester.state<ScrollableState>(scroll).position.pixels;
    expect(offset, greaterThan(0));
    for (final (finder, rect) in [
      (avatar, before[0]),
      (identity, before[1]),
      (actions, before[2]),
    ]) {
      expect(tester.getRect(finder), rect);
    }
    expect(aboutBefore.top - tester.getRect(about).top, closeTo(offset, 1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
}
