import 'package:coolvibes/app.dart';
import 'package:coolvibes/components/app_button.dart';
import 'package:coolvibes/components/app_segments.dart';
import 'package:coolvibes/components/app_tab_bar.dart';
import 'package:coolvibes/components/glass_surface.dart';
import 'package:coolvibes/components/game_map.dart';
import 'package:coolvibes/components/radar_profile_card.dart';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/components/navigation.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/screens/discover.dart';
import 'package:coolvibes/screens/location_picker.dart';
import 'package:coolvibes/screens/shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'audit_regression_test.dart' show AuditApi, AuditSession;
import 'support/glass_assertions.dart';
import 'support/ui_driver.dart';

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('nearby map glass survives real shell navigation in $mode', (
      tester,
    ) async {
      final session = AuditSession(AuditApi())
        ..ready = true
        ..user = previewSelf
        ..themeMode = mode;
      await tester.pumpWidget(
        CoolvibesApp(session: session, home: const Shell(initialTab: 1)),
      );
      await pumpUI(tester);
      expect(
        PlatformBackdrop.active,
        isFalse,
        reason: 'The hidden check-in map must not affect the active grid',
      );
      final selector = find.byType(AppSegments<String>);
      Future<void> selectView(int index) async {
        final rect = tester.getRect(selector);
        await tester.tapAt(
          Offset(rect.left + rect.width * (index + .5) / 3, rect.center.dy),
        );
        await pumpUI(tester);
      }

      await selectView(2);
      expectRoundMapControls(tester);
      expectMapTabBar(tester);
      Future<void> selectTab(int index) async {
        final rect = tester.getRect(find.byType(AppTabBar));
        await tester.tapAt(
          Offset(rect.left + rect.width * (index + .5) / 5, rect.center.dy),
        );
        await pumpUI(tester);
        expect(
          tester.widget<AppTabBar>(find.byType(AppTabBar)).selected,
          index,
        );
      }

      await selectTab(0);
      expect(PlatformBackdrop.active, isFalse);
      await selectTab(1);
      expectMapTabBar(tester);
      await selectView(1);
      expect(find.byType(GameMap), findsNothing);
      expect(PlatformBackdrop.active, isFalse);
      await selectView(2);
      expectMapTabBar(tester);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      session.dispose();
      expect(PlatformBackdrop.active, isFalse);
    });
  }
  testWidgets(
    'nearby map extends behind header, exposes markers and teleport',
    (tester) async {
      final session = AuditSession(AuditApi())
        ..ready = true
        ..user = previewSelf;
      await tester.pumpWidget(
        CoolvibesApp(
          session: session,
          home: const NearbyScreen(initialView: 'map'),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final mapFinder = find.byType(GameMap);
      expectRoundMapControls(tester);
      final map = tester.widget<GameMap>(mapFinder);
      expect(map.zoom, 12.5);
      expect(map.markers.length, 37);
      expect(tester.getRect(mapFinder).top, 0);
      expect(
        tester.getRect(mapFinder).width,
        tester.view.physicalSize.width / tester.view.devicePixelRatio,
      );
      final first = map.markers.first;
      expect(first['latitude'], isA<double>());
      map.onMarker!(string(first['id']));
      await tester.pump();
      final card = tester.widget<RadarProfileCard>(
        find.byType(RadarProfileCard),
      );
      expect(recordId(card.user), first['id']);
      card.onClose();
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (w) => w is AppIconButton && w.tooltip == 'Konumum',
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is AppIconButton && w.tooltip == 'Konum değiştir',
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        tester
            .widget<LocationPickerScreen>(find.byType(LocationPickerScreen))
            .teleport,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}
