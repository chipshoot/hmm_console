import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/video/video_cache.dart';
import 'package:hmm_console/core/data/attachments/video/video_cache_index.dart';
import 'package:hmm_console/core/data/vault/vault_file_store.dart';
import 'package:hmm_console/core/data/vault/vault_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Files implements IVaultFileStore {
  final sizes = <String, int>{};
  final modified = <String, DateTime>{};
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
  Future<DateTime?> offloadedModified(String p) async => modified[p];
  @override
  Future<int> deleteStaleParts() async => 3;
  @override
  Future<File?> localFile(String p) async => null;
  @override
  File? downloadTarget(String p) => null;
  @override
  Future<void> importFile(String p, File s) async {}
  @override
  Future<void> offload(String p) async {}
}

void main() {
  late _Files files;
  late VideoCacheIndex index;
  var pending = <String>{};
  // Null: every file and kept path is referenced by a note.
  Set<String>? referenced;
  VideoCache cache() => VideoCache(
    files: files,
    index: index,
    pendingUploads: () async => pending,
    referencedPaths: () async =>
        referenced ?? {...files.sizes.keys, ...index.keptOffline},
    limitBytes: 100,
  );
  DateTime t(int n) => DateTime.fromMillisecondsSinceEpoch(n * 1000);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    index = VideoCacheIndex(await SharedPreferences.getInstance());
    files = _Files();
    pending = {};
    referenced = null;
  });

  test(
    'usage counts non-kept bytes as downloaded and kept separately',
    () async {
      files.sizes.addAll({'a.mov': 40, 'b.mov': 30, 'c.mov': 50});
      await index.setKept('c.mov', true);
      final u = await cache().usage();
      expect(u.downloadedBytes, 70);
      expect(u.keptCount, 1);
      expect(u.keptBytes, 50);
    },
  );

  test('usage ignores a kept path that has no file', () async {
    await index.setKept('gone.mov', true);
    final u = await cache().usage();
    expect(u.keptCount, 0);
    expect(u.downloadedBytes, 0);
  });

  test('evictToFit removes oldest-used first until under the limit', () async {
    files.sizes.addAll({'a.mov': 60, 'b.mov': 60, 'c.mov': 60});
    index.touch('a.mov', t(1));
    index.touch('b.mov', t(2));
    index.touch('c.mov', t(3));
    expect(await cache().evictToFit(), ['a.mov', 'b.mov']);
    expect(files.sizes.keys, ['c.mov']);
    expect(index.lastUsed('a.mov'), isNull);
  });

  test('evictToFit falls back to file modified time', () async {
    files.sizes.addAll({'a.mov': 60, 'b.mov': 60});
    files.modified['a.mov'] = t(5);
    files.modified['b.mov'] = t(1);
    expect(await cache().evictToFit(), ['b.mov']);
  });

  test('evictToFit never evicts kept or pending-upload paths', () async {
    files.sizes.addAll({'k.mov': 90, 'p.mov': 90});
    await index.setKept('k.mov', true);
    pending = {'p.mov'};
    expect(await cache().evictToFit(), isEmpty);
    expect(files.deleted, isEmpty);
  });

  test('evictToFit never evicts a protected path', () async {
    files.sizes.addAll({'a.mov': 60, 'b.mov': 60});
    index.touch('a.mov', t(1));
    index.touch('b.mov', t(2));
    expect(await cache().evictToFit(protect: {'b.mov'}), ['a.mov']);
  });

  test('clearDownloaded deletes non-kept, non-pending videos', () async {
    files.sizes.addAll({'a.mov': 10, 'b.mov': 20, 'k.mov': 30, 'p.mov': 40});
    await index.setKept('k.mov', true);
    pending = {'p.mov'};
    expect(await cache().clearDownloaded(), 30);
    expect(files.deleted, unorderedEquals(['a.mov', 'b.mov']));
  });

  test('sweepStaleParts returns the count', () async {
    expect(await cache().sweepStaleParts(), 3);
  });

  group('a kept path no note references is an ordinary download', () {
    test('usage counts it as downloaded, not kept', () async {
      files.sizes.addAll({'k.mov': 50, 'gone.mov': 30});
      await index.setKept('k.mov', true);
      await index.setKept('gone.mov', true);
      referenced = {'k.mov'};
      final u = await cache().usage();
      expect(u.keptCount, 1);
      expect(u.keptBytes, 50);
      expect(u.downloadedBytes, 30);
    });

    test('evictToFit may evict it; a referenced kept path stays', () async {
      files.sizes.addAll({'k.mov': 90, 'gone.mov': 90, 'a.mov': 60});
      await index.setKept('k.mov', true);
      await index.setKept('gone.mov', true);
      index.touch('gone.mov', t(1));
      index.touch('a.mov', t(2));
      referenced = {'k.mov', 'a.mov'};
      expect(await cache().evictToFit(), ['gone.mov']);
      expect(files.sizes.keys, unorderedEquals(['k.mov', 'a.mov']));
    });

    test('clearDownloaded clears it; a referenced kept path stays', () async {
      files.sizes.addAll({'k.mov': 30, 'gone.mov': 20});
      await index.setKept('k.mov', true);
      await index.setKept('gone.mov', true);
      referenced = {'k.mov'};
      expect(await cache().clearDownloaded(), 20);
      expect(files.deleted, ['gone.mov']);
    });
  });
}
