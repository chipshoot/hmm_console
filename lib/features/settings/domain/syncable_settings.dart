import 'dart:convert';

import 'gas_log_settings.dart';
import 'sync_settings.dart';

/// Aggregate of every user preference that travels across devices via
/// the cloud-sync layer. Whatever is NOT in this object lives only on
/// the device that wrote it — by design.
///
/// What's in: gas-log units + currency + showRegistration toggle, sync
/// network policy, UI locale. These are "the user's taste" preferences.
///
/// What's out (intentional, see `task_plan.md` Phase D.2):
///   - `DataMode` (cloud tier) — which storage backend the user wants
///     on THIS device. Phones may run cloudStorage; laptops may run
///     local.
///   - `CloudProvider` — paired with DataMode.
///   - Vault folder path — device-specific filesystem location.
///   - SQLite database path — same.
///   - OneDrive auth tokens — live in flutter_secure_storage, not prefs.
///   - Sync cursor + device id — operational state, not preferences.
///
/// Conflict resolution: whole-bundle last-writer-wins. [lastModified]
/// is the bundle's "version stamp"; the device whose bundle has the
/// later stamp wins ALL fields. Independent per-field merging would
/// be nice but isn't worth the complexity for v1 — settings change
/// rarely, and the surprise-factor of "I changed X on phone, laptop
/// pull overwrote my Y change on laptop" is acceptable given users
/// can just change Y back.
class SyncableSettings {
  const SyncableSettings({
    required this.gasLog,
    required this.syncSettings,
    required this.localeCode,
    required this.lastModified,
  });

  final GasLogSettings gasLog;
  final SyncSettings syncSettings;

  /// User-selected UI locale code (e.g. 'en', 'zh'). Null = follow
  /// system. Stored as the raw language code rather than a `Locale`
  /// object so the JSON shape stays primitive.
  final String? localeCode;

  /// UTC timestamp of the most recent local mutation. Pull leg
  /// compares this to the remote bundle's stamp to decide who wins.
  final DateTime lastModified;

  /// Treats an absent `lastModified` field on the wire as "never set"
  /// (epoch zero) — that way an old bundle in the cloud loses to any
  /// real local change.
  static final DateTime epochZero =
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  Map<String, dynamic> toJson() => {
        'gasLog': gasLog.toJson(),
        'syncSettings': {
          'networkPolicy': syncSettings.networkPolicy.name,
        },
        if (localeCode != null) 'localeCode': localeCode,
        'lastModified': lastModified.toUtc().toIso8601String(),
        '_v': 1,
      };

  factory SyncableSettings.fromJson(Map<String, dynamic> json) {
    final gasLogJson = json['gasLog'] as Map<String, dynamic>?;
    final syncSettingsJson = json['syncSettings'] as Map<String, dynamic>?;

    return SyncableSettings(
      gasLog: gasLogJson != null
          ? GasLogSettings.fromJson(gasLogJson)
          : const GasLogSettings(),
      syncSettings: SyncSettings(
        networkPolicy: switch (
            syncSettingsJson?['networkPolicy'] as String?) {
          'anyNetwork' => SyncNetworkPolicy.anyNetwork,
          // Old payloads + unknown values default to the safe choice.
          _ => SyncNetworkPolicy.wifiOnly,
        },
      ),
      localeCode: json['localeCode'] as String?,
      lastModified: () {
        final raw = json['lastModified'] as String?;
        if (raw == null) return epochZero;
        return DateTime.tryParse(raw)?.toUtc() ?? epochZero;
      }(),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory SyncableSettings.fromJsonString(String s) =>
      SyncableSettings.fromJson(jsonDecode(s) as Map<String, dynamic>);

  /// Defaults used when no settings have been persisted yet.
  factory SyncableSettings.defaults() => SyncableSettings(
        gasLog: const GasLogSettings(),
        syncSettings: const SyncSettings(),
        localeCode: null,
        lastModified: epochZero,
      );

  SyncableSettings copyWith({
    GasLogSettings? gasLog,
    SyncSettings? syncSettings,
    Object? localeCode = _sentinel,
    DateTime? lastModified,
  }) {
    return SyncableSettings(
      gasLog: gasLog ?? this.gasLog,
      syncSettings: syncSettings ?? this.syncSettings,
      localeCode:
          identical(localeCode, _sentinel) ? this.localeCode : localeCode as String?,
      lastModified: lastModified ?? this.lastModified,
    );
  }
}

/// Sentinel so `copyWith(localeCode: null)` can explicitly set null
/// (i.e. "follow system locale") vs "leave the field alone".
const Object _sentinel = Object();
