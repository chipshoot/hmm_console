import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Per-device bookkeeping for the video cache: when each video was last used
/// and which ones the user keeps offline. Never synced.
class VideoCacheIndex {
  VideoCacheIndex(this._prefs);

  final SharedPreferences _prefs;

  static const _lastUsedKey = 'video_cache_last_used';
  static const _keptKey = 'video_keep_offline';

  Map<String, int> _readLastUsed() {
    final raw = _prefs.getString(_lastUsedKey);
    if (raw == null) return {};
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return {};
      return {
        for (final e in json.entries)
          if (e.key is String && e.value is int)
            e.key as String: e.value as int,
      };
    } catch (_) {
      return {};
    }
  }

  /// Records that [path] was just used (downloaded, played or offloaded).
  void touch(String path, [DateTime? at]) {
    final map = _readLastUsed();
    map[path] = (at ?? DateTime.now()).millisecondsSinceEpoch;
    _prefs.setString(_lastUsedKey, jsonEncode(map));
  }

  DateTime? lastUsed(String path) {
    final ms = _readLastUsed()[path];
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Set<String> get keptOffline {
    final raw = _prefs.getString(_keptKey);
    if (raw == null) return {};
    try {
      final json = jsonDecode(raw);
      if (json is! List) return {};
      return json.whereType<String>().toSet();
    } catch (_) {
      return {};
    }
  }

  bool isKept(String path) => keptOffline.contains(path);

  Future<void> setKept(String path, bool kept) async {
    final set = keptOffline;
    if (kept ? !set.add(path) : !set.remove(path)) return;
    await _prefs.setString(_keptKey, jsonEncode(set.toList()..sort()));
  }

  /// Drops the last-used entry only; a kept mark is the user's and stays.
  Future<void> forget(String path) async {
    final map = _readLastUsed();
    if (map.remove(path) == null) return;
    await _prefs.setString(_lastUsedKey, jsonEncode(map));
  }
}
