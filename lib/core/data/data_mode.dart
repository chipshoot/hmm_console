import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../settings/settings_controller.dart';

/// Where the app reads and writes data.
///
/// Display copy for these values lives in `core/i18n/enum_labels.dart`
/// (`.label(l)` / `.describe(l)`), not here — a domain enum should not decide
/// what English word appears on screen. See that file for why the split is
/// load-bearing and not just tidiness.
enum DataMode {
  local,
  cloudStorage,
  cloudApi;
}

enum CloudProvider {
  onedrive;
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
