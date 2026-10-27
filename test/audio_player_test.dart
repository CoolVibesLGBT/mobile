import 'dart:async';
import 'package:audioplayers/audioplayers.dart' show AudioLogger, AudioLogLevel;
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/components/app_button.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/screens/media.dart';
import 'support/ui_driver.dart';

class TestGlobalAudio extends GlobalAudioplayersPlatformInterface {
  @override
  Future<void> init() async {}
  @override
  Future<void> setGlobalAudioContext(AudioContext context) async {}
  @override
  Future<void> emitGlobalLog(String message) async {}
  @override
  Future<void> emitGlobalError(String code, String message) async {}
  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() => const Stream.empty();
}

class AudioPlatform {
  static const channel = MethodChannel('xyz.luan/audioplayers');
  final calls = <MethodCall>[];
  final channels = <String>[];
  final failures = <String>{};
  Completer<void>? preparation;
  String? playerId;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void install() {
    for (final name in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(name),
        (_) async => null,
      );
      channels.add(name);
    }
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      final id = (call.arguments as Map)['playerId'] as String;
      if (call.method == 'create') {
        playerId = id;
        final events = 'xyz.luan/audioplayers/events/$id';
        messenger.setMockMethodCallHandler(
          MethodChannel(events),
          (_) async => null,
        );
        channels.add(events);
      }
      if (call.method == 'setSourceUrl') {
        await preparation?.future;
        emit(id, failed: failures.contains(call.method));
      }
      if (call.method == 'seek') emit(id, event: 'audio.onSeekComplete');
      if (failures.contains(call.method)) {
        throw PlatformException(
          code: 'DarwinAudioError',
          message: 'Failed to set playerItem',
        );
      }
      if (call.method == 'getDuration') return 3000;
      if (call.method == 'getCurrentPosition') return 0;
      return null;
    });
  }

  void emit(
    String id, {
    bool failed = false,
    String event = 'audio.onPrepared',
  }) {
    TestWidgetsFlutterBinding.instance.channelBuffers.push(
      'xyz.luan/audioplayers/events/$id',
      failed
          ? const StandardMethodCodec().encodeErrorEnvelope(
              code: 'DarwinAudioError',
              message: 'Failed to set playerItem',
            )
          : const StandardMethodCodec().encodeSuccessEnvelope({
              'event': event,
              'value': true,
            }),
      (_) {},
    );
  }

  int count(String method) =>
      calls.where((call) => call.method == method).length;
  void dispose() {
    messenger.setMockMethodCallHandler(channel, null);
    for (final name in channels) {
      messenger.setMockMethodCallHandler(MethodChannel(name), null);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AudioLogger.logLevel = AudioLogLevel.none;
  late AudioPlatform platform;
  late Session session;
  setUp(() {
    GlobalAudioplayersPlatformInterface.instance = TestGlobalAudio();
    platform = AudioPlatform()..install();
    session = Session(PreviewApi(PreviewState.empty), persistPreferences: false)
      ..ready = true;
  });
  tearDown(() {
    platform.dispose();
    session.dispose();
  });
  Future<void> mount(WidgetTester tester, {bool voice = false}) async {
    await tester.pumpWidget(
      CoolvibesApp(
        session: session,
        home: Scaffold(
          body: Center(
            child: AudioMediaPlayer(
              item: const {
                'url': 'https://example.org/voice.m4a',
                'mime_type': 'audio/mp4',
              },
              voice: voice
                  ? const VoiceBubbleStyle(
                      active: Colors.blue,
                      inactive: Colors.grey,
                      glyph: Colors.white,
                      duration: Colors.black,
                      maxWidth: 300,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
    await pumpNativeFrames(tester);
  }

  Future<void> release(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await pumpNativeFrames(tester);
    // Broadcast cancellation can complete outside the fake animation clock.
    for (var i = 0; i < 10 && platform.count('dispose') == 0; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await pumpNativeFrames(tester);
    }
  }

  Finder play() => find
      .byWidgetPredicate(
        (widget) => widget is AppIconButton && widget.onPressed != null,
      )
      .first;

  testWidgets('Darwin source and stream errors are handled; retry plays', (
    tester,
  ) async {
    platform.failures.add('setSourceUrl');
    await mount(tester);
    await tester.tap(play());
    await pumpUI(tester);
    expect(platform.count('resume'), 0);
    expect(find.text('Ses oynatılamadı'), findsOneWidget);
    expect(tester.takeException(), isNull);
    platform.failures.clear();
    await tester.tap(play());
    await pumpNativeFrames(tester);
    expect(platform.count('setSourceUrl'), 2);
    expect(platform.count('resume'), 1);
    expect(find.text('Ses oynatılamadı'), findsNothing);
    platform.emit(platform.playerId!, failed: true);
    await pumpNativeFrames(tester);
    expect(find.text('Ses oynatılamadı'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await release(tester);
    expect(platform.count('dispose'), 1);
  });

  testWidgets(
    'metadata probe and play share preparation; leaving never resumes a disposed player',
    (tester) async {
      platform.preparation = Completer<void>();
      await mount(tester, voice: true);
      expect(platform.count('setSourceUrl'), 1);
      await tester.tap(find.bySemanticsLabel('Oynat'));
      await pumpNativeFrames(tester);
      expect(platform.count('setSourceUrl'), 1);
      await tester.pumpWidget(const SizedBox());
      platform.preparation!.complete();
      await pumpUI(tester);
      await release(tester);
      expect(platform.count('resume'), 0);
      expect(platform.count('dispose'), 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'seek, lifecycle and position failures do not escape their futures',
    (tester) async {
      await mount(tester);
      await tester.tap(play());
      await pumpNativeFrames(tester);
      platform.failures.add('seek');
      tester.widget<Slider>(find.byType(Slider)).onChanged!(1500);
      await pumpNativeFrames(tester);
      expect(tester.takeException(), isNull);
      platform.failures.clear();
      await tester.tap(play());
      await pumpNativeFrames(tester);
      platform.failures.add('getCurrentPosition');
      await pumpUI(tester);
      expect(tester.takeException(), isNull);
      platform.failures.add('pause');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await pumpNativeFrames(tester);
      expect(tester.takeException(), isNull);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await release(tester);
    },
  );
}
