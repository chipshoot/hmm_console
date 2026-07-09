import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/data_mode.dart';
import '../../features/receipt_scan/domain/receipt_draft.dart';
import 'app_settings.dart';
import 'settings_migration.dart';

const _blobKey = 'app_settings';

/// Single owner of the device-local settings blob. On first load it decodes
/// the blob, or migrates the legacy keys, or (on a corrupt blob) falls back to
/// the retained legacy keys so connection-critical settings are never lost.
class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_blobKey);
    if (raw == null) {
      final migrated = migrateFromLegacy(prefs);
      await _persist(prefs, migrated);
      return migrated;
    }
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('SettingsController: corrupt app_settings blob ($e); '
          'falling back to legacy keys.');
      // Legacy keys are retained this release: recover connection-critical
      // (and everything else) rather than dropping to blind defaults.
      return migrateFromLegacy(prefs);
    }
  }

  Future<void> _persist(SharedPreferences prefs, AppSettings s) async {
    try {
      await prefs.setString(_blobKey, jsonEncode(s.toJson()));
    } catch (e) {
      debugPrint('SettingsController: persist failed ($e); keeping in-memory.');
    }
  }

  Future<void> _update(AppSettings next) async {
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await _persist(prefs, next);
  }

  AppSettings get _current => state.value ?? AppSettings.defaults;

  Future<void> setDataMode(DataMode v) =>
      _update(_current.copyWith(dataMode: v));
  Future<void> setCloudProvider(CloudProvider v) =>
      _update(_current.copyWith(cloudProvider: v));
  Future<void> setGeoCaptureEnabled(bool v) =>
      _update(_current.copyWith(geoCaptureEnabled: v));
  Future<void> setReceiptExtractorMode(ReceiptExtractorMode v) =>
      _update(_current.copyWith(receiptExtractorMode: v));
  Future<void> setReceiptCloudConsent(bool v) =>
      _update(_current.copyWith(receiptCloudConsent: v));
  Future<void> setLauncherRecents(List<String> v) =>
      _update(_current.copyWith(launcherRecents: v));
  Future<void> setNotesFilterUsage(Map<String, int> v) =>
      _update(_current.copyWith(notesFilterUsage: v));
  Future<void> setDashboardIntroCardSeen(bool v) =>
      _update(_current.copyWith(dashboardIntroCardSeen: v));
  Future<void> setOnboardingCompleted(bool v) =>
      _update(_current.copyWith(onboardingCompleted: v));
  Future<void> setLocalDbPath(String v) =>
      _update(_current.copyWith(localDbPath: v));
  Future<void> setCloudStorageVaultPath(String v) =>
      _update(_current.copyWith(cloudStorageVaultPath: v));
}

final settingsProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
        SettingsController.new);
