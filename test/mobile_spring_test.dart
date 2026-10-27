import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/core/mobile_spring.dart';

void main() {
  final fixtures =
      jsonDecode(File('test/fixtures/mobile-springs.json').readAsStringSync())
          as List;
  for (final fixture in fixtures) {
    test(
      'matches original Reanimated 4 ${fixture['name']} frame positions and velocities',
      () {
        final spring = MobileSpring(
          (fixture['start'] as num).toDouble(),
          (fixture['target'] as num).toDouble(),
          (fixture['velocity'] as num).toDouble(),
          stiffness: (fixture['stiffness'] as num).toDouble(),
          damping: (fixture['damping'] as num).toDouble(),
        );
        for (final frame in fixture['samples']) {
          final t = (frame['t'] as num).toDouble();
          expect(
            spring.x(t),
            closeTo((frame['position'] as num).toDouble(), 1e-8),
          );
          expect(
            spring.dx(t),
            closeTo((frame['velocity'] as num).toDouble(), 1e-8),
          );
        }
        expect(spring.isDone(20), isTrue);
        expect(spring.x(20), fixture['target']);
      },
    );
  }
}
