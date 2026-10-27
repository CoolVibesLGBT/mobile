import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'api.dart';

class AttachmentController extends ChangeNotifier {
  final files = <Json>[];
  Json? location, emoticon;
  bool recording = false, disposed = false;

  /// Telegram "Hide with spoiler" for the next send.
  bool spoiler = false;
  AudioRecorder? _recorder;
  String? _recordingPath;
  Timer? _timer;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  final amplitudes = <double>[];

  /// Every metered level of the current recording (the sent waveform);
  /// [amplitudes] keeps only the live bar's last 40.
  final levels = <double>[];
  Future<void>? _recordingTransition;
  int seconds = 0;
  bool get hasContent =>
      files.isNotEmpty || location != null || emoticon != null;
  void changed() {
    if (!disposed) notifyListeners();
  }

  static Future<Directory> directory() async {
    final root = await getApplicationSupportDirectory();
    return Directory('${root.path}/outbox').create(recursive: true);
  }

  static String mime(String name) {
    final ext = name.toLowerCase().split('.').last;
    return {
          'jpg': 'image/jpeg',
          'jpeg': 'image/jpeg',
          'png': 'image/png',
          'webp': 'image/webp',
          'gif': 'image/gif',
          'heic': 'image/heic',
          'mp4': 'video/mp4',
          'mov': 'video/quicktime',
          'm4a': 'audio/mp4',
          'mp3': 'audio/mpeg',
          'wav': 'audio/wav',
          'pdf': 'application/pdf',
          'txt': 'text/plain',
          'zip': 'application/zip',
        }[ext] ??
        'application/octet-stream';
  }

  Future<void> addFile(String path, {String? name, String? contentType}) async {
    final original = File(path);
    final filename = name ?? path.split('/').last;
    final root = await directory();
    final target =
        '${root.path}/${DateTime.now().microsecondsSinceEpoch}-${filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')}';
    final copy = await original.copy(target);
    final type = contentType ?? mime(filename);
    if (disposed) return;
    files.add({
      'path': copy.path,
      'name': filename,
      'mime': type,
      'size': await copy.length(),
      'field': type.startsWith('video/') ? 'videos[]' : 'images[]',
    });
    changed();
  }

  Future<void> pickImages({bool camera = false}) async {
    final picker = ImagePicker();
    final result = camera
        ? [await picker.pickImage(source: ImageSource.camera)]
        : await picker.pickMultiImage();
    for (final image in result.whereType<XFile>()) {
      await addFile(image.path, name: image.name);
    }
  }

  Future<void> pickVideo({bool camera = false}) async {
    final video = await ImagePicker().pickVideo(
      source: camera ? ImageSource.camera : ImageSource.gallery,
    );
    if (video != null) await addFile(video.path, name: video.name);
  }

  Future<void> pickDocuments() async {
    final result = await FilePicker.pickFiles();
    for (final file in result) {
      if (file.path != null) await addFile(file.path!, name: file.name);
    }
  }

  Future<void> startRecording() {
    if (disposed || recording) return Future.value();
    return _recordingTransition ??= _startRecording().whenComplete(
      () => _recordingTransition = null,
    );
  }

  Future<void> _startRecording() async {
    final recorder = _recorder ??= AudioRecorder();
    if (!await recorder.hasPermission()) {
      throw ApiException('Microphone permission is required');
    }
    if (disposed) return;
    final root = await directory();
    if (disposed) return;
    _recordingPath =
        '${root.path}/voice-${DateTime.now().microsecondsSinceEpoch}.m4a';
    await recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _recordingPath!,
    );
    if (disposed) {
      final path = await recorder.stop();
      if (path != null && await File(path).exists()) await File(path).delete();
      return;
    }
    seconds = 0;
    amplitudes.clear();
    levels.clear();
    recording = true;
    _amplitudeSubscription = recorder
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen(
          (value) {
            if (!recording || disposed) return;
            final level = math
                .pow(10, value.current / 40)
                .toDouble()
                .clamp(0.0, 1.0);
            amplitudes.add(level);
            levels.add(level);
            if (amplitudes.length > 40) amplitudes.removeAt(0);
            changed();
          },
          onError: (Object error) {
            /* Recording remains usable without metering. */
          },
        );
    changed();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      seconds++;
      changed();
    });
  }

  Future<void> stopRecording({bool cancel = false}) async {
    await _recordingTransition;
    if (!recording) return;
    // Clear the state before awaiting the platform; stop/send/cancel may race.
    recording = false;
    _timer?.cancel();
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    try {
      final path = await _recorder!.stop();
      if (path != null && !cancel && !disposed) {
        files.add({
          'path': path,
          'name': 'Voice message.m4a',
          'mime': 'audio/mp4',
          'size': await File(path).length(),
          'field': 'images[]',
          'duration': seconds,
          'waveform': List<double>.of(levels),
        });
      } else if (path != null) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    } finally {
      changed();
    }
  }

  void remove(Json file) {
    files.remove(file);
    changed();
  }

  void clear() {
    files.clear();
    location = null;
    emoticon = null;
    spoiler = false;
    changed();
  }

  Json extraFields() => {
    if (location != null) ...{
      'location[lat]': location!['latitude'],
      'location[lng]': location!['longitude'],
      'location[address]': location!['address'] ?? '',
    },
    if (emoticon != null || spoiler)
      'extras': {
        if (emoticon != null) 'emoticon': emoticon,
        if (spoiler) 'spoiler': true,
      },
  };
  @override
  void dispose() {
    disposed = true;
    _timer?.cancel();
    _amplitudeSubscription?.cancel();
    // An in-flight permission/start operation checks disposed before recording.
    final pending = _recordingTransition;
    if (pending != null) {
      pending.whenComplete(() => _recorder?.dispose()).ignore();
    } else {
      _recorder?.dispose();
    }
    super.dispose();
  }
}
