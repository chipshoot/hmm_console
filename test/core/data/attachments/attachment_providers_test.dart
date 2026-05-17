// Tests cover the cloudStorage vault-path persistence helpers added
// in Phase 11.5. The full provider chain (vaultRootDirectoryProvider
// → LocalVaultStore) depends on path_provider for the default fallback
// and isn't a great fit for unit tests; integration coverage for the
// resolution behavior lives in local_attachments_integration_test.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    test('set + invalidate returns the new value', () async {
      await setCloudStorageVaultPath('/Users/me/OneDrive/Hmm');

      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        await container.read(cloudStorageVaultPathProvider.future),
        equals('/Users/me/OneDrive/Hmm'),
      );
    });

    test('null clears the saved value', () async {
      await setCloudStorageVaultPath('/somewhere');
      await setCloudStorageVaultPath(null);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        await container.read(cloudStorageVaultPathProvider.future),
        isNull,
      );
    });

    test('empty string clears the saved value', () async {
      await setCloudStorageVaultPath('/somewhere');
      await setCloudStorageVaultPath('');

      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        await container.read(cloudStorageVaultPathProvider.future),
        isNull,
      );
    });

    test('set is idempotent and observable across containers', () async {
      await setCloudStorageVaultPath('/a/b/c');

      // Two separate containers see the same value — backed by
      // SharedPreferences, not in-memory state.
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
}
