import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/vault/local_vault_store.dart';
import 'package:hmm_console/core/data/vault/sensitive_path.dart';
import 'package:hmm_console/core/data/vault/vault_store.dart';

void main() {
  late Directory tmp;
  late LocalVaultStore store;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('vault_file_store_');
    store = LocalVaultStore(
      rootDir: Directory('${tmp.path}/vault'),
      offloadDir: Directory('${tmp.path}/offload'),
    );
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  File makeSource() =>
      File('${tmp.path}/src.mov')..writeAsBytesSync([1, 2, 3]);

  test('imports by moving and the source is gone', () async {
    final source = makeSource();
    await store.importFile('attachments/note-1/a.mov', source);
    expect(await store.getBytes('attachments/note-1/a.mov'), [1, 2, 3]);
    expect(source.existsSync(), isFalse);
    final entries = await store.list('');
    expect(entries, hasLength(1));
    expect(entries.single.relativePath.endsWith('.tmp'), isFalse);
  });

  test('localFile returns the file or null', () async {
    await store.importFile('attachments/note-1/a.mov', makeSource());
    expect((await store.localFile('attachments/note-1/a.mov'))!.lengthSync(),
        3);
    expect(await store.localFile('attachments/note-1/none.mov'), isNull);
  });

  test('refuses invalid and sensitive paths', () async {
    final source = makeSource();
    await expectLater(
        store.importFile('../x.mov', source), throwsArgumentError);
    await expectLater(
        store.importFile(
            buildSensitiveAttachmentPath(noteId: 1, ext: 'mov'), source),
        throwsArgumentError);
    expect(source.existsSync(), isTrue);
  });

  test('missing source throws VaultStoreException', () async {
    await expectLater(
        store.importFile(
            'attachments/note-1/a.mov', File('${tmp.path}/nope.mov')),
        throwsA(isA<VaultStoreException>()));
  });

  group('offload root', () {
    const path = 'attachments/note-1/u.mov';

    test('offload moves a video into the offload root', () async {
      await store.importFile(path, makeSource());
      await store.offload(path);
      final moved = File('${tmp.path}/offload/$path');
      expect(moved.readAsBytesSync(), [1, 2, 3]);
      expect(File('${tmp.path}/vault/$path').existsSync(), isFalse);
      await store.offload(path); // no-op when already there
      expect(moved.existsSync(), isTrue);
    });

    test('offloaded video is found, listed and deleted', () async {
      await store.importFile(path, makeSource());
      await store.offload(path);
      expect((await store.localFile(path))!.path, '${tmp.path}/offload/$path');
      expect(await store.exists(path), isTrue);
      final paths = (await store.list('')).map((e) => e.relativePath);
      expect(paths.where((e) => e == path), hasLength(1));
      await store.delete(path);
      expect(await store.exists(path), isFalse);
      expect(File('${tmp.path}/offload/$path').existsSync(), isFalse);
    });

    test('vault root wins when both roots have the file', () async {
      await store.importFile(path, makeSource());
      File('${tmp.path}/offload/$path')
        ..createSync(recursive: true)
        ..writeAsBytesSync([9]);
      expect((await store.localFile(path))!.path, '${tmp.path}/vault/$path');
    });

    test('a file in both roots is listed once and deleted from both',
        () async {
      await store.importFile(path, makeSource());
      final dup = File('${tmp.path}/offload/$path')
        ..createSync(recursive: true)
        ..writeAsBytesSync([9]);
      final paths = (await store.list('')).map((e) => e.relativePath);
      expect(paths.where((e) => e == path), hasLength(1));
      await store.delete(path);
      expect(File('${tmp.path}/vault/$path').existsSync(), isFalse);
      expect(dup.existsSync(), isFalse);
      expect(await store.exists(path), isFalse);
    });

    test('offload refuses a non-video path', () async {
      await expectLater(
        store.offload('attachments/note-1/a.jpg'),
        throwsArgumentError,
      );
    });

    test('offload of a missing file throws VaultStoreException', () async {
      await expectLater(
        store.offload(path),
        throwsA(isA<VaultStoreException>()),
      );
    });

    test('downloadTarget points into the offload root', () {
      expect(store.downloadTarget(path)!.path, '${tmp.path}/offload/$path');
      final bare = LocalVaultStore(rootDir: Directory('${tmp.path}/vault'));
      expect(bare.downloadTarget(path), isNull);
    });
  });
}
