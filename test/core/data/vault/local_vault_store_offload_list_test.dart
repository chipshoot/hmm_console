import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/vault/local_vault_store.dart';

void main() {
  late Directory tmp;
  late Directory root;
  late Directory off;
  late LocalVaultStore store;

  File put(Directory d, String rel, List<int> bytes) {
    final f = File('${d.path}/$rel')..createSync(recursive: true);
    f.writeAsBytesSync(bytes);
    return f;
  }

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('vault_offload_list_');
    root = Directory('${tmp.path}/vault');
    off = Directory('${tmp.path}/offload');
    store = LocalVaultStore(rootDir: root, offloadDir: off);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test(
    'listOffloaded lists only video files in the offload home, with sizes',
    () async {
      put(off, 'attachments/n/a.mov', [1, 2, 3]);
      put(off, 'attachments/n/b.jpg', [1]);
      put(off, 'attachments/n/c.mov.part', [1]);
      put(root, 'attachments/n/d.mov', [1, 2]);
      final list = await store.listOffloaded();
      expect(list.map((e) => e.relativePath), ['attachments/n/a.mov']);
      expect(list.single.byteSize, 3);
    },
  );

  test('listOffloaded is empty with no offload root', () async {
    final s = LocalVaultStore(rootDir: root);
    expect(await s.listOffloaded(), isEmpty);
  });

  test(
    'deleteOffloaded removes the offload copy and never the root copy',
    () async {
      final r = put(root, 'attachments/n/a.mov', [1]);
      final o = put(off, 'attachments/n/a.mov', [1]);
      await store.deleteOffloaded('attachments/n/a.mov');
      expect(r.existsSync(), isTrue);
      expect(o.existsSync(), isFalse);
    },
  );

  test(
    'deleteStaleParts deletes only .part files in the offload home',
    () async {
      final part = put(off, 'attachments/n/a.mov.part', [1]);
      final mov = put(off, 'attachments/n/a.mov', [1]);
      expect(await store.deleteStaleParts(), 1);
      expect(part.existsSync(), isFalse);
      expect(mov.existsSync(), isTrue);
    },
  );
}
