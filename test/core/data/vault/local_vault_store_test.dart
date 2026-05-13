import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/vault/local_vault_store.dart';
import 'package:hmm_console/core/data/vault/vault_store.dart';

Uint8List _bytes(String s) => Uint8List.fromList(s.codeUnits);

void main() {
  late Directory tmp;
  late LocalVaultStore store;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('hmm_vault_test_');
    store = LocalVaultStore(rootDir: tmp);
  });

  tearDown(() async {
    if (await tmp.exists()) {
      await tmp.delete(recursive: true);
    }
  });

  group('putBytes / getBytes / exists', () {
    test('round-trips bytes at a vault path', () async {
      final payload = _bytes('hello-vault');
      await store.putBytes('attachments/note-1/a.jpg', payload);

      expect(await store.exists('attachments/note-1/a.jpg'), isTrue);
      expect(await store.getBytes('attachments/note-1/a.jpg'),
          equals(payload));
    });

    test('creates the parent directory tree on first write', () async {
      await store.putBytes('attachments/note-42/x.png', _bytes('x'));
      final dir = Directory(
        '${tmp.path}${Platform.pathSeparator}attachments'
        '${Platform.pathSeparator}note-42',
      );
      expect(await dir.exists(), isTrue);
    });

    test('overwrites an existing file', () async {
      await store.putBytes('attachments/note-1/x.jpg', _bytes('old'));
      await store.putBytes('attachments/note-1/x.jpg', _bytes('new'));
      expect(await store.getBytes('attachments/note-1/x.jpg'),
          equals(_bytes('new')));
    });

    test('leaves no .tmp residue after a successful write', () async {
      await store.putBytes('attachments/note-1/a.jpg', _bytes('payload'));
      final dir = Directory(
        '${tmp.path}${Platform.pathSeparator}attachments'
        '${Platform.pathSeparator}note-1',
      );
      final entries = await dir.list().toList();
      // Should be exactly one file (a.jpg); no a.jpg.tmp left over.
      expect(entries.length, equals(1));
      expect(entries.single.path.endsWith('.jpg'), isTrue);
    });

    test('getBytes throws VaultStoreException for a missing file', () async {
      expect(
        () => store.getBytes('attachments/note-1/missing.jpg'),
        throwsA(isA<VaultStoreException>()),
      );
    });

    test('exists returns false for a missing file', () async {
      expect(await store.exists('attachments/note-1/missing.jpg'), isFalse);
    });
  });

  group('delete', () {
    test('removes an existing file', () async {
      await store.putBytes('attachments/note-1/a.jpg', _bytes('x'));
      await store.delete('attachments/note-1/a.jpg');
      expect(await store.exists('attachments/note-1/a.jpg'), isFalse);
    });

    test('succeeds silently for a missing file', () async {
      // No exception expected.
      await store.delete('attachments/note-1/missing.jpg');
    });
  });

  group('list', () {
    test('empty prefix returns every file under the root', () async {
      await store.putBytes('attachments/note-1/a.jpg', _bytes('a'));
      await store.putBytes('attachments/note-1/b.jpg', _bytes('bb'));
      await store.putBytes('attachments/note-2/c.jpg', _bytes('ccc'));

      final all = await store.list('');
      expect(all.map((e) => e.relativePath).toList(),
          equals([
            'attachments/note-1/a.jpg',
            'attachments/note-1/b.jpg',
            'attachments/note-2/c.jpg',
          ]));
      expect(all.firstWhere((e) => e.relativePath.endsWith('b.jpg')).byteSize,
          equals(2));
    });

    test('folder prefix returns only entries beneath it', () async {
      await store.putBytes('attachments/note-1/a.jpg', _bytes('a'));
      await store.putBytes('attachments/note-2/b.jpg', _bytes('b'));

      final note1 = await store.list('attachments/note-1');
      expect(note1.length, equals(1));
      expect(note1.single.relativePath, equals('attachments/note-1/a.jpg'));
    });

    test('file prefix returns that single entry', () async {
      await store.putBytes('attachments/note-1/a.jpg', _bytes('hello'));
      final single = await store.list('attachments/note-1/a.jpg');
      expect(single.length, equals(1));
      expect(single.single,
          equals(const VaultEntry(
              relativePath: 'attachments/note-1/a.jpg', byteSize: 5)));
    });

    test('non-existent prefix returns an empty list', () async {
      final empty = await store.list('attachments/note-99');
      expect(empty, isEmpty);
    });

    test('skips half-written .tmp files', () async {
      // Manually drop a .tmp file (simulating an interrupted write).
      final dir = Directory(
        '${tmp.path}${Platform.pathSeparator}attachments'
        '${Platform.pathSeparator}note-1',
      );
      await dir.create(recursive: true);
      final tmpFile = File('${dir.path}${Platform.pathSeparator}a.jpg.tmp');
      await tmpFile.writeAsBytes(_bytes('partial'));
      await store.putBytes('attachments/note-1/a.jpg', _bytes('full'));

      final entries = await store.list('attachments/note-1');
      expect(entries.length, equals(1));
      expect(entries.single.relativePath, equals('attachments/note-1/a.jpg'));
    });
  });

  group('input validation', () {
    test('putBytes rejects invalid paths', () async {
      expect(
        () => store.putBytes('../escape.jpg', _bytes('x')),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => store.putBytes('/leading-slash.jpg', _bytes('x')),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('getBytes rejects invalid paths', () async {
      expect(
        () => store.getBytes('foo/../bar.jpg'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('list rejects invalid non-empty prefixes', () async {
      expect(
        () => store.list('../escape'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('list accepts the empty prefix', () async {
      // Even on a fresh empty vault.
      expect(await store.list(''), isEmpty);
    });
  });
}
