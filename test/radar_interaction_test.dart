import 'package:flutter/material.dart';
import 'package:coolvibes/components/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/screens/discover.dart';
import 'package:coolvibes/screens/radar.dart';
import 'package:coolvibes/components/radar_group_card.dart';
import 'package:coolvibes/components/radar_profile_card.dart';
import 'package:coolvibes/components/glass_surface.dart';
import 'package:coolvibes/design/app_design.dart';
import 'package:coolvibes/l10n/l10n.dart';
import 'package:coolvibes/vendor/liquid_glass_widgets/liquid_glass_widgets.dart'
    as liquid;
import 'support/ui_driver.dart';
import 'support/contract_api.dart';

void main({bool nativeRendering = false}) {
  testWidgets('group preview expands and closes without joining or mutating', (
    tester,
  ) async {
    final api = ContractApi();
    final session = Session(api, persistPreferences: false)
      ..ready = true
      ..user = previewSelf;
    await tester.pumpWidget(
      CoolvibesApp(session: session, home: const RadarScreen()),
    );
    await pumpUI(tester);
    await tapUI(tester, find.byKey(const ValueKey('grp1')));
    await pumpUI(tester);
    expect(find.byType(RadarGroupCard), findsOneWidget);
    await tapUI(tester, find.byKey(const ValueKey('radar.group.avatar')));
    await pumpUI(tester);
    await tapUI(tester, find.byKey(const ValueKey('radar.group.close')));
    await pumpUI(tester);
    expect(find.byType(RadarGroupCard), findsNothing);
    expect(
      api.calls.map((call) => call.action),
      everyElement(isIn(['chat.group.list', 'chat.participants.fetch'])),
    );
    expect(
      api.calls.where((call) => call.action == 'chat.group.join'),
      isEmpty,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
  // Radar now displays groups. Person-card interaction belongs to NearbyScreen,
  // which is the production owner of the shared RadarProfileCard overlay.
  for (final mode in ['light', 'dark', 'accessible', 'large-rtl']) {
    testWidgets(
      'nearby profile identity stays pinned while details scroll: $mode',
      (tester) async {
        if (!nativeRendering &&
            !const bool.fromEnvironment('NATIVE_HOST_TOUCH')) {
          tester.view.physicalSize = const Size(1170, 2532);
          tester.view.devicePixelRatio = 3;
          tester.view.viewPadding = const FakeViewPadding(
            top: 177,
            bottom: 102,
          );
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
                    disableAnimations: mode == 'accessible',
                    textScaler: TextScaler.linear(mode == 'large-rtl' ? 2 : 1),
                  ),
                  child: const NearbyScreen(),
                ),
              ),
            ),
          ),
        );
        await pumpUI(tester);
        final headerBounds = tester.getRect(find.byType(AppHeader));
        expect(find.byType(RadarProfileCard), findsNothing);
        await tapUI(tester, find.byType(PersonTile).first);
        await waitForUI(tester, find.byType(RadarProfileCard));
        await pumpUI(tester);
        final close = find.byKey(const ValueKey('radar.profile.close'));
        expect(close.hitTestable(), findsOneWidget);
        await tapUI(tester, find.byKey(const ValueKey('radar.profile.avatar')));
        final about = find.byKey(const ValueKey('radar.profile.about'));
        await waitForUI(tester, about);
        await tester.pump(const Duration(seconds: 3));
        await pumpUI(tester);
        final glass = tester.widget<GlassSurface>(
          find.byKey(const ValueKey('radar.profile.backdrop')),
        );
        expect(glass.useOwnLayer, isTrue);
        final parts = [
          for (final part in ['avatar', 'identity', 'actions', 'about'])
            find.byKey(ValueKey('radar.profile.$part')),
        ];
        final before = parts.map(tester.getRect).toList();
        expect(
          before.first.width,
          closeTo(AppDesign.radarExpandedAvatarSize, 1),
        );
        expect(before.first.top, closeTo(headerBounds.bottom + 20, 1));
        for (var i = 0; i < before.length - 1; i++) {
          expect(before[i].bottom, lessThanOrEqualTo(before[i + 1].top));
        }
        final closeBounds = tester.getRect(close);
        final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
        final start = Offset(screen.width / 2, screen.height - 70);
        if (const bool.fromEnvironment('NATIVE_HOST_TOUCH')) {
          await nativeTouch(tester, start, start - const Offset(0, 240));
        } else {
          await tester.dragFrom(start, const Offset(0, -240));
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
            reason: 'The source card pins avatar, identity and actions.',
          );
        }
        expect(before.last.top - tester.getRect(about).top, closeTo(offset, 1));
        expect(tester.getRect(close), closeBounds);
        expect(close.hitTestable(), findsOneWidget);
        expect(tester.getRect(find.byType(AppHeader)), headerBounds);
        final l = tester.element(find.byType(NearbyScreen)).l10n;
        await tapUI(
          tester,
          find.byWidgetPredicate(
            (w) => w is AppIconButton && w.tooltip == l.search,
          ),
        );
        await pumpUI(tester);
        expect(find.byType(SearchScreen), findsOneWidget);
        final back = MaterialLocalizations.of(
          tester.element(find.byType(SearchScreen)),
        ).backButtonTooltip;
        await tapUI(
          tester,
          find.byWidgetPredicate(
            (w) => w is AppIconButton && w.tooltip == back,
          ),
        );
        await pumpUI(tester);
        expect(find.byType(RadarProfileCard), findsOneWidget);
        await tapUI(tester, close);
        await pumpUI(tester);
        expect(find.byType(RadarProfileCard), findsNothing);
        expect(find.byType(PersonTile), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        session.dispose();
      },
    );
  }
}
