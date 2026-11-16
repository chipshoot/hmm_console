import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/video/video_cache.dart';
import 'package:hmm_console/core/data/attachments/video/video_cache_index.dart';
import 'package:hmm_console/core/data/attachments/video/video_uploader.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/sync/sync_orchestrator.dart';
import 'package:hmm_console/core/data/vault/vault_file_store.dart';
import 'package:hmm_console/core/data/vault/vault_store.dart' show VaultEntry;
import 'package:shared_preferences/shared_preferences.dart';

const _path = 'attachments/note-1/clip.mov';

class _Files implements IVaultFileStore {
  _Files(this.file);
  final File file;
  @override
  Future<List<VaultEntry>> listOffloaded() async => const [];
  @override
  Future<void> deleteOffloaded(String p) async {}
  @override
  Future<DateTime?> offloadedModified(String p) async => null;
  @override
  Future<int> deleteStaleParts() async => 0;
  @override
  Future<File?> localFile(String p) async => file;
  @override
  Future<void> offload(String p) async {}
  @override
  Future<void> importFile(String p, File s) async {}
  @override
  File? downloadTarget(String p) => null;
}

class _Provider extends CloudSyncProvider {
  @override
  String get providerId => 'fake';
  @override
  bool get supportsLargeFiles => true;
  @override
  Future<String> startLargeUpload(String path, int total) async => 's';
  @override
  Future<int?> largeUploadNextOffset(String h) async => null;
  @override
  Future<bool> uploadLargeChunk(
    String h,
    Uint8List chunk,
    int offset,
    int total,
  ) async => offset + chunk.length >= total;
  @override
  Future<void> cancelLargeUpload(String h) async {}
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Orchestrator implements SyncOrchestrator {
  _Orchestrator(this._provider);
  final CloudSyncProvider _provider;
  @override
  CloudSyncProvider? get provider => _provider;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Mode extends DataModeNotifier {
  @override
  DataMode build() => DataMode.cloudStorage;
}

class _FakeCache implements VideoCache {
  final evicted = <Set<String>>[];
  @override
  Future<List<String>> evictToFit({Set<String> protect = const {}}) async {
    evicted.add(protect);
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test('an upload that offloads a video touches it in the cache index and '
      'trims the cache with it protected', () async {
    SharedPreferences.setMockInitialValues({});
    final index = VideoCacheIndex(await SharedPreferences.getInstance());
    final dir = await Directory.systemTemp.createTemp('vupw');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/clip.mov')..writeAsBytesSync([1, 2, 3]);
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final aid = await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    final cid = await db
        .into(db.noteCatalogs)
        .insert(NoteCatalogsCompanion.insert(name: 'Cat', schema: '{}'));
    await db
        .into(db.notes)
        .insert(
          NotesCompanion.insert(
            subject: 'v',
            content: const Value(''),
            authorId: aid,
            catalogId: Value(cid),
            attachments: Value(
              jsonEncode({
                'files': [
                  {
                    'kind': 'vault',
                    'path': _path,
                    'contentType': 'video/quicktime',
                    'byteSize': 3,
                  },
                ],
              }),
            ),
          ),
        );
    final cache = _FakeCache();
    final c = ProviderContainer(
      overrides: [
        dataModeProvider.overrideWith(_Mode.new),
        videoMayUseNetworkProvider.overrideWithValue(() async => true),
        syncOrchestratorProvider.overrideWithValue(_Orchestrator(_Provider())),
        vaultFileStoreProvider.overrideWith((ref) async => _Files(file)),
        hmmDatabaseProvider.overrideWithValue(db),
        videoCacheIndexProvider.overrideWith((ref) async => index),
        videoCacheProvider.overrideWith((ref) async => cache),
      ],
    );
    addTearDown(c.dispose);

    final uploader = (await c.read(videoUploaderProvider.future))!;
    expect(index.lastUsed(_path), isNull);
    await uploader.enqueue(_path);
    await uploader.run();
    await pumpEventQueue();

    expect(index.lastUsed(_path), isNotNull);
    expect(cache.evicted, [
      {_path},
    ]);
  });
}
