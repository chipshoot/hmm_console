// Tests target persistToVault, the pure-ish path the picker takes
// after pickImage hands us bytes. Driving image_picker itself
// requires a platform channel — that's covered by manual smoke
// testing on the simulator.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/picker/image_attachment_picker.dart';
import 'package:hmm_console/core/data/vault/local_vault_store.dart';

Uint8List _bytes(int n) => Uint8List.fromList(List<int>.filled(n, 0x42));

void main() {
  late Directory tmp;
  late LocalVaultStore store;
  late VaultImageAttachmentPicker picker;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('hmm_picker_test_');
    store = LocalVaultStore(rootDir: tmp);
    picker = VaultImageAttachmentPicker(vaultStore: store);
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('persistToVault writes bytes and returns a VaultRef', () async {
    final payload = _bytes(64);
    final ref = await picker.persistToVault(
      noteId: 7,
      bytes: payload,
      originalName: 'photo.jpg',
    );

    expect(ref.path, startsWith('attachments/note-7/'));
    expect(ref.path, endsWith('.jpg'));
    expect(ref.contentType, equals('image/jpeg'));
    expect(ref.byteSize, equals(64));
    expect(ref.originalName, equals('photo.jpg'));

    // Bytes are actually on disk under the vault root.
    expect(await store.exists(ref.path), isTrue);
    expect(await store.getBytes(ref.path), equals(payload));
  });

  test('returned path is unique on each call (UUID stamping)', () async {
    final a = await picker.persistToVault(
      noteId: 1,
      bytes: _bytes(8),
      originalName: 'x.png',
    );
    final b = await picker.persistToVault(
      noteId: 1,
      bytes: _bytes(8),
      originalName: 'x.png',
    );
    expect(a.path, isNot(equals(b.path)));
  });

  test('content-type hint is honoured when allow-listed', () async {
    final ref = await picker.persistToVault(
      noteId: 1,
      bytes: _bytes(8),
      originalName: 'no-extension',
      contentTypeHint: 'image/heic',
    );
    expect(ref.contentType, equals('image/heic'));
    expect(ref.path, endsWith('.heic'));
  });

  test('extension wins over a vague hint like "image/*"', () async {
    final ref = await picker.persistToVault(
      noteId: 1,
      bytes: _bytes(8),
      originalName: 'kitten.webp',
      contentTypeHint: 'image/*', // image_picker on Android sometimes does this
    );
    expect(ref.contentType, equals('image/webp'));
  });

  test('rejects an empty file', () async {
    expect(
      () => picker.persistToVault(
        noteId: 1,
        bytes: Uint8List(0),
        originalName: 'empty.jpg',
      ),
      throwsA(isA<AttachmentPickerException>()),
    );
  });

  test('rejects a file over the size cap', () async {
    final oversized = Uint8List(kMaxAttachmentBytes + 1);
    expect(
      () => picker.persistToVault(
        noteId: 1,
        bytes: oversized,
        originalName: 'big.jpg',
      ),
      throwsA(isA<AttachmentPickerException>()),
    );
  });

  test('rejects an unsupported type', () async {
    expect(
      () => picker.persistToVault(
        noteId: 1,
        bytes: _bytes(8),
        originalName: 'noisy.bmp',
      ),
      throwsA(isA<AttachmentPickerException>()),
    );
  });

  test('originalName collapses to null when empty', () async {
    final ref = await picker.persistToVault(
      noteId: 1,
      bytes: _bytes(8),
      originalName: '',
      contentTypeHint: 'image/jpeg',
    );
    expect(ref.originalName, isNull);
  });

  test('persistToVault(sensitive: true) writes a sensitive/-segment path '
      'and returns VaultRef.sensitive == true', () async {
    final payload = _bytes(64);
    final ref = await picker.persistToVault(
      noteId: 7,
      bytes: payload,
      originalName: 'photo.jpg',
      sensitive: true,
    );

    expect(ref.path, startsWith('attachments/note-7/sensitive/'));
    expect(ref.path, endsWith('.jpg'));
    expect(ref.sensitive, isTrue);
    expect(await store.exists(ref.path), isTrue);
    expect(await store.getBytes(ref.path), equals(payload));
  });

  test('non-sensitive path is unchanged (no sensitive segment, '
      'sensitive == false)', () async {
    final ref = await picker.persistToVault(
      noteId: 7,
      bytes: _bytes(8),
      originalName: 'photo.jpg',
    );

    expect(ref.path, isNot(contains('/sensitive/')));
    expect(ref.sensitive, isFalse);
  });
}
