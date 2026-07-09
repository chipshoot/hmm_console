// Tests cover the cloudStorage vault-path persistence, now owned by the
// unified SettingsController (writes go through settingsProvider; the value
// lives in the app_settings blob in SharedPreferences). The full provider
// chain (vaultRootDirectoryProvider → LocalVaultStore) depends on
// path_provider for the default fallback and isn't a great fit for unit
// tests; integration coverage for the resolution behavior lives in
// local_attachments_integration_test.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/vault/api_vault_store.dart';
import 'package:hmm_console/core/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists a vault path through the controller (which writes the blob to
/// SharedPreferences), so a fresh container observes it. Pass '' to clear.
Future<void> _writeVaultPath(String value) async {
  final c = ProviderContainer();
  await c.read(settingsProvider.future);
  await c.read(settingsProvider.notifier).setCloudStorageVaultPath(value);
  c.dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('cloudStorage vault path persistence', () {
    test('initial value is null', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        await container.read(cloudStorageVaultPathProvider.future),
        isNull,
      );
    });

    test('set returns the new value', () async {
      await _writeVaultPath('/Users/me/OneDrive/Hmm');

      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        await container.read(cloudStorageVaultPathProvider.future),
        equals('/Users/me/OneDrive/Hmm'),
      );
    });

    test('empty string clears the saved value', () async {
      await _writeVaultPath('/somewhere');
      await _writeVaultPath('');

      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        await container.read(cloudStorageVaultPathProvider.future),
        isNull,
      );
    });

    test('set is observable across containers', () async {
      await _writeVaultPath('/a/b/c');

      // Two separate containers see the same value — backed by the
      // persisted app_settings blob, not in-memory state.
      final c1 = ProviderContainer();
      final c2 = ProviderContainer();
      addTearDown(c1.dispose);
      addTearDown(c2.dispose);

      expect(await c1.read(cloudStorageVaultPathProvider.future),
          equals('/a/b/c'));
      expect(await c2.read(cloudStorageVaultPathProvider.future),
          equals('/a/b/c'));
    });
  });

  // Phase 15: vaultStoreProvider routes to ApiVaultStore when the
  // active tier is cloudApi. Local + cloudStorage cases need a real
  // path_provider binding, which lives in an integration test; the
  // cloudApi case is pure code (no filesystem) so it slots in here.
  group('vaultStoreProvider × dataMode', () {
    test('cloudApi mode returns an ApiVaultStore', () async {
      final container = ProviderContainer(overrides: [
        dataModeProvider.overrideWith(_FixedDataModeNotifier.new),
      ]);
      addTearDown(container.dispose);

      final store = await container.read(vaultStoreProvider.future);

      expect(store, isA<ApiVaultStore>());
      // Sanity: the dedicated provider returns the same instance.
      expect(store, same(container.read(apiVaultStoreProvider)));
    });
  });
}

/// Override that pins [dataModeProvider] to [DataMode.cloudApi].
class _FixedDataModeNotifier extends DataModeNotifier {
  @override
  DataMode build() => DataMode.cloudApi;
}
