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
}
