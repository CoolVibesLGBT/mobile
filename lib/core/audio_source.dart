import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'api.dart';

/// A playback-scoped copy of protected media. AVPlayer's URL source cannot
/// attach our API authorization header; private files must be fetched first.
class AudioSourceLoader {
  final Api? api;
  final String url, localPath;
  final String? mimeType;
  final _cancel = CancelToken();
  Directory? _directory;
  Future<Source>? _pending;
  bool _disposed = false;

  AudioSourceLoader({
    required this.url,
    this.api,
    this.localPath = '',
    this.mimeType,
  });

  Future<Source> load() async {
    final pending = _pending ??= _load();
    try {
      return await pending;
    } catch (_) {
      if (identical(_pending, pending)) _pending = null;
      rethrow;
    }
  }

  Future<Source> _load() async {
    _checkActive();
    if (localPath.isNotEmpty) {
      return DeviceFileSource(localPath, mimeType: mimeType);
    }
    final headers = api?.mediaHeaders(url);
    if (headers == null) return UrlSource(url, mimeType: mimeType);
    final token = api!.token;
    try {
      final root = await getTemporaryDirectory();
      _checkActive();
      final directory = _directory = await root.createTemp('coolvibes-audio-');
      _checkActive();
      final extension = Uri.parse(url).path.split('.').last.toLowerCase();
      final suffix = RegExp(r'^[a-z0-9]{1,5}$').hasMatch(extension)
          ? extension
          : 'm4a';
      final file = File('${directory.path}/audio.$suffix');
      await api!.dio.download(
        url,
        file.path,
        cancelToken: _cancel,
        options: Options(
          headers: headers,
          followRedirects: false,
          validateStatus: (status) => status == 200,
        ),
      );
      _checkActive();
      if (api!.token != token) throw StateError('Audio session changed');
      if (await file.length() == 0) throw StateError('Empty audio response');
      return DeviceFileSource(file.path, mimeType: mimeType);
    } catch (_) {
      await _deleteCopy();
      rethrow;
    }
  }

  void _checkActive() {
    if (_disposed) throw StateError('Audio source disposed');
  }

  void cancel() {
    _disposed = true;
    _cancel.cancel();
  }

  Future<void> _deleteCopy() async {
    final directory = _directory;
    _directory = null;
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<void> dispose() async {
    cancel();
    try {
      await _pending;
    } catch (_) {
      // Cancellation and failed downloads still need their temporary cleanup.
    }
    await _deleteCopy();
  }
}
