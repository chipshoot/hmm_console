import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/data_mode.dart';
import '../../features/receipt_scan/domain/receipt_draft.dart';
import 'app_settings.dart';

/// Reads the pre-unification device-local keys into an [AppSettings].
/// Missing keys fall back to defaults. Legacy keys are NOT removed (retained
/// this release as a reversible safety net and as the corrupt-blob fallback
/// source for connection-critical fields).
AppSettings migrateFromLegacy(SharedPreferences prefs) {
  final dataMode = switch (prefs.getString('data_mode')) {
    'cloudStorage' => DataMode.cloudStorage,
    'cloudApi' || 'api' => DataMode.cloudApi,
    _ => DataMode.local,
  };

  List<String> recents() {
    final raw = prefs.getString('launcher_recents');
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List).whereType<String>().toList();
    } catch (_) {
      return const [];
    }
  }

  Map<String, int> usage() {
    final raw = prefs.getString('notes.filter_usage');
    if (raw == null || raw.isEmpty) return const {};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return m.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return const {};
    }
  }

  return AppSettings(
    dataMode: dataMode,
    cloudProvider: CloudProvider.values.firstWhere(
      (c) => c.name == prefs.getString('cloud_provider'),
      orElse: () => CloudProvider.onedrive,
    ),
    geoCaptureEnabled: prefs.getBool('geo_capture_enabled') ?? false,
    receiptExtractorMode: ReceiptExtractorMode.fromWire(
        prefs.getString('receipt_extractor_mode')),
    receiptCloudConsent: prefs.getBool('receipt_cloud_consent') ?? false,
    launcherRecents: recents(),
    notesFilterUsage: usage(),
    dashboardIntroCardSeen: prefs.getBool('dashboard_intro_card_seen') ?? false,
    onboardingCompleted: prefs.getBool('onboarding_completed') ?? false,
    localDbPath: prefs.getString('local_db_path'),
    cloudStorageVaultPath: prefs.getString('cloud_storage_vault_path'),
  );
}
