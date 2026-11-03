import '../data/data_mode.dart';
import '../../features/receipt_scan/domain/receipt_draft.dart';

/// How much each Notes list row shows. Per device.
enum NoteRowDensity { compact, standard, rich }

/// One immutable, typed document holding every device-local setting. Persisted
/// as a single JSON blob (see SettingsController). Roaming settings and secrets
/// are NOT here.
class AppSettings {
  const AppSettings({
    this.dataMode = DataMode.local,
    this.cloudProvider = CloudProvider.onedrive,
    this.geoCaptureEnabled = false,
    this.receiptExtractorMode = ReceiptExtractorMode.onDevice,
    this.receiptCloudConsent = false,
    this.launcherRecents = const [],
    this.notesFilterUsage = const {},
    this.notesRowDensity = NoteRowDensity.standard,
    this.notesRecentSearches = const [],
    this.dashboardIntroCardSeen = false,
    this.onboardingCompleted = false,
    this.quickPanelEnabled = true,
    this.quickPanelHintShown = false,
    this.localDbPath,
    this.cloudStorageVaultPath,
    this.schemaVersion = currentSchemaVersion,
  });

  static const int currentSchemaVersion = 1;
  static const AppSettings defaults = AppSettings();

  final DataMode dataMode;
  final CloudProvider cloudProvider;
  final bool geoCaptureEnabled;
  final ReceiptExtractorMode receiptExtractorMode;
  final bool receiptCloudConsent;
  final List<String> launcherRecents;
  final Map<String, int> notesFilterUsage;
  final NoteRowDensity notesRowDensity;

  /// Per-device recent notes searches, stored as raw JSON maps (core/ must not
  /// import features/; the notes-side notifier converts them).
  final List<Map<String, Object?>> notesRecentSearches;
  final bool dashboardIntroCardSeen;
  final bool onboardingCompleted;
  final bool quickPanelEnabled;
  final bool quickPanelHintShown;
  final String? localDbPath;
  final String? cloudStorageVaultPath;
  final int schemaVersion;

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    DataMode dataMode() => switch (j['dataMode']) {
          'cloudStorage' => DataMode.cloudStorage,
          'cloudApi' || 'api' => DataMode.cloudApi,
          _ => DataMode.local,
        };
    final recents =
        (j['launcherRecents'] as List?)?.whereType<String>().toList() ??
            const <String>[];
    final usage = (j['notesFilterUsage'] as Map?)?.map(
          (k, v) => MapEntry(k as String, (v as num).toInt()),
        ) ??
        const <String, int>{};
    final recentSearches = [
      if (j['notesRecentSearches'] case final List l)
        for (final e in l)
          if (e is Map) Map<String, Object?>.from(e),
    ];
    return AppSettings(
      dataMode: dataMode(),
      cloudProvider: CloudProvider.values.firstWhere(
        (c) => c.name == j['cloudProvider'],
        orElse: () => CloudProvider.onedrive,
      ),
      geoCaptureEnabled: j['geoCaptureEnabled'] as bool? ?? false,
      receiptExtractorMode:
          ReceiptExtractorMode.fromWire(j['receiptExtractorMode'] as String?),
      receiptCloudConsent: j['receiptCloudConsent'] as bool? ?? false,
      launcherRecents: recents,
      notesFilterUsage: usage,
      notesRowDensity: NoteRowDensity.values.firstWhere(
        (d) => d.name == j['notesRowDensity'],
        orElse: () => NoteRowDensity.standard,
      ),
      notesRecentSearches: recentSearches,
      dashboardIntroCardSeen: j['dashboardIntroCardSeen'] as bool? ?? false,
      onboardingCompleted: j['onboardingCompleted'] as bool? ?? false,
      quickPanelEnabled: j['quickPanelEnabled'] as bool? ?? true,
      quickPanelHintShown: j['quickPanelHintShown'] as bool? ?? false,
      localDbPath: j['localDbPath'] as String?,
      cloudStorageVaultPath: j['cloudStorageVaultPath'] as String?,
      schemaVersion:
          (j['schemaVersion'] as num?)?.toInt() ?? currentSchemaVersion,
    );
  }

  Map<String, dynamic> toJson() => {
        'dataMode': dataMode.name,
        'cloudProvider': cloudProvider.name,
        'geoCaptureEnabled': geoCaptureEnabled,
        'receiptExtractorMode': receiptExtractorMode.wire,
        'receiptCloudConsent': receiptCloudConsent,
        'launcherRecents': launcherRecents,
        'notesFilterUsage': notesFilterUsage,
        'notesRowDensity': notesRowDensity.name,
        'notesRecentSearches': notesRecentSearches,
        'dashboardIntroCardSeen': dashboardIntroCardSeen,
        'onboardingCompleted': onboardingCompleted,
        'quickPanelEnabled': quickPanelEnabled,
        'quickPanelHintShown': quickPanelHintShown,
        if (localDbPath != null) 'localDbPath': localDbPath,
        if (cloudStorageVaultPath != null)
          'cloudStorageVaultPath': cloudStorageVaultPath,
        'schemaVersion': schemaVersion,
      };

  AppSettings copyWith({
    DataMode? dataMode,
    CloudProvider? cloudProvider,
    bool? geoCaptureEnabled,
    ReceiptExtractorMode? receiptExtractorMode,
    bool? receiptCloudConsent,
    List<String>? launcherRecents,
    Map<String, int>? notesFilterUsage,
    NoteRowDensity? notesRowDensity,
    List<Map<String, Object?>>? notesRecentSearches,
    bool? dashboardIntroCardSeen,
    bool? onboardingCompleted,
    bool? quickPanelEnabled,
    bool? quickPanelHintShown,
    String? localDbPath,
    String? cloudStorageVaultPath,
  }) =>
      AppSettings(
        dataMode: dataMode ?? this.dataMode,
        cloudProvider: cloudProvider ?? this.cloudProvider,
        geoCaptureEnabled: geoCaptureEnabled ?? this.geoCaptureEnabled,
        receiptExtractorMode: receiptExtractorMode ?? this.receiptExtractorMode,
        receiptCloudConsent: receiptCloudConsent ?? this.receiptCloudConsent,
        launcherRecents: launcherRecents ?? this.launcherRecents,
        notesFilterUsage: notesFilterUsage ?? this.notesFilterUsage,
        notesRowDensity: notesRowDensity ?? this.notesRowDensity,
        notesRecentSearches: notesRecentSearches ?? this.notesRecentSearches,
        dashboardIntroCardSeen:
            dashboardIntroCardSeen ?? this.dashboardIntroCardSeen,
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
        quickPanelEnabled: quickPanelEnabled ?? this.quickPanelEnabled,
        quickPanelHintShown: quickPanelHintShown ?? this.quickPanelHintShown,
        localDbPath: localDbPath ?? this.localDbPath,
        cloudStorageVaultPath:
            cloudStorageVaultPath ?? this.cloudStorageVaultPath,
        schemaVersion: schemaVersion,
      );
}
