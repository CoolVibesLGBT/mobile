import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Looping production Lotties never settle. Pump bounded native frames so an
/// assertion, rather than an endless animation, determines a test's outcome.
Future<void> pumpUI(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> pumpNativeFrames(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> waitForUI(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 50 && finder.evaluate().isEmpty; i++) {
    if (const bool.fromEnvironment('NATIVE_HOST_TOUCH')) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsWidgets);
}

/// UIKit controls need actual OS touches; tester.tap only synthesizes Flutter
/// pointer events. Run these tests with scripts/test-native-touch.py.
Future<void> nativeTap(WidgetTester tester, Finder finder) async {
  await nativeTouch(tester, tester.getCenter(finder));
}

Future<void> nativeTouch(
  WidgetTester tester,
  Offset start, [
  Offset? end,
]) async {
  if (!const bool.fromEnvironment('NATIVE_HOST_TOUCH')) {
    throw StateError(
      'Run scripts/test-native-touch.py for real UIKit touches.',
    );
  }
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  final points = [
    start.dx / size.width,
    start.dy / size.height,
    if (end != null) ...[end.dx / size.width, end.dy / size.height],
  ];
  await tester.runAsync(() async {
    final acknowledgement = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    try {
      debugPrint(
        'COOLVIBES_TOUCH ${points.join(' ')} ACK:${acknowledgement.port}',
      );
      final delivered = await acknowledgement.first.timeout(
        const Duration(seconds: 15),
      );
      delivered.response.statusCode = HttpStatus.noContent;
      await delivered.response.close();
    } finally {
      await acknowledgement.close(force: true);
    }
  });
  await pumpUI(tester);
}

/// Shared fixtures use Flutter events in widget tests and OS events on iOS.
Future<void> tapUI(WidgetTester tester, Finder finder) =>
    const bool.fromEnvironment('NATIVE_HOST_TOUCH')
    ? nativeTap(tester, finder)
    : tester.tap(finder);
