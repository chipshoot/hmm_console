import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/picker/image_attachment_picker.dart';
import 'package:hmm_console/core/data/attachments/picker/image_byte_source.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_cheatsheet_repository.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/core/data/vault/vault_gc.dart';
import 'package:hmm_console/core/data/vault/vault_store.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
import 'package:hmm_console/features/cheatsheet/states/cheatsheets_state.dart';

class _MemVault implements IVaultStore {
  final files = <String, Uint8List>{};

  @override
  Future<void> putBytes(String relativePath, Uint8List bytes,
      {String? contentType}) async {
    files[relativePath] = bytes;
  }

  @override
  Future<Uint8List> getBytes(String relativePath) async {
    final b = files[relativePath];
    if (b == null) throw VaultStoreException('missing', relativePath);
    return b;
  }

  @override
  Future<bool> exists(String relativePath) async =>
      files.containsKey(relativePath);

  @override
  Future<void> delete(String relativePath) async {
    files.remove(relativePath);
  }

  @override
  Future<List<VaultEntry>> list(String prefix) async => [
        for (final e in files.entries)
          if (e.key.startsWith(prefix))
            VaultEntry(relativePath: e.key, byteSize: e.value.length),
      ]..sort((a, b) => a.relativePath.compareTo(b.relativePath));
}

class _Mode extends DataModeNotifier {
  _Mode(this.mode);
  final DataMode mode;
  @override
  DataMode build() => mode;
}

/// A vault store that must never be touched.
class _NoVault implements IVaultStore {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('vault touched: ${invocation.memberName}');
}

void main() {
  late HmmDatabase db;
  late LocalCheatsheetRepository repo;
  late _MemVault vault;

  final png = Uint8List.fromList(List<int>.generate(64, (i) => i));
  PickedImageBytes pick() =>
      PickedImageBytes(bytes: png, originalName: 'c.png', contentType: 'image/png');

  const plain = CheatsheetCard(
    id: 'c1',
    title: 'Claim',
    walletGroup: 'Vehicle',
    tags: [],
    templateId: 'accidentClaim',
    rows: [],
  );

  setUp(() async {
    db = HmmDatabase(NativeDatabase.memory());
    final aid = await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'state-cover'));
    final author = await (db.select(db.authors)..where((a) => a.id.equals(aid)))
        .getSingle();
    final notes = LocalHmmNoteRepository(db, () async => author);
    repo = LocalCheatsheetRepository(notes, LocalNoteCatalogRepository(db));
    vault = _MemVault();
  });

  tearDown(() async => db.close());

  ProviderContainer container({
    DataMode mode = DataMode.local,
    IVaultStore? store,
  }) {
    final s = store ?? vault;
    final c = ProviderContainer(overrides: [
      cheatsheetRepositoryModeProvider.overrideWithValue(repo),
      dataModeProvider.overrideWith(() => _Mode(mode)),
      vaultStoreProvider.overrideWith((ref) async => s),
      imageAttachmentPickerProvider.overrideWith(
          (ref) async => VaultImageAttachmentPicker(vaultStore: s)),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('a new card with a cover: bytes in the vault, ref in the column',
      () async {
    final c = container();
    await c.read(cheatsheetsStateProvider.notifier).save(plain, newCover: pick());

    final saved = (await repo.getCard('c1'))!;
    final ref = saved.cover!;
    expect(ref.path, startsWith('attachments/note-'));
    expect(ref.sensitive, isFalse);
    expect(vault.files.keys, [ref.path]);
    expect(await collectReferencedVaultPaths(db), {ref.path});
    expect(saved.style.coverPath, ref.path);
  });

  test('replacing a cover deletes the old bytes after the save', () async {
    final c = container();
    final state = c.read(cheatsheetsStateProvider.notifier);
    await state.save(plain, newCover: pick());
    final first = (await repo.getCard('c1'))!;

    await state.save(first.withCover(null),
        newCover: pick(), released: [first.cover!]);

    final second = (await repo.getCard('c1'))!.cover!;
    expect(second.path, isNot(first.cover!.path));
    expect(vault.files.keys, [second.path]);
    expect(await collectReferencedVaultPaths(db), {second.path});
  });

  test('removing a cover releases the attachment and deletes its bytes',
      () async {
    final c = container();
    final state = c.read(cheatsheetsStateProvider.notifier);
    await state.save(plain, newCover: pick());
    final withCover = (await repo.getCard('c1'))!;

    await state.save(withCover.withCover(null), released: [withCover.cover!]);

    expect(vault.files, isEmpty);
    expect(await collectReferencedVaultPaths(db), isEmpty);
  });

  test('removing a card deletes its cover bytes', () async {
    final c = container();
    final state = c.read(cheatsheetsStateProvider.notifier);
    await state.save(plain, newCover: pick());

    await state.remove('c1');

    expect(vault.files, isEmpty);
    expect(await collectReferencedVaultPaths(db), isEmpty);
    expect(await repo.getCard('c1'), isNull);
  });

  test('a protected card stores its cover as sensitive', () async {
    final c = container();
    await c
        .read(cheatsheetsStateProvider.notifier)
        .save(plain.copyWith(protected: true), newCover: pick());
    expect((await repo.getCard('c1'))!.cover!.sensitive, isTrue);
  });

  test('cloudApi mode never deletes vault bytes', () async {
    const stale = VaultRef(
      path: 'attachments/note-1/old.jpg',
      contentType: 'image/jpeg',
      byteSize: 3,
    );
    vault.files[stale.path] = Uint8List(3);
    final c = container(mode: DataMode.cloudApi);

    await c
        .read(cheatsheetsStateProvider.notifier)
        .save(plain, released: const [stale]);

    expect(vault.files.keys, [stale.path]);
  });

  test('a card without a cover never touches the vault', () async {
    final c = container(store: _NoVault());
    final state = c.read(cheatsheetsStateProvider.notifier);
    await state.save(plain);
    await state.remove('c1');
    expect(await repo.getCard('c1'), isNull);
  });
}
