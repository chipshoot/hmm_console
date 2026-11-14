import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Size of one upload chunk. A multiple of 320 KiB, as OneDrive requires.
const kUploadFragmentBytes = 10 * 1024 * 1024;

/// One video waiting to be uploaded, with enough state to resume after a
/// restart.
class VideoUploadEntry {
  const VideoUploadEntry({
    required this.path,
    required this.total,
    this.session,
    this.sent = 0,
    this.mobileOk = false,
  });

  final String path;
  final int total;
  final String? session;
  final int sent;

  /// The user allowed this upload on mobile data.
  final bool mobileOk;

  VideoUploadEntry copyWith({
    String? session,
    bool clearSession = false,
    int? sent,
    bool? mobileOk,
  }) => VideoUploadEntry(
    path: path,
    total: total,
    session: clearSession ? null : (session ?? this.session),
    sent: sent ?? this.sent,
    mobileOk: mobileOk ?? this.mobileOk,
  );

  Map<String, Object?> toJson() => {
    'path': path,
    'total': total,
    'session': session,
    'sent': sent,
    'mobileOk': mobileOk,
  };

  static VideoUploadEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    final path = json['path'];
    final total = json['total'];
    if (path is! String || total is! int) return null;
    final session = json['session'];
    final sent = json['sent'];
    return VideoUploadEntry(
      path: path,
      total: total,
      session: session is String ? session : null,
      sent: sent is int ? sent : 0,
      mobileOk: json['mobileOk'] == true,
    );
  }
}

/// Persists the upload queue per provider, so it survives restarts.
class VideoUploadQueueStore {
  static String _key(String providerId) => 'video_upload_queue:$providerId';

  /// Mutations are read-modify-writes across awaits, so they run one at a
  /// time. Static: separate store instances share one SharedPreferences.
  static Future<void> _tail = Future.value();

  static Future<T> _serialized<T>(Future<T> Function() op) {
    final result = _tail.then((_) => op());
    _tail = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<List<VideoUploadEntry>> read(String providerId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(providerId));
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [for (final e in decoded) ?VideoUploadEntry.fromJson(e)];
    } on FormatException {
      return [];
    }
  }

  Future<void> put(String providerId, VideoUploadEntry e) =>
      _serialized(() => _put(providerId, e));

  Future<void> _put(String providerId, VideoUploadEntry e) async {
    final current = await read(providerId);
    final i = current.indexWhere((x) => x.path == e.path);
    if (i >= 0) {
      current[i] = e;
    } else {
      current.add(e);
    }
    await _write(providerId, current);
  }

  Future<void> remove(String providerId, String path) =>
      _serialized(() => _remove(providerId, path));

  Future<void> _remove(String providerId, String path) async {
    final current = await read(providerId);
    final before = current.length;
    current.removeWhere((x) => x.path == path);
    if (current.length == before) return;
    await _write(providerId, current);
  }

  Future<void> _write(String providerId, List<VideoUploadEntry> value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value.isEmpty) {
      await prefs.remove(_key(providerId));
      return;
    }
    await prefs.setString(
      _key(providerId),
      jsonEncode([for (final e in value) e.toJson()]),
    );
  }
}
