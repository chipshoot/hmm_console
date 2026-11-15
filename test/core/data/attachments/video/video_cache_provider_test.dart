import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/video/video_cache.dart';
import 'package:hmm_console/core/data/attachments/video/video_cache_index.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/sync/sync_orchestrator.dart';
import 'package:hmm_console/core/data/vault/vault_file_store.dart';
import 'package:hmm_console/core/data/vault/vault_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Files implements IVaultFileStore {
  final sizes = <String, int>{'a.mov': 3 * 1024 * 1024 * 1024};
  final deleted = <String>[];
  @override
  Future<List<VaultEntry>> listOffloaded() async => [
    for (final e in sizes.entries)
      VaultEntry(relativePath: e.key, byteSize: e.value),
  ];
  @override
  Future<void> deleteOffloaded(String p) async {
    sizes.remove(p);
    deleted.add(p);
  }

  @override
  Future<DateTime?> offloadedModified(String p) async => null;
  @override
  Future<int> deleteStaleParts() async => 0;
  @override
  Future<File?> localFile(String p) async => null;
  @override
  File? downloadTarget(String p) => null;
  @override
  Future<void> importFile(String p, File s) async {}
  @override
  Future<void> offload(String p) async {}
}

class _Mode extends DataModeNotifier {
  _Mode(this._mode);
  final DataMode _mode;
  @override
  DataMode build() => _mode;
}

class _Orchestrator implements SyncOrchestrator {
  @override
  CloudSyncProvider? get provider => null;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late _Files files;
  late HmmDatabase db;

  ProviderContainer containerFor(DataMode mode) {
    final c = ProviderContainer(
      overrides: [
        dataModeProvider.overrideWith(() => _Mode(mode)),
        vaultFileStoreProvider.overrideWith((ref) async => files),
        videoCacheIndexProvider.overrideWith(
          (ref) async => VideoCacheIndex(await SharedPreferences.getInstance()),
        ),
        syncOrchestratorProvider.overrideWithValue(_Orchestrator()),
        hmmDatabaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    files = _Files();
    db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);
  });

  test('local mode has no cache, so nothing is evicted', () async {
    final c = containerFor(DataMode.local);
    expect(await c.read(videoCacheProvider.future), isNull);
    expect(files.deleted, isEmpty);
  });

  test('cloudStorage mode has a cache', () async {
    final c = containerFor(DataMode.cloudStorage);
    expect(await c.read(videoCacheProvider.future), isNotNull);
  });
}
