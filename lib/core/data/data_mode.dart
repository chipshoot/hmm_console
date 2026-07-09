import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../settings/settings_controller.dart';

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

/// Thin view over the unified settings. Preserves the public surface; the
/// value + persistence live in [settingsProvider] / SettingsController.
class DataModeNotifier extends Notifier<DataMode> {
  @override
  DataMode build() =>
      ref.watch(settingsProvider).value?.dataMode ?? DataMode.local;

  Future<void> setMode(DataMode mode) =>
      ref.read(settingsProvider.notifier).setDataMode(mode);
}

class CloudProviderNotifier extends Notifier<CloudProvider> {
  @override
  CloudProvider build() =>
      ref.watch(settingsProvider).value?.cloudProvider ??
      CloudProvider.onedrive;

  Future<void> setProvider(CloudProvider provider) =>
      ref.read(settingsProvider.notifier).setCloudProvider(provider);
}

final dataModeProvider = NotifierProvider<DataModeNotifier, DataMode>(
  () => DataModeNotifier(),
);

final cloudProviderProvider =
    NotifierProvider<CloudProviderNotifier, CloudProvider>(
  () => CloudProviderNotifier(),
);

final databasePathProvider = FutureProvider<String>((ref) async {
  final customPath = ref.watch(settingsProvider).value?.localDbPath;
  if (customPath != null && customPath.isNotEmpty) return customPath;
  final appDir = await getApplicationDocumentsDirectory();
  return p.join(appDir.path, 'hmm.db');
});
