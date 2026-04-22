import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the "last successful push" cursor per sync provider.
///
/// Each provider keeps its own cursor under `sync_last_pushed_at:<providerId>`
/// so a user who occasionally switches between CloudStorage and CloudApi
/// doesn't lose deltas.
class SyncMetaRepository {
  static String _keyFor(String providerId) =>
      'sync_last_pushed_at:$providerId';

  Future<DateTime?> getLastPushedAt(String providerId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFor(providerId));
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> setLastPushedAt(String providerId, DateTime at) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFor(providerId), at.toUtc().toIso8601String());
  }

  Future<void> clear(String providerId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFor(providerId));
  }
}

final syncMetaRepositoryProvider =
    Provider<SyncMetaRepository>((ref) => SyncMetaRepository());
