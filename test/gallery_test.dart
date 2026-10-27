import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/debug/gallery.dart';
import 'package:coolvibes/debug/preview_api.dart';

void main() {
  for (final destination in debugDestinations) {
    testWidgets('gallery renders ${destination.id} using production widget', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = Session(PreviewApi(PreviewState.populated))
        ..ready = true
        ..user = previewSelf
        ..system = previewSystem;
      await tester.pumpWidget(
        CoolvibesApp(
          session: session,
          home: Builder(builder: destination.build),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: destination.id);
      for (final header in tester.widgetList<AppBar>(find.byType(AppBar))) {
        expect(
          header.forceMaterialTransparency,
          isTrue,
          reason: destination.id,
        );
        expect(
          header.backgroundColor,
          Colors.transparent,
          reason: destination.id,
        );
        expect(header.toolbarHeight, 44, reason: destination.id);
        expect(header.scrolledUnderElevation, 0, reason: destination.id);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      session.dispose();
    });
  }
  for (final variant in [
    PreviewState.empty,
    PreviewState.error,
    PreviewState.loading,
  ]) {
    for (final destination in debugDestinations.where(
      (d) => [
        'feed',
        'nearby',
        'radar',
        'chats',
        'chat.private',
        'profile.self',
        'profile.peer',
        'post.detail',
        'places',
        'classifieds',
        'activity',
      ].contains(d.id),
    )) {
      testWidgets(
        '${destination.id} ${variant.name} has no layout or lifecycle errors',
        (tester) async {
          final session =
              Session(PreviewApi(variant), persistPreferences: false)
                ..ready = true
                ..user = previewSelf
                ..system = previewSystem;
          await tester.pumpWidget(
            CoolvibesApp(
              session: session,
              home: Builder(builder: destination.build),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump(const Duration(milliseconds: 500));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          session.dispose();
        },
      );
    }
  }
  for (final destination in debugDestinations) {
    testWidgets('${destination.id} RTL 2x narrow viewport', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final session =
          Session(PreviewApi(PreviewState.populated), persistPreferences: false)
            ..ready = true
            ..user = previewSelf
            ..locale = const Locale('ar')
            ..themeMode = ThemeMode.dark;
      await tester.pumpWidget(
        CoolvibesApp(
          session: session,
          home: Builder(builder: destination.build),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: destination.id);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      session.dispose();
    });
  }
  testWidgets('gallery state selector opens isolated empty screen', (
    tester,
  ) async {
    final session = Session(PreviewApi(PreviewState.populated))..ready = true;
    await tester.pumpWidget(
      CoolvibesApp(session: session, home: const DebugGallery()),
    );
    await tester.pump();
    expect(find.textContaining('Ekran kataloğu'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<PreviewState>), findsOneWidget);
  });
}
