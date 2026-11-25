import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/picker/image_attachment_picker.dart';
import 'package:hmm_console/core/data/attachments/picker/image_byte_source.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';
import 'package:hmm_console/features/contacts/states/contact_edit_state.dart';

import '../data/contact_repository_fakes.dart';

const _new = Contact(id: '', contactType: ContactType.person, firstName: 'Ann');

const _stored = VaultRef(
  path: 'n/1/old.jpg',
  contentType: 'image/jpeg',
  byteSize: 5,
);

class _FakeBytes implements ImageByteSource {
  _FakeBytes(this.result);
  final PickedImageBytes? result;
  @override
  Future<PickedImageBytes?> pick(AttachmentPickSource source) async => result;
}

class _FakePicker implements IImageAttachmentPicker {
  final calls = <int>[];
  Object? throwOnce;
  @override
  Future<VaultRef> persistToVault({
    required int noteId,
    required Uint8List bytes,
    required String originalName,
    String? contentTypeHint,
    bool sensitive = false,
  }) async {
    calls.add(noteId);
    final t = throwOnce;
    if (t != null) {
      throwOnce = null;
      throw t;
    }
    return VaultRef(
      path: 'n/$noteId/$originalName',
      contentType: 'image/jpeg',
      byteSize: bytes.length,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not faked');
}

final _picked = PickedImageBytes(
  bytes: Uint8List.fromList([1, 2, 3]),
  originalName: 'face.jpg',
  contentType: 'image/jpeg',
);

ProviderContainer _container(
  InMemoryContactRepository repo,
  _FakePicker picker, {
  PickedImageBytes? pick,
}) {
  final c = ProviderContainer(
    overrides: [
      contactRepositoryModeProvider.overrideWithValue(repo),
      imageByteSourceProvider.overrideWithValue(_FakeBytes(pick)),
      imageAttachmentPickerProvider.overrideWith((ref) async => picker),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test(
    'photo picked on a new contact is persisted after the first save',
    () async {
      final repo = InMemoryContactRepository();
      final picker = _FakePicker();
      final c = _container(repo, picker, pick: _picked);
      final n = c.read(contactEditStateProvider(_new).notifier);

      await n.pickPhoto(AttachmentPickSource.gallery);
      expect(c.read(contactEditStateProvider(_new)).pendingPhoto, _picked);
      expect(n.hasPhoto, isTrue);
      expect(await n.save(), isTrue);

      final saved = (await repo.getContacts()).single;
      expect(picker.calls, [await repo.noteIdFor(saved.id)]);
      expect((saved.photo! as VaultRef).path, endsWith('face.jpg'));
    },
  );

  test('cancelled pick changes nothing', () async {
    final repo = InMemoryContactRepository();
    final picker = _FakePicker();
    final c = _container(repo, picker);
    final n = c.read(contactEditStateProvider(_new).notifier);

    await n.pickPhoto(AttachmentPickSource.camera);
    expect(c.read(contactEditStateProvider(_new)).pendingPhoto, isNull);
    expect(await n.save(), isTrue);
    expect((await repo.getContacts()).single.photo, isNull);
    expect(picker.calls, isEmpty);
  });

  test('removePhoto clears the stored photo on save', () async {
    final repo = InMemoryContactRepository();
    const existing = Contact(
      id: 'c1',
      contactType: ContactType.person,
      firstName: 'Ann',
      photo: _stored,
    );
    repo.seed(existing);
    final c = _container(repo, _FakePicker());
    final n = c.read(contactEditStateProvider(existing).notifier);

    expect(n.hasPhoto, isTrue);
    n.removePhoto();
    expect(c.read(contactEditStateProvider(existing)).photoRemoved, isTrue);
    expect(n.hasPhoto, isFalse);
    expect(await n.save(), isTrue);
    expect((await repo.getContact('c1'))!.photo, isNull);
  });

  test(
    'save without touching the photo keeps it and never calls the picker',
    () async {
      final repo = InMemoryContactRepository();
      const existing = Contact(
        id: 'c1',
        contactType: ContactType.person,
        firstName: 'Ann',
        photo: _stored,
      );
      repo.seed(existing);
      final picker = _FakePicker();
      final c = _container(repo, picker);
      final n = c.read(contactEditStateProvider(existing).notifier);

      n.setFirstName('Anna');
      expect(await n.save(), isTrue);
      final saved = (await repo.getContact('c1'))!;
      expect(saved.firstName, 'Anna');
      expect(saved.photo, _stored);
      expect(picker.calls, isEmpty);
    },
  );

  test(
    'a failed photo store, then retry, does not duplicate a new contact',
    () async {
      final repo = InMemoryContactRepository();
      final picker = _FakePicker()..throwOnce = StateError('disk full');
      final c = _container(repo, picker, pick: _picked);
      final n = c.read(contactEditStateProvider(_new).notifier);

      await n.pickPhoto(AttachmentPickSource.gallery);
      await expectLater(n.save(), throwsStateError);
      expect(await n.save(), isTrue);

      final all = await repo.getContacts();
      expect(all, hasLength(1));
      expect(all.single.photo, isNotNull);
    },
  );
}
