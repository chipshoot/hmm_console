import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../launcher/domain/launcher_prefs.dart';
import '../domain/gas_log_settings.dart';
import '../domain/sync_settings.dart';
import '../domain/syncable_settings.dart';

/// Reads + writes the [SyncableSettings] bundle against the same
/// SharedPreferences keys the per-feature notifiers already own:
///
///   - `gas_log_settings`     → `GasLogSettings` JSON blob
///   - `sync.network_policy`  → `SyncNetworkPolicy` enum name
///   - `app_locale`           → language code string ('en', 'zh', …)
///   - `settings.last_modified` → ISO8601 UTC, bumped by every setter
///
/// The cloud sync layer goes through THIS repo to get a coherent
/// snapshot (and to apply a pulled snapshot back into the per-feature
/// keys atomically). The per-feature notifiers also bump
/// `settings.last_modified` whenever they mutate their slice — that's
/// how the conflict-resolution stamp stays accurate without us having
/// to introspect every notifier from the orchestrator.
///
/// Pure Dart (no Riverpod inside) so it composes cleanly with the
/// orchestrator's plain-class style + is easy to unit-test.
class SyncableSettingsRepository {
  static const _gasLogKey = 'gas_log_settings';
  static const _localeKey = 'app_locale';
  static const _networkPolicyKey = 'sync.network_policy';
  static const _lastModifiedKey = 'settings.last_modified';
  static const _launcherKey = 'launcher_prefs';

  /// Reads the current local snapshot. Missing keys fall back to
  /// defaults — same behaviour as the per-feature notifiers' first-
  /// boot path.
  Future<SyncableSettings> read() async {
    final prefs = await SharedPreferences.getInstance();

    GasLogSettings gasLog;
    final gasLogRaw = prefs.getString(_gasLogKey);
    if (gasLogRaw != null) {
      try {
        gasLog = GasLogSettings.fromJsonString(gasLogRaw);
      } catch (_) {
        gasLog = const GasLogSettings();
      }
    } else {
      gasLog = const GasLogSettings();
    }

    final policyRaw = prefs.getString(_networkPolicyKey);
    final syncSettings = SyncSettings(
      networkPolicy: switch (policyRaw) {
        'anyNetwork' => SyncNetworkPolicy.anyNetwork,
        _ => SyncNetworkPolicy.wifiOnly,
      },
    );

    final localeCode = prefs.getString(_localeKey);

    final lastModifiedRaw = prefs.getString(_lastModifiedKey);
    final lastModified = () {
      if (lastModifiedRaw == null) return SyncableSettings.epochZero;
      return DateTime.tryParse(lastModifiedRaw)?.toUtc() ??
          SyncableSettings.epochZero;
    }();

    final launcherRaw = prefs.getString(_launcherKey);
    LauncherPrefs launcher;
    if (launcherRaw != null) {
      try {
        launcher = LauncherPrefs.fromJsonString(launcherRaw);
      } catch (_) {
        launcher = LauncherPrefs.empty;
      }
    } else {
      launcher = LauncherPrefs.empty;
    }

    return SyncableSettings(
      gasLog: gasLog,
      syncSettings: syncSettings,
      localeCode: (localeCode == null || localeCode.isEmpty) ? null : localeCode,
      lastModified: lastModified,
      launcher: launcher,
    );
  }

  /// Applies a [SyncableSettings] bundle to the underlying
  /// SharedPreferences keys. Used by the sync orchestrator when a
  /// pulled bundle is newer than local. Does NOT touch
  /// `settings.last_modified` separately — the bundle's stamp is
  /// written through verbatim so the next sync sees the SAME stamp on
  /// both ends.
  Future<void> apply(SyncableSettings settings) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_gasLogKey, settings.gasLog.toJsonString());
    await prefs.setString(
      _networkPolicyKey,
      settings.syncSettings.networkPolicy.name,
    );
    if (settings.localeCode == null) {
      await prefs.remove(_localeKey);
    } else {
      await prefs.setString(_localeKey, settings.localeCode!);
    }
    await prefs.setString(_launcherKey, settings.launcher.toJsonString());
    await prefs.setString(
      _lastModifiedKey,
      settings.lastModified.toUtc().toIso8601String(),
    );
  }

  /// Bumps the bundle's stamp to "now". Called by every per-feature
  /// notifier setter; the orchestrator never calls this directly.
  Future<DateTime> bumpLastModified() async {
    final now = DateTime.now().toUtc();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastModifiedKey, now.toIso8601String());
    return now;
  }
}

final syncableSettingsRepositoryProvider =
    Provider<SyncableSettingsRepository>(
        (ref) => SyncableSettingsRepository());
