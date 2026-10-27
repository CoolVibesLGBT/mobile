import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api.dart';

class UploadJob {
  final String id, owner, action, title;
  final Json fields;
  final List<Json> files;
  String status;
  String? error;
  double progress;
  Json? result;
  bool receiptPending = false;
  UploadJob({
    required this.id,
    required this.owner,
    required this.action,
    required this.title,
    required this.fields,
    this.files = const [],
    this.status = 'queued',
    this.error,
    this.progress = 0,
    this.result,
  });
  Json toJson() => {
    'id': id,
    'owner': owner,
    'action': action,
    'title': title,
    'fields': fields,
    'files': files,
    // An interrupted request may already have reached the server. Never replay
    // it automatically without a server-side idempotency guarantee.
    'status': status == 'sending' ? 'failed' : status,
    'error': status == 'sending'
        ? 'Delivery could not be confirmed. Check before retrying.'
        : error,
    if (result != null) 'result': result,
  };
  factory UploadJob.fromJson(Json data) => UploadJob(
    id: string(data['id']),
    owner: string(data['owner']),
    action: string(data['action']),
    title: string(data['title']),
    fields: object(data['fields']),
    files: (data['files'] as List? ?? []).map(object).toList(),
    status: string(data['status']),
    error: data['error'] as String?,
    result: data['result'] is Map ? object(data['result']) : null,
  );
}

/// Persists retryable metadata, rebuilds multipart streams for every attempt and
/// never sends one account's pending work under another account's token.
class UploadQueue extends ChangeNotifier {
  final _waiters = <UploadJob, Completer<Json>>{};
  Future<Json> waitFor(UploadJob job) {
    if (disposed || job.owner != owner || !jobs.contains(job)) {
      return Future.error(ApiException('Submission cancelled'));
    }
    if (job.status == 'done' && !job.receiptPending) {
      return Future.value(job.result ?? {});
    }
    if (job.status == 'failed') {
      return Future.error(ApiException(job.error ?? 'Upload failed'));
    }
    return (_waiters[job] ??= Completer<Json>()).future;
  }

  void cancelWaiters() {
    for (final waiter in _waiters.values) {
      waiter.completeError(ApiException('Session changed'));
    }
    _waiters.clear();
  }

  final Api api;
  final jobs = <UploadJob>[];
  final completed = StreamController<Json>.broadcast();
  String owner = '';
  bool working = false, disposed = false;
  CancelToken? active;
  Future<void> _persistence = Future<void>.value();
  Future<void> _enqueues = Future<void>.value();
  int _sessionVersion = 0;
  UploadQueue(this.api);
  String get _key => 'coolvibes.outbox.$owner';
  Future<void> attach(String nextOwner) async {
    final version = ++_sessionVersion;
    cancelWaiters();
    active?.cancel();
    owner = nextOwner;
    jobs.clear();
    if (owner.isNotEmpty && !api.isPreview) {
      final raw = await api.storage.read(key: _key);
      if (disposed || version != _sessionVersion) return;
      try {
        if (raw != null) {
          jobs.addAll(
            (jsonDecode(raw) as List)
                .map((j) => UploadJob.fromJson(object(j)))
                .where((j) => j.owner == nextOwner),
          );
        }
      } catch (_) {}
    }
    if (!disposed) notifyListeners();
    unawaited(process());
  }

  Future<void> persist() {
    if (api.isPreview || owner.isEmpty) return Future<void>.value();
    final key = _key;
    final value = jsonEncode(jobs.map((j) => j.toJson()).toList());
    final write = _persistence.then(
      (_) => api.storage.write(key: key, value: value),
    );
    _persistence = write.then<void>((_) {}, onError: (Object _) {});
    return write;
  }

  Future<UploadJob> enqueue({
    required String action,
    required String title,
    required Json fields,
    List<Json> files = const [],
    String? clientId,
  }) {
    final version = _sessionVersion;
    final operation = _enqueues.then((_) async {
      if (disposed || owner.isEmpty || version != _sessionVersion) {
        throw ApiException('Authentication required');
      }
      if (clientId != null) {
        final existing = jobs
            .where((j) => j.id == clientId && j.owner == owner)
            .firstOrNull;
        if (existing != null) return existing;
      }
      final job = UploadJob(
        id: clientId ?? 'cv-${DateTime.now().microsecondsSinceEpoch}',
        owner: owner,
        action: action,
        title: title,
        fields: fields,
        files: files,
      );
      jobs.add(job);
      try {
        await persist();
      } catch (_) {
        jobs.remove(job);
        rethrow;
      }
      if (disposed || version != _sessionVersion) {
        throw ApiException('Session changed');
      }
      notifyListeners();
      unawaited(process());
      return job;
    });
    _enqueues = operation.then<void>((_) {}, onError: (Object _) {});
    return operation;
  }

  Future<void> retry(UploadJob job) async {
    if (job.owner != owner || job.status != 'failed' || !jobs.contains(job)) {
      return;
    }
    final previousError = job.error;
    job.status = 'queued';
    job.error = null;
    try {
      await persist();
    } catch (_) {
      job.status = 'failed';
      job.error = previousError;
      rethrow;
    }
    notifyListeners();
    unawaited(process());
  }

  Future<void> remove(UploadJob job) async {
    _waiters.remove(job)?.completeError(ApiException('Submission cancelled'));
    if (job.status == 'sending') active?.cancel();
    jobs.remove(job);
    await persist();
    notifyListeners();
  }

  Future<void> process() async {
    if (working || owner.isEmpty || api.token == null || disposed) return;
    working = true;
    try {
      while (!disposed) {
        final job = jobs
            .where((j) => j.owner == owner && j.status == 'queued')
            .firstOrNull;
        if (job == null) break;
        final version = _sessionVersion;
        final token = api.token;
        final attemptOwner = owner;
        job.status = 'sending';
        job.error = null;
        job.progress = 0;
        active = CancelToken();
        notifyListeners();
        Json? result;
        try {
          await persist();
          final body = <String, dynamic>{...job.fields};
          for (final file in job.files) {
            final key = string(file['field']);
            final values = List<dynamic>.of((body[key] as List?) ?? const []);
            values.add(
              await MultipartFile.fromFile(
                string(file['path']),
                filename: string(file['name']),
                contentType: DioMediaType.parse(
                  string(file['mime']).isEmpty
                      ? 'application/octet-stream'
                      : string(file['mime']),
                ),
              ),
            );
            body[key] = values;
          }
          if (token != api.token ||
              attemptOwner != owner ||
              version != _sessionVersion ||
              !jobs.contains(job)) {
            throw ApiException('Session changed');
          }
          result = await api.call(
            job.action,
            body: body,
            receiveTimeout: Duration.zero,
            cancelToken: active,
            onSendProgress: (sent, total) {
              if (disposed || job.owner != owner) return;
              job.progress = total > 0 ? sent / total : 0;
              notifyListeners();
            },
          );
        } catch (e) {
          if (disposed || version != _sessionVersion) break;
          if (!jobs.contains(job)) continue;
          job.status = 'failed';
          job.error = '$e';
          try {
            await persist();
          } catch (_) {
            // Keep the failure visible and never start an automatic retry loop.
          }
          _waiters.remove(job)?.completeError(e);
          if (!disposed) notifyListeners();
          continue;
        }
        if (disposed || version != _sessionVersion) break;
        if (!jobs.contains(job)) continue;
        job.receiptPending = true;
        job.status = 'done';
        job.result = result;
        job.progress = 1;
        try {
          await persist();
        } catch (_) {
          // The server accepted the request. Do not turn this into a retryable
          // network failure; the durable in-flight record requires manual review.
          job.error = 'Delivered, but the local receipt could not be saved.';
        }
        if (disposed || version != _sessionVersion) break;
        job.receiptPending = false;
        _waiters.remove(job)?.complete(result);
        completed.add({
          'job_id': job.id,
          'action': job.action,
          'fields': job.fields,
          'result': result,
        });
        notifyListeners();
      }
    } finally {
      working = false;
      active = null;
      if (!disposed &&
          jobs.any((j) => j.owner == owner && j.status == 'queued')) {
        scheduleMicrotask(process);
      }
    }
  }

  @override
  void dispose() {
    cancelWaiters();
    disposed = true;
    _sessionVersion++;
    active?.cancel();
    completed.close();
    super.dispose();
  }
}
