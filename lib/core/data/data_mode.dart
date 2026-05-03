import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;

import 'local/database.dart';

enum DataMode {
  local,
  cloudStorage,
  cloudApi;

  String get displayName => switch (this) {
        local => 'Local (Offline)',
        cloudStorage => 'Cloud Storage',
        cloudApi => 'Cloud (API)',
      };

  String get description => switch (this) {
        local =>
          'Your data stays on this device. No sync, no account needed.',
        cloudStorage =>
          'Data is stored locally and synced to your personal cloud account (OneDrive).',
        cloudApi =>
          'Data is stored locally and synced with the Hmm backend API.',
      };
}

enum CloudProvider {
  onedrive;

  String get displayName => switch (this) {
        onedrive => 'OneDrive',
      };
}

class DataModeNotifier extends Notifier<DataMode> {
  static const _key = 'data_mode';

  @override
  DataMode build() {
    _loadFromPrefs();
    return DataMode.local;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    state = switch (stored) {
      'cloudStorage' => DataMode.cloudStorage,
      // Backward compat: legacy 'api' value maps to the new cloudApi mode.
      'cloudApi' || 'api' => DataMode.cloudApi,
      _ => DataMode.local,
    };
  }

  Future<void> setMode(DataMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

class CloudProviderNotifier extends Notifier<CloudProvider> {
  static const _key = 'cloud_provider';

  @override
  CloudProvider build() {
    _loadFromPrefs();
    return CloudProvider.onedrive;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored == CloudProvider.onedrive.name) {
      state = CloudProvider.onedrive;
    }
  }

  Future<void> setProvider(CloudProvider provider) async {
    state = provider;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, provider.name);
  }
}

final dataModeProvider = NotifierProvider<DataModeNotifier, DataMode>(
  () => DataModeNotifier(),
);

final cloudProviderProvider =
    NotifierProvider<CloudProviderNotifier, CloudProvider>(
  () => CloudProviderNotifier(),
);

final databasePathProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final customPath = prefs.getString('local_db_path');
  if (customPath != null && customPath.isNotEmpty) return customPath;
  final appDir = await getApplicationDocumentsDirectory();
  return p.join(appDir.path, 'hmm.db');
});

Future<void> updateDatabasePath(String newPath) async {
  await setDatabasePath(newPath);
}
