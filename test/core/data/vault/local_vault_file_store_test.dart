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
    store = LocalVaultStore(rootDir: Directory('${tmp.path}/vault'));
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
}
