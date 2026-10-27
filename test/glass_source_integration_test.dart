import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/components/app_button.dart';
import 'package:coolvibes/components/glass_surface.dart';
import 'package:coolvibes/vendor/liquid_glass_widgets/liquid_glass_widgets.dart'
    as liquid;

void main() {
  testWidgets('vendored shaders preload and shared controls dispatch once', (
    tester,
  ) async {
    await liquid.LiquidGlassWidgets.initialize(enablePerformanceMonitor: false);
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: GlassSurface(
              child: AppIconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Add',
                onPressed: () => taps++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The surface is a GlassContainer; every button is the vendored
    // GlassButton.
    expect(find.byType(liquid.GlassContainer), findsOneWidget);
    expect(find.byType(liquid.GlassButton), findsOneWidget);
    final material = tester.widget<liquid.GlassContainer>(
      find.byType(liquid.GlassContainer),
    );
    expect(material.settings!.lightIntensity, greaterThan(0));
    expect(material.settings!.fresnelStrength, greaterThan(0));
    expect(tester.takeException(), isNull);
    await tester.tap(find.bySemanticsLabel('Add'));
    await tester.pumpAndSettle();
    expect(taps, 1);
    final gesture = await tester.startGesture(
      tester.getCenter(find.bySemanticsLabel('Add')),
    );
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('accessible glass and disabled controls preserve layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            highContrast: true,
            disableAnimations: true,
            textScaler: TextScaler.linear(2),
          ),
          child: const Scaffold(
            body: Center(
              child: AppButton(onPressed: null, child: Text('Continue')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    expect(tester.takeException(), isNull);
    expect(find.byType(liquid.GlassButton), findsOneWidget);
  });
}
