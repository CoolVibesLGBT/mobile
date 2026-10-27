import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/screens/media.dart';
import 'package:coolvibes/vendor/liquid_glass_widgets/liquid_glass_widgets.dart'
    as liquid;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('AUDIO_SMOKE_URL');
  testWidgets(
    'authorized voice note plays with AVPlayer and cleans up on exit',
    (tester) async {
      await liquid.LiquidGlassWidgets.initialize(
        enablePerformanceMonitor: false,
      );
      final api = Api();
      await api.restore();
      expect(
        api.mediaHeaders(url),
        isNotNull,
        reason: 'Requires an existing authorized simulator session.',
      );
      final session = Session(api, persistPreferences: false)..ready = true;
      await tester.pumpWidget(
        CoolvibesApp(
          session: session,
          home: Scaffold(
            body: Center(
              child: AudioMediaPlayer(
                item: const {'url': url, 'mime_type': 'audio/mp4'},
                voice: const VoiceBubbleStyle(
                  active: Colors.blue,
                  inactive: Colors.grey,
                  glyph: Colors.white,
                  duration: Colors.black,
                  maxWidth: 300,
                ),
              ),
            ),
          ),
        ),
      );
      final dynamic state = tester.state(find.byType(AudioMediaPlayer));
      Future<void> waitFor(bool Function() ready) async {
        for (var i = 0; i < 60 && !ready(); i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump();
        }
        expect(ready(), isTrue);
        expect(tester.takeException(), isNull);
      }

      await waitFor(() => state.loaded as bool);
      expect(state.duration, greaterThan(Duration.zero));
      expect(state.player.source, isA<DeviceFileSource>());
      final file = File((state.player.source as DeviceFileSource).path);
      await tester.tap(find.bySemanticsLabel('Oynat'));
      await waitFor(() => state.playing as bool);
      await waitFor(() => (state.position as Duration) > Duration.zero);
      await tester.tap(find.bySemanticsLabel('Duraklat'));
      await waitFor(() => !(state.playing as bool));
      expect(state.error, isNull);
      await tester.pumpWidget(const SizedBox());
      await waitFor(() => !file.existsSync());
      session.dispose();
      api.dio.close();
    },
    skip: url.isEmpty,
  );
}
