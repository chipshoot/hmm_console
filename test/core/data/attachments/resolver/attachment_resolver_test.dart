import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/resolver/attachment_resolver.dart';
import 'package:hmm_console/core/data/vault/local_vault_store.dart';

void main() {
  late Directory tmp;
  late LocalVaultStore store;
  late VaultResolver resolver;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('hmm_resolver_test_');
    store = LocalVaultStore(rootDir: tmp);
    resolver = VaultResolver(vaultStore: store);
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('VaultResolver', () {
    test('returns bytes for an existing VaultRef', () async {
      final bytes = Uint8List.fromList(List.generate(32, (i) => i));
      await store.putBytes('attachments/note-1/x.jpg', bytes);

      const ref = VaultRef(
        path: 'attachments/note-1/x.jpg',
        contentType: 'image/jpeg',
        byteSize: 32,
      );
      expect(await resolver.resolve(ref), equals(bytes));
    });

    test('returns null when the vault file is missing', () async {
      const ref = VaultRef(
        path: 'attachments/note-1/gone.jpg',
        contentType: 'image/jpeg',
        byteSize: 1,
      );
      expect(await resolver.resolve(ref), isNull);
    });

    test('returns null for non-vault kinds (v1)', () async {
      const phasset = PhAssetRef(id: 'PH-1', contentType: 'image/heic');
      const cloud = CloudFileRef(
        provider: CloudProvider.oneDrive,
        path: 'foo.jpg',
        contentType: 'image/jpeg',
      );
      expect(await resolver.resolve(phasset), isNull);
      expect(await resolver.resolve(cloud), isNull);
    });
  });

  group('CompositeAttachmentResolver', () {
    test('routes VaultRef to the vault resolver', () async {
      await store.putBytes(
        'attachments/note-1/a.jpg',
        Uint8List.fromList([1, 2, 3]),
      );
      final composite = CompositeAttachmentResolver(vault: resolver);

      const ref = VaultRef(
        path: 'attachments/note-1/a.jpg',
        contentType: 'image/jpeg',
        byteSize: 3,
      );
      expect(await composite.resolve(ref), equals([1, 2, 3]));
    });

    test('returns null for non-vault kinds when no resolver is wired',
        () async {
      final composite = CompositeAttachmentResolver(vault: resolver);
      const ref = PhAssetRef(id: 'PH-1', contentType: 'image/heic');
      expect(await composite.resolve(ref), isNull);
    });
  });
}
