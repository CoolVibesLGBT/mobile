import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('backend AVIF artwork decodes in the Flutter engine', () async {
    // Real backend static/checkin/256/beach.avif, retained to catch codec regressions.
    final bytes = await File('test/fixtures/checkin-beach.avif').readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    expect(frame.image.width, greaterThan(0));
    frame.image.dispose();
    codec.dispose();
  });
}
