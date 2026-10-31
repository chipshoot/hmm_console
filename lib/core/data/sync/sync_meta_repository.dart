import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the "last successful push" cursor per sync provider plus a stable
/// per-install device id used for manifest diagnostics.
///
/// Each provider keeps its own cursor under `sync_last_pushed_at:<providerId>`
/// so a user who occasionally switches between CloudStorage and CloudApi
/// doesn't lose deltas.
class SyncMetaRepository {
  static String _cursorKey(String providerId) =>
      'sync_last_pushed_at:$providerId';
  static const _deviceIdKey = 'sync_device_id';

  Future<DateTime?> getLastPushedAt(String providerId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cursorKey(providerId));
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> setLastPushedAt(String providerId, DateTime at) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cursorKey(providerId), at.toUtc().toIso8601String());
  }

  Future<void> clear(String providerId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cursorKey(providerId));
  }

  static String _noteStatesUnsupportedKey(String providerId) =>
      'sync_note_states_unsupported:$providerId';

  /// True after the last sync found a remote without note-state support (an
  /// old Hmm API). Read by the "Pins and flags need the latest server" banner.
  Future<bool> getNoteStatesUnsupported(String providerId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_noteStatesUnsupportedKey(providerId)) ?? false;
  }

  Future<void> setNoteStatesUnsupported(String providerId, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_noteStatesUnsupportedKey(providerId), value);
  }

  /// Stable identifier for this install. Generated lazily on first call. Used
  /// only for telemetry in the manifest — no security or conflict semantics.
  Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = _generateId();
    await prefs.setString(_deviceIdKey, generated);
    return generated;
  }

  String _generateId() {
    final now = DateTime.now().toUtc().microsecondsSinceEpoch.toRadixString(36);
    final rand = Random().nextInt(0x7fffffff).toRadixString(36);
    return 'dev-$now-$rand';
  }
}

final syncMetaRepositoryProvider = Provider<SyncMetaRepository>(
  (ref) => SyncMetaRepository(),
);
