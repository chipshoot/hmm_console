// Phase 4a Task 7: vaultStoreProvider wires EncryptedVaultStore over the
// (now-public) baseVaultStoreProvider for local/cloudStorage, while
// cloudApi keeps returning the base ApiVaultStore unchanged (encryption
// there is Phase 5).
//
// Note on the dataModeProvider override: dataModeProvider is a
// NotifierProvider<DataModeNotifier, DataMode> (see lib/core/data/data_mode.dart),
// not a plain value provider, so `dataModeProvider.overrideWith((ref) => mode)`
// does not type-check. The rest of the suite (e.g.
// test/core/data/attachments/attachment_providers_test.dart) overrides it with
// a DataModeNotifier subclass via `dataModeProvider.overrideWith(_Fixed.new)`.
// We follow that shape here.

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/vault/encrypted_vault_store.dart';
import 'package:hmm_console/core/data/vault/vault_store.dart';

class _FakeVaultStore implements IVaultStore {
  final Map<String, Uint8List> m = {};
  @override
  Future<void> putBytes(String p, Uint8List b, {String? contentType}) async {
    m[p] = b;
  }

  @override
  Future<Uint8List> getBytes(String p) async {
    final v = m[p];
    if (v == null) throw VaultStoreException('missing', p);
    return v;
  }

  @override
  Future<bool> exists(String p) async => m.containsKey(p);
  @override
  Future<void> delete(String p) async => m.remove(p);
  @override
  Future<List<VaultEntry>> list(String prefix) async => const [];
}

/// Pins [dataModeProvider] to a fixed [DataMode], mirroring the pattern
/// used in attachment_providers_test.dart's `_FixedDataModeNotifier`.
class _StubDataModeNotifier extends DataModeNotifier {
  _StubDataModeNotifier(this._mode);
  final DataMode _mode;
  @override
  DataMode build() => _mode;
}

ProviderContainer _containerFor(DataMode mode, IVaultStore base) {
  return ProviderContainer(
    overrides: [
      dataModeProvider.overrideWith(() => _StubDataModeNotifier(mode)),
      baseVaultStoreProvider.overrideWith((ref) async => base),
    ],
  );
}

void main() {
  test('local mode yields an EncryptedVaultStore', () async {
    final c = _containerFor(DataMode.local, _FakeVaultStore());
    addTearDown(c.dispose);
    final store = await c.read(vaultStoreProvider.future);
    expect(store, isA<EncryptedVaultStore>());
  });

  test('cloudStorage mode yields an EncryptedVaultStore', () async {
    final c = _containerFor(DataMode.cloudStorage, _FakeVaultStore());
    addTearDown(c.dispose);
    final store = await c.read(vaultStoreProvider.future);
    expect(store, isA<EncryptedVaultStore>());
  });

  test('cloudApi mode yields the base store unchanged (no encryption)',
      () async {
    final base = _FakeVaultStore();
    final c = _containerFor(DataMode.cloudApi, base);
    addTearDown(c.dispose);
    final store = await c.read(vaultStoreProvider.future);
    expect(store, same(base));
    expect(store, isNot(isA<EncryptedVaultStore>()));
  });
}
