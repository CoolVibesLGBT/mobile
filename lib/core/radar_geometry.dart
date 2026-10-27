import 'dart:math' as math;
import 'dart:ui';

/// Exact constants and axial spiral from the source Match/index.tsx.
abstract final class RadarGeometry {
  static const hexSize = 100.0;
  static const itemSize = 90.0;
  static const photoSize = 78.0;
  static const directions = [
    (1, 0),
    (1, -1),
    (0, -1),
    (-1, 0),
    (-1, 1),
    (0, 1),
  ];
  static Iterable<(int, int)> spiral() sync* {
    yield (0, 0);
    for (var radius = 1; ; radius++) {
      var q = -radius, r = radius;
      for (final direction in directions) {
        for (var step = 0; step < radius; step++) {
          yield (q, r);
          q += direction.$1;
          r += direction.$2;
        }
      }
    }
  }

  static Offset position(int q, int r) => Offset(
    hexSize * (math.sqrt(3) * q + math.sqrt(3) / 2 * r),
    hexSize * 1.5 * r,
  );
  static double scale(double distance) => distance <= 100
      ? 1.8 - .8 * (distance.clamp(0, 100) / 100)
      : 1 - .6 * ((distance - 100).clamp(0, 350) / 350);
  static double opacity(double distance) => distance <= 220
      ? 1 - .1 * (distance / 220)
      : .9 - .85 * ((distance - 220).clamp(0, 280) / 280);
  static Offset nearest(List<Offset> positions, Offset pan, Offset velocity) {
    final predicted = pan + velocity * .12;
    var nearest = Offset.zero;
    var distance = double.infinity;
    for (final position in positions) {
      final d = (position + predicted).distanceSquared;
      if (d < distance) {
        nearest = position;
        distance = d;
      }
    }
    return -nearest;
  }
}
