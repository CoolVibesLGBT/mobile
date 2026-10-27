// Port of the existing Coolvibes/tweb mesh algorithm; GPL-3.0 attribution is
// preserved in assets/licenses/telegram-background-NOTICE.txt.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

Uint8List wallpaperPixels(List<int> colors, {int phase = 0}) {
  const points = [
    (.8, .1),
    (.6, .2),
    (.35, .25),
    (.25, .6),
    (.2, .9),
    (.4, .8),
    (.65, .75),
    (.75, .4),
  ];
  final pixels = Uint8List(50 * 50 * 4);
  int clamped(double value) {
    final floor = value.floor();
    final fraction = value - floor;
    return (fraction == .5 ? (floor.isEven ? floor : floor + 1) : value.round())
        .clamp(0, 255);
  }

  var offset = 0;
  for (var y = 0; y < 50; y++) {
    final cy = y / 50 - .5;
    for (var x = 0; x < 50; x++) {
      final cx = x / 50 - .5;
      final swirl = .35 * math.sqrt(cx * cx + cy * cy);
      final theta = swirl * swirl * .8 * 8;
      final sin = math.sin(theta), cos = math.cos(theta);
      final px = (.5 + cx * cos - cy * sin).clamp(0, 1),
          py = (.5 + cx * sin + cy * cos).clamp(0, 1);
      double sum = 0, red = 0, green = 0, blue = 0;
      for (var i = 0; i < colors.length; i++) {
        final point = points[(phase + i * 2) % 8];
        final dx = px - point.$1, dy = py - (1 - point.$2);
        var weight = math.max(0.0, .9 - math.sqrt(dx * dx + dy * dy));
        weight = weight * weight * weight * weight;
        sum += weight;
        red += weight * ((colors[i] >> 16) & 255);
        green += weight * ((colors[i] >> 8) & 255);
        blue += weight * (colors[i] & 255);
      }
      pixels[offset++] = clamped(red / sum);
      pixels[offset++] = clamped(green / sum);
      pixels[offset++] = clamped(blue / sum);
      pixels[offset++] = 255;
    }
  }
  return pixels;
}

final _meshes = <String, Future<ui.Image>>{};
Future<ui.Image> wallpaperMesh(List<int> colors, {int phase = 0}) =>
    _meshes.putIfAbsent('$colors:$phase', () async {
      final buffer = await ui.ImmutableBuffer.fromUint8List(
        wallpaperPixels(colors, phase: phase),
      );
      final descriptor = ui.ImageDescriptor.raw(
        buffer,
        width: 50,
        height: 50,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      final codec = await descriptor.instantiateCodec();
      final frame = await codec.getNextFrame();
      codec.dispose();
      descriptor.dispose();
      buffer.dispose();
      return frame.image;
    });
