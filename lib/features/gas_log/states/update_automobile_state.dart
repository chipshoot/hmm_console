import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/attachments/attachment_providers.dart';
import '../../../core/data/attachments/attachment_ref.dart';
import '../../../core/data/attachments/picker/file_byte_source.dart';
import '../../../core/data/attachments/picker/image_byte_source.dart';
import '../../../core/data/data_mode.dart';
import '../domain/entities/automobile.dart';
import '../states/automobiles_state.dart';
import '../usecases/update_automobile_usecase.dart';

class UpdateAutomobileState extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<void> updateAutomobile(
    int id,
    Automobile automobile, {
    List<PickedImageBytes> pendingImages = const [],
    List<PickedFileBytes> pendingFiles = const [],
    List<VaultRef> removed = const [],
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      // The vehicle already exists, so unlike the insurance create path there
      // is no chicken-and-egg over the note id: the vault path can be keyed
      // straight off it.
      final refs = await _persistPicks(id, pendingImages, pendingFiles);
      final merged =
          refs.isEmpty ? automobile : _withAttachments(automobile, refs);

      await ref.read(updateAutomobileUseCaseProvider).call(id, merged);

      // Only AFTER the write lands. Deleting first means a failed save leaves
      // the bytes gone while the stored note still lists their paths - an
      // attachment visible in the list that fails to open. Deleting late can
      // at worst orphan bytes, which wastes space; deleting early loses data.
      await _deleteRemoved(removed);

      ref.read(automobilesStateProvider.notifier).refresh();
    });
  }

  /// Writes picked bytes into the vault and returns their refs.
  ///
  /// Only touches the vault when there is real attachment work: initialising
  /// it can fail or stall, and a plain vehicle save must never report failure
  /// because of that. Skipped entirely in cloudApi, which has no vault.
  Future<List<VaultRef>> _persistPicks(
    int noteId,
    List<PickedImageBytes> images,
    List<PickedFileBytes> files,
  ) async {
    if (images.isEmpty && files.isEmpty) return const [];
    if (ref.read(dataModeProvider) == DataMode.cloudApi) return const [];

    final picker = await ref.read(imageAttachmentPickerProvider.future);
    final refs = <VaultRef>[];
    for (final img in images) {
      refs.add(await picker.persistToVault(
        noteId: noteId,
        bytes: img.bytes,
        originalName: img.originalName,
        contentTypeHint: img.contentType,
        // A registration scan carries the plate, the VIN and the owner's
        // address, so it goes in the encrypted vault like a licence does.
        sensitive: true,
      ));
    }
    for (final f in files) {
      refs.add(await picker.persistFileToVault(
        noteId: noteId,
        bytes: f.bytes,
        originalName: f.originalName,
        contentType: f.contentType ?? 'application/pdf',
        sensitive: true,
      ));
    }
    return refs;
  }

  Future<void> _deleteRemoved(List<VaultRef> removed) async {
    if (removed.isEmpty) return;
    if (ref.read(dataModeProvider) == DataMode.cloudApi) return;
    final store = await ref.read(vaultStoreProvider.future);
    for (final r in removed) {
      await store.delete(r.path);
    }
  }

  /// Splits refs by content type, the same rule the service-record and
  /// insurance paths use. `primaryImage` is left alone: the car photo owns
  /// that slot, and a scan must never be promoted into it.
  Automobile _withAttachments(Automobile auto, List<VaultRef> newRefs) {
    bool isImage(VaultRef r) => r.contentType.startsWith('image/');
    return auto.copyWith(
      images: [...auto.images, ...newRefs.where(isImage)],
      files: [...auto.files, ...newRefs.where((r) => !isImage(r))],
    );
  }
}

final updateAutomobileStateProvider =
    AsyncNotifierProvider<UpdateAutomobileState, void>(
  () => UpdateAutomobileState(),
);
