import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/core/audio_source.dart';

class AudioAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int status = 200;
  Completer<void>? hold;
  Future<void>? cancelled;
  void Function()? received;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    cancelled = cancelFuture;
    received?.call();
    await hold?.future;
    return ResponseBody.fromBytes([1, 2, 3, 4], status);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  final url = '${Api.endpoints.api.origin}/static/uploads/users/test/voice.m4a';
  late Directory root;
  late AudioAdapter adapter;
  late Api api;
  late AudioSourceLoader loader;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('coolvibes-audio-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => root.path);
    adapter = AudioAdapter();
    api = Api(client: Dio()..httpClientAdapter = adapter)..token = 'test-token';
    loader = AudioSourceLoader(api: api, url: url, mimeType: 'audio/mp4');
  });
  tearDown(() async {
    await loader.dispose();
    api.dio.close(force: true);
    await root.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'private audio uses authorized local file and deletes only its copy',
    () async {
      final original = File('${root.path}/original.m4a');
      await original.writeAsBytes([9, 8]);
      final result = await Future.wait([loader.load(), loader.load()]);
      expect(adapter.requests, hasLength(1));
      final request = adapter.requests.single;
      expect(request.headers['Authorization'], 'Bearer test-token');
      expect(request.followRedirects, isFalse);
      final source = result.first as DeviceFileSource;
      expect(source.mimeType, 'audio/mp4');
      expect(source.path.endsWith('.m4a'), isTrue);
      expect(await File(source.path).readAsBytes(), [1, 2, 3, 4]);
      expect((result.last as DeviceFileSource).path, source.path);
      await loader.dispose();
      expect(await File(source.path).exists(), isFalse);
      expect(await original.readAsBytes(), [9, 8]);
    },
  );

  test(
    '404 and redirects fail without anonymous fallback and can retry',
    () async {
      for (final status in [404, 302]) {
        adapter.status = status;
        await expectLater(loader.load(), throwsA(isA<DioException>()));
        expect(await root.list().toList(), isEmpty);
      }
      adapter.status = 200;
      expect(await loader.load(), isA<DeviceFileSource>());
      expect(adapter.requests, hasLength(3));
    },
  );

  test('dispose cancels pending download and removes partial files', () async {
    adapter.hold = Completer<void>();
    final started = Completer<void>();
    adapter.received = started.complete;
    final result = expectLater(loader.load(), throwsA(anything));
    await started.future;
    final disposed = loader.dispose();
    await adapter.cancelled;
    adapter.hold!.complete();
    await result;
    await disposed;
    expect(await root.list().toList(), isEmpty);
  });

  test(
    'an account change during download invalidates the private copy',
    () async {
      adapter.received = () => api.token = 'different-account';
      await expectLater(loader.load(), throwsStateError);
      expect(await root.list().toList(), isEmpty);
    },
  );

  test(
    'external audio never receives API authorization and local recordings stay owned by outbox',
    () async {
      final external = AudioSourceLoader(
        api: api,
        url: 'https://example.org/voice.mp3',
      );
      final local = AudioSourceLoader(
        api: api,
        url: '',
        localPath: '${root.path}/recording.m4a',
      );
      await File(local.localPath).writeAsBytes([1]);
      expect(await external.load(), isA<UrlSource>());
      expect(await local.load(), isA<DeviceFileSource>());
      expect(adapter.requests, isEmpty);
      await external.dispose();
      await local.dispose();
      expect(await File(local.localPath).exists(), isTrue);
    },
  );
}
