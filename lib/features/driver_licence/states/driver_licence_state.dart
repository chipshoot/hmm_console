import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/attachments/attachment_providers.dart';
import '../../../core/data/attachments/attachment_ref.dart';
import '../../../core/data/attachments/picker/image_byte_source.dart';
import '../../../core/data/data_mode.dart';
import '../../../core/data/repository_providers.dart';
import '../domain/driver_licence.dart';

/// Reads and writes the single licence, and owns the vault work.
///
/// The repository is pure persistence, so picking bytes, writing them to the
/// vault and deleting removed ones happens here — the same split insurance and
/// service records use.
class DriverLicenceState extends AsyncNotifier<DriverLicence?> {
  /// Guards against a double-tapped save. A second tap while the first is in
  /// flight has created duplicate records in this codebase before, and here it
  /// would also persist the same image bytes twice, orphaning the first copy.
  bool _saving = false;

  @override
  Future<DriverLicence?> build() =>
      ref.watch(driverLicenceRepositoryModeProvider).getLicence();

  Future<void> save(
    DriverLicence licence, {
    PickedImageBytes? newFront,
    PickedImageBytes? newBack,
    List<VaultRef> removed = const [],
  }) async {
    if (_saving) return;
    _saving = true;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(driverLicenceRepositoryModeProvider);

      // Vault paths are keyed by note id, so on a first save with images the
      // note has to exist before the bytes can be written. Details first, then
      // images, then one more write to record their paths.
      var id = await repo.noteId();
      if (id == null && (newFront != null || newBack != null)) {
        await repo.saveLicence(licence);
        id = await repo.noteId();
      }

      var next = licence;
      if (id != null && (newFront != null || newBack != null)) {
        final front =
            newFront == null ? licence.frontImage : await _persist(id, newFront);
        final back =
            newBack == null ? licence.backImage : await _persist(id, newBack);
        // Constructed directly: DriverLicence has no copyWith, because
        // `field ?? this.field` could not express clearing one.
        next = DriverLicence(
          number: licence.number,
          licenceClass: licence.licenceClass,
          jurisdiction: licence.jurisdiction,
          issuedDate: licence.issuedDate,
          expiryDate: licence.expiryDate,
          frontImage: front,
          backImage: back,
          extraFields: licence.extraFields,
        );
      }

      await repo.saveLicence(next);

      // Only AFTER the write lands. Deleting first means a failed save leaves
      // the bytes gone while the note still lists their paths — an image the
      // licence claims to have that cannot be opened.
      await _deleteRemoved(removed);

      return next;
    });
    _saving = false;
  }

  /// Both sides are stored `sensitive: true`, so they land in the encrypted
  /// vault behind the local-auth gate rather than beside ordinary photos.
  Future<VaultRef> _persist(int noteId, PickedImageBytes pick) async {
    final picker = await ref.read(imageAttachmentPickerProvider.future);
    return picker.persistToVault(
      noteId: noteId,
      bytes: pick.bytes,
      originalName: pick.originalName,
      contentTypeHint: pick.contentType,
      sensitive: true,
    );
  }

  Future<void> _deleteRemoved(List<VaultRef> removed) async {
    if (removed.isEmpty) return;
    if (ref.read(dataModeProvider) == DataMode.cloudApi) return;
    final store = await ref.read(vaultStoreProvider.future);
    for (final r in removed) {
      await store.delete(r.path);
    }
  }
}

final driverLicenceStateProvider =
    AsyncNotifierProvider<DriverLicenceState, DriverLicence?>(
  () => DriverLicenceState(),
);
