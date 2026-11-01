import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// cloudStorage purges whose remote half (note blob + released vault files)
/// waits for the next sync, keyed per provider like the sync cursor. Sync
/// runs it after the pull, so a note restored on another device is revived
/// first and never deleted remotely.
class PendingRemotePurgeStore {
  static String _key(String providerId) =>
      'sync_pending_remote_purge:$providerId';

  /// uuid → vault paths released when the note was purged locally.
  Future<Map<String, Set<String>>> read(String providerId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(providerId));
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final e in decoded.entries)
          if (e.key is String && e.value is List)
            e.key as String: (e.value as List).whereType<String>().toSet(),
      };
    } on FormatException {
      return {};
    }
  }

  Future<void> add(
    String providerId,
    String uuid,
    Set<String> vaultPaths,
  ) async {
    final current = await read(providerId);
    current[uuid] = {...?current[uuid], ...vaultPaths};
    await _write(providerId, current);
  }

  Future<void> remove(String providerId, String uuid) async {
    final current = await read(providerId);
    if (current.remove(uuid) == null) return;
    await _write(providerId, current);
  }

  Future<void> _write(String providerId, Map<String, Set<String>> value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value.isEmpty) {
      await prefs.remove(_key(providerId));
      return;
    }
    await prefs.setString(
      _key(providerId),
      jsonEncode({
        for (final e in value.entries) e.key: (e.value.toList()..sort()),
      }),
    );
  }
}
