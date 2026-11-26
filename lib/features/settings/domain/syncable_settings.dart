import 'dart:convert';

import '../../calendar/domain/holidays.dart';
import '../../contacts/domain/contact_sort_by.dart';
import '../../launcher/domain/launcher_prefs.dart';
import '../../notes/query/saved_search.dart';
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
    this.launcher = LauncherPrefs.empty,
    this.contactSortBy = ContactSortBy.family,
    this.notesSavedSearches,
    this.calendarShowLunar,
    this.calendarHolidayRegions,
    this.calendarMyHolidays,
    this.glucoseRangeLow,
    this.glucoseRangeHigh,
    this.glucoseRangeUnit,
    this.glucoseDisplayUnit,
    this.homeHiddenTiles,
    this.aiEngines,
    this.aiDefault,
    this.aiRoutes,
  });

  final GasLogSettings gasLog;
  final SyncSettings syncSettings;

  /// Launcher favorites + aliases. Synced with the rest of the bundle.
  final LauncherPrefs launcher;

  /// Contacts list order (Settings → Sort contacts by). Absent in older
  /// bundles, which read as [ContactSortBy.family].
  final ContactSortBy contactSortBy;

  /// Notes saved searches. Null = the bundle did not carry the key (an older
  /// client), so applying it must leave local saved searches alone; an
  /// explicit empty list clears them.
  final List<SavedSearch>? notesSavedSearches;

  /// Calendar "Show lunar calendar". Null = the bundle did not carry the key
  /// (an older client), so applying it must leave this device's value alone.
  final bool? calendarShowLunar;

  /// AI engines (JSON list, never keys), default engine id and purpose routes
  /// (JSON map). Null = the bundle did not carry the key: keep local values.
  final String? aiEngines;
  final String? aiDefault;
  final String? aiRoutes;

  /// Subscribed public-holiday regions. Null = the bundle did not carry the
  /// key (absent is not empty), so applying it leaves local values alone.
  final List<HolidayRegion>? calendarHolidayRegions;

  /// The user's own holidays and hidden downloaded holidays. Null = absent.
  final MyHolidaysData? calendarMyHolidays;

  /// Glucose target range (low, high, unit as `mg/dL`/`mmol/L`) and display
  /// unit. Null = the bundle did not carry the key, so applying it leaves
  /// this device's value alone.
  final num? glucoseRangeLow;
  final num? glucoseRangeHigh;
  final String? glucoseRangeUnit;
  final String? glucoseDisplayUnit;

  /// Route ids of home-screen tiles the user hid. Null = the bundle did not
  /// carry the key (an older client), so applying it leaves this device's
  /// value alone; an explicit empty list shows every tile.
  final List<String>? homeHiddenTiles;

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
        'launcher': launcher.toJson(),
        if (contactSortBy != ContactSortBy.family)
          'contactSortBy': contactSortBy.name,
        'notesSavedSearches': [
          for (final s in notesSavedSearches ?? const <SavedSearch>[])
            s.toJson(),
        ],
        if (calendarShowLunar != null) 'calendarShowLunar': calendarShowLunar,
        if (aiEngines != null) 'aiEngines': aiEngines,
        if (aiDefault != null) 'aiDefault': aiDefault,
        if (aiRoutes != null) 'aiRoutes': aiRoutes,
        if (calendarHolidayRegions != null)
          'calendarHolidayRegions': [
            for (final r in calendarHolidayRegions!) r.toJson(),
          ],
        if (calendarMyHolidays != null)
          'calendarMyHolidays': calendarMyHolidays!.toJson(),
        if (glucoseRangeLow != null) 'glucoseRangeLow': glucoseRangeLow,
        if (glucoseRangeHigh != null) 'glucoseRangeHigh': glucoseRangeHigh,
        if (glucoseRangeUnit != null) 'glucoseRangeUnit': glucoseRangeUnit,
        if (glucoseDisplayUnit != null)
          'glucoseDisplayUnit': glucoseDisplayUnit,
        if (homeHiddenTiles != null) 'homeHiddenTiles': homeHiddenTiles,
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
      launcher: () {
        final l = json['launcher'] as Map<String, dynamic>?;
        return l != null ? LauncherPrefs.fromJson(l) : LauncherPrefs.empty;
      }(),
      contactSortBy: ContactSortBy.fromName(json['contactSortBy']),
      notesSavedSearches: json.containsKey('notesSavedSearches')
          ? parseSavedSearches(json['notesSavedSearches'])
          : null,
      calendarShowLunar: json['calendarShowLunar'] is bool
          ? json['calendarShowLunar'] as bool
          : null,
      aiEngines: json['aiEngines'] is String
          ? json['aiEngines'] as String
          : null,
      aiDefault: json['aiDefault'] is String
          ? json['aiDefault'] as String
          : null,
      aiRoutes: json['aiRoutes'] is String ? json['aiRoutes'] as String : null,
      calendarHolidayRegions: json['calendarHolidayRegions'] is List
          ? [
              for (final r in json['calendarHolidayRegions'] as List)
                ?HolidayRegion.fromJson(r),
            ]
          : null,
      calendarMyHolidays: json['calendarMyHolidays'] is Map
          ? MyHolidaysData.fromJson(json['calendarMyHolidays'])
          : null,
      glucoseRangeLow: json['glucoseRangeLow'] is num
          ? json['glucoseRangeLow'] as num
          : null,
      glucoseRangeHigh: json['glucoseRangeHigh'] is num
          ? json['glucoseRangeHigh'] as num
          : null,
      glucoseRangeUnit: json['glucoseRangeUnit'] is String
          ? json['glucoseRangeUnit'] as String
          : null,
      glucoseDisplayUnit: json['glucoseDisplayUnit'] is String
          ? json['glucoseDisplayUnit'] as String
          : null,
      homeHiddenTiles: json['homeHiddenTiles'] is List
          ? [
              for (final e in json['homeHiddenTiles'] as List)
                if (e is String) e,
            ]
          : null,
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
    LauncherPrefs? launcher,
    ContactSortBy? contactSortBy,
    List<SavedSearch>? notesSavedSearches,
    bool? calendarShowLunar,
    List<HolidayRegion>? calendarHolidayRegions,
    MyHolidaysData? calendarMyHolidays,
    num? glucoseRangeLow,
    num? glucoseRangeHigh,
    String? glucoseRangeUnit,
    String? glucoseDisplayUnit,
    List<String>? homeHiddenTiles,
    String? aiEngines,
    String? aiDefault,
    String? aiRoutes,
  }) {
    return SyncableSettings(
      gasLog: gasLog ?? this.gasLog,
      syncSettings: syncSettings ?? this.syncSettings,
      localeCode:
          identical(localeCode, _sentinel) ? this.localeCode : localeCode as String?,
      lastModified: lastModified ?? this.lastModified,
      launcher: launcher ?? this.launcher,
      contactSortBy: contactSortBy ?? this.contactSortBy,
      notesSavedSearches: notesSavedSearches ?? this.notesSavedSearches,
      calendarShowLunar: calendarShowLunar ?? this.calendarShowLunar,
      aiEngines: aiEngines ?? this.aiEngines,
      aiDefault: aiDefault ?? this.aiDefault,
      aiRoutes: aiRoutes ?? this.aiRoutes,
      calendarHolidayRegions:
          calendarHolidayRegions ?? this.calendarHolidayRegions,
      calendarMyHolidays: calendarMyHolidays ?? this.calendarMyHolidays,
      glucoseRangeLow: glucoseRangeLow ?? this.glucoseRangeLow,
      glucoseRangeHigh: glucoseRangeHigh ?? this.glucoseRangeHigh,
      glucoseRangeUnit: glucoseRangeUnit ?? this.glucoseRangeUnit,
      glucoseDisplayUnit: glucoseDisplayUnit ?? this.glucoseDisplayUnit,
      homeHiddenTiles: homeHiddenTiles ?? this.homeHiddenTiles,
    );
  }
}

/// Sentinel so `copyWith(localeCode: null)` can explicitly set null
/// (i.e. "follow system locale") vs "leave the field alone".
const Object _sentinel = Object();
