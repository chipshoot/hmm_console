import '../data/data_mode.dart';
import '../../features/receipt_scan/domain/receipt_draft.dart';

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
    this.dashboardIntroCardSeen = false,
    this.onboardingCompleted = false,
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
  final bool dashboardIntroCardSeen;
  final bool onboardingCompleted;
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
      dashboardIntroCardSeen: j['dashboardIntroCardSeen'] as bool? ?? false,
      onboardingCompleted: j['onboardingCompleted'] as bool? ?? false,
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
        'dashboardIntroCardSeen': dashboardIntroCardSeen,
        'onboardingCompleted': onboardingCompleted,
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
    bool? dashboardIntroCardSeen,
    bool? onboardingCompleted,
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
        dashboardIntroCardSeen:
            dashboardIntroCardSeen ?? this.dashboardIntroCardSeen,
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
        localDbPath: localDbPath ?? this.localDbPath,
        cloudStorageVaultPath:
            cloudStorageVaultPath ?? this.cloudStorageVaultPath,
        schemaVersion: schemaVersion,
      );
}
