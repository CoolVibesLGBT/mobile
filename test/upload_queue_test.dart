import 'dart:async';
import 'dart:convert';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/core/upload_queue.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryStorage extends FlutterSecureStorage {
  final values = <String, String>{};
  int writes = 0;
  int? failWrite, holdWrite;
  final receiptGate = Completer<void>();
  Future<String?> Function(String)? readValue;
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => readValue != null ? await readValue!(key) : values[key];
  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    final number = ++writes;
    if (number == failWrite) throw StateError('Storage unavailable');
    if (number == holdWrite) await receiptGate.future;
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

class QueueApi extends Api {
  int calls = 0;
  Completer<Json>? response;
  QueueApi(MemoryStorage storage) : super(secureStorage: storage) {
    token = 'Bearer test';
  }
  @override
  Future<Json> call(
    String action, {
    Json body = const {},
    bool get = false,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    Duration? receiveTimeout,
  }) async {
    calls++;
    return response != null ? await response!.future : {'id': 'accepted'};
  }
}

Future<void> drain() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('a failed enqueue is removed and never sent', () async {
    final storage = MemoryStorage()..failWrite = 1;
    final api = QueueApi(storage);
    final queue = UploadQueue(api);
    addTearDown(queue.dispose);
    await queue.attach('a');
    await expectLater(
      queue.enqueue(action: 'post.create', title: 'Post', fields: {}),
      throwsStateError,
    );
    await drain();
    expect(queue.jobs, isEmpty);
    expect(api.calls, 0);
  });

  test('delivery completion waits for the durable server receipt', () async {
    final storage = MemoryStorage()..holdWrite = 3;
    final api = QueueApi(storage);
    final queue = UploadQueue(api);
    addTearDown(queue.dispose);
    await queue.attach('a');
    final job = await queue.enqueue(
      action: 'post.create',
      title: 'Post',
      fields: {},
    );
    var completed = false;
    final receipt = queue.waitFor(job).then((result) {
      completed = true;
      return result;
    });
    await drain();
    expect(storage.writes, 3);
    expect(completed, isFalse);
    var secondCompleted = false;
    final second = queue.waitFor(job).then((_) => secondCompleted = true);
    await drain();
    expect(secondCompleted, isFalse);
    storage.receiptGate.complete();
    expect(await receipt, {'id': 'accepted'});
    await second;
    final restored = UploadJob.fromJson(
      object(
        (jsonDecode(storage.values['coolvibes.outbox.a']!) as List).single,
      ),
    );
    expect(restored.status, 'done');
    expect(restored.result, {'id': 'accepted'});
  });

  test(
    'receipt storage failure never retries an accepted submission',
    () async {
      final storage = MemoryStorage()..failWrite = 3;
      final api = QueueApi(storage);
      final queue = UploadQueue(api);
      await queue.attach('a');
      final job = await queue.enqueue(
        action: 'post.create',
        title: 'Post',
        fields: {},
      );
      expect(await queue.waitFor(job), {'id': 'accepted'});
      expect(job.status, 'done');
      expect(job.error, contains('Delivered'));
      await queue.retry(job);
      expect(api.calls, 1);
      queue.dispose();
      final restored = UploadQueue(api);
      addTearDown(restored.dispose);
      await restored.attach('a');
      await drain();
      expect(restored.jobs.single.status, 'failed');
      expect(restored.jobs.single.error, contains('could not be confirmed'));
      expect(api.calls, 1);
    },
  );

  test('same client id resolves to one pending operation', () async {
    final storage = MemoryStorage();
    final api = QueueApi(storage)..response = Completer<Json>();
    final queue = UploadQueue(api);
    addTearDown(queue.dispose);
    await queue.attach('a');
    final jobs = await Future.wait([
      queue.enqueue(
        action: 'chat.send_message',
        title: 'Message',
        fields: {},
        clientId: 'stable-id',
      ),
      queue.enqueue(
        action: 'chat.send_message',
        title: 'Message',
        fields: {},
        clientId: 'stable-id',
      ),
    ]);
    expect(identical(jobs.first, jobs.last), isTrue);
    expect(queue.jobs.length, 1);
    api.response!.complete({'id': 'accepted'});
    await queue.waitFor(jobs.first);
    expect(api.calls, 1);
  });

  test('A to B to A ignores the first stale account restore', () async {
    final storage = MemoryStorage();
    final staleRead = Completer<String?>();
    var reads = 0;
    storage.readValue = (key) async {
      if (++reads == 1) return staleRead.future;
      return null;
    };
    final queue = UploadQueue(QueueApi(storage));
    addTearDown(queue.dispose);
    final firstAttach = queue.attach('a');
    await queue.attach('b');
    await queue.attach('a');
    staleRead.complete(
      jsonEncode([
        UploadJob(
          id: 'stale',
          owner: 'a',
          action: 'post.create',
          title: 'Post',
          fields: {},
        ).toJson(),
      ]),
    );
    await firstAttach;
    expect(queue.owner, 'a');
    expect(queue.jobs, isEmpty);
  });
}
