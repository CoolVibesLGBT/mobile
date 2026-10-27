import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/core/radar_geometry.dart';
import 'package:coolvibes/core/wallpaper_mesh.dart';

void main() {
  test('same first axial spiral cells as React Native source', () {
    expect(RadarGeometry.spiral().take(7).toList(), [
      (0, 0),
      (-1, 1),
      (0, 1),
      (1, 0),
      (1, -1),
      (0, -1),
      (-1, 0),
    ]);
    expect(RadarGeometry.spiral().take(127).toSet().length, 127);
  });
  test('bubble and focus dimensions preserve source interpolation', () {
    expect(RadarGeometry.scale(0), 1.8);
    expect(RadarGeometry.scale(100), 1);
    expect(RadarGeometry.scale(450), closeTo(.4, 1e-12));
    expect(RadarGeometry.opacity(500), closeTo(.05, 1e-12));
    expect(RadarGeometry.itemSize, 90);
    expect(RadarGeometry.photoSize, 78);
  });
  test('flick prediction snaps to the same hex with .12 second lookahead', () {
    final positions = [
      Offset.zero,
      RadarGeometry.position(1, 0),
      RadarGeometry.position(-1, 0),
    ];
    expect(
      RadarGeometry.nearest(
        positions,
        const Offset(-40, 0),
        const Offset(-1200, 0),
      ),
      -positions[1],
    );
  });
  for (final phase in [0, 3]) {
    test('mesh phase $phase matches all 10000 bytes from original JS', () {
      final expected = File(
        'test/fixtures/source-wallpaper-phase-$phase.rgba',
      ).readAsBytesSync();
      expect(
        wallpaperPixels([0xdbddbb, 0x6ba587, 0xd5d88d, 0x88b884], phase: phase),
        expected,
      );
    });
  }
}
