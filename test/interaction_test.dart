import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/components/app_pressable.dart';

void main() {
  testWidgets(
    'press down, release, cancellation and disabled follow one contract',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: AppPressable(
              label: 'Test',
              onPressed: () => taps++,
              child: const Text('Action'),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Action')),
      );
      await tester.pump();
      expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, .5);
      await gesture.up();
      await tester.pump();
      expect(taps, 1);
      final cancelled = await tester.startGesture(
        tester.getCenter(find.text('Action')),
      );
      await tester.pump();
      await cancelled.cancel();
      await tester.pump();
      expect(taps, 1);
      expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, 1);
      await tester.pumpWidget(
        const MaterialApp(
          home: AppPressable(
            label: 'Disabled',
            onPressed: null,
            child: Text('Disabled'),
          ),
        ),
      );
      await tester.tap(find.text('Disabled'));
      await tester.pump();
      expect(taps, 1);
    },
  );
  testWidgets('Reduce Motion removes release animation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: AppPressable(
            label: 'Test',
            style: AppPressStyle.touchable,
            onPressed: () {},
            child: const Text('Action'),
          ),
        ),
      ),
    );
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).duration,
      Duration.zero,
    );
  });
  testWidgets('disabled flag blocks tap and long-press callbacks', (
    tester,
  ) async {
    var taps = 0;
    var holds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: AppPressable(
            enabled: false,
            label: 'Unavailable',
            onPressed: () => taps++,
            onLongPressStart: (_) => holds++,
            child: const Text('Action'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Action'));
    await tester.longPress(find.text('Action'));
    expect(taps, 0);
    expect(holds, 0);
  });

  for (final style in [
    AppPressStyle.button,
    AppPressStyle.iconButton,
    AppPressStyle.tag,
    AppPressStyle.radar,
  ]) {
    testWidgets('Reduce Motion keeps $style stationary while pressed', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Center(
              child: AppPressable(
                label: 'Action',
                style: style,
                onPressed: () {},
                child: const Text('Action'),
              ),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Action')),
      );
      await tester.pump();
      final transform = tester.widget<Transform>(
        find.descendant(
          of: find.byType(AppPressable),
          matching: find.byType(Transform),
        ),
      );
      expect(transform.transform, Matrix4.identity());
      await gesture.cancel();
    });
  }

  testWidgets('backgrounding clears a pressed control', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: AppPressable(
            label: 'Action',
            onPressed: () {},
            child: const Text('Action'),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Action')),
    );
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await gesture.cancel();
  });
}
