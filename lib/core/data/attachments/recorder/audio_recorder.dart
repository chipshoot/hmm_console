import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// A finished recording, held until the note is saved (then persisted to the
/// vault via the existing file path).
class AudioRecording {
  AudioRecording({
    required this.bytes,
    required this.fileName,
    this.contentType = 'audio/mp4',
  });
  final Uint8List bytes;
  final String fileName;
  final String contentType;
}

/// Microphone recorder seam. Overridable in tests.
abstract interface class AudioRecorderService {
  Future<bool> hasPermission();
  Future<void> start();

  /// Stop and return the recording (null if nothing was captured).
  Future<AudioRecording?> stop();

  /// Stop and discard (delete the temp file).
  Future<void> cancel();

  /// Release native recorder resources (called when the provider is disposed).
  Future<void> dispose();
}

class RecordAudioRecorderService implements AudioRecorderService {
  final AudioRecorder _rec = AudioRecorder();
  String? _path;

  @override
  Future<bool> hasPermission() => _rec.hasPermission();

  @override
  Future<void> start() async {
    final dir = await getTemporaryDirectory();
    final path =
        p.join(dir.path, 'rec-${DateTime.now().millisecondsSinceEpoch}.m4a');
    await _rec.start(const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path);
    _path = path;
  }

  @override
  Future<AudioRecording?> stop() async {
    final path = await _rec.stop();
    _path = null;
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    return AudioRecording(bytes: bytes, fileName: p.basename(path));
  }

  @override
  Future<void> cancel() async {
    await _rec.stop();
    final path = _path;
    _path = null;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  @override
  Future<void> dispose() => _rec.dispose();
}

final audioRecorderProvider = Provider<AudioRecorderService>((ref) {
  final service = RecordAudioRecorderService();
  ref.onDispose(service.dispose);
  return service;
});
