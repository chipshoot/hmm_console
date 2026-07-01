import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/attachments/attachment_providers.dart';
import '../../../core/data/attachments/attachment_ref.dart';
import '../../../core/data/attachments/picker/file_byte_source.dart';
import '../../../core/data/attachments/picker/image_byte_source.dart';
import '../../../core/data/data_mode.dart';
import '../../../core/data/repository_providers.dart';
import '../domain/entities/service_record.dart';
import 'service_records_state.dart';

class MutateServiceRecordState extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<ServiceRecord?> create(int autoId, ServiceRecord record) async {
    state = const AsyncValue.loading();
    ServiceRecord? created;
    state = await AsyncValue.guard(() async {
      created = await ref
          .read(serviceRecordRepositoryModeProvider)
          .createRecord(autoId, record);
    });
    if (state.hasValue) _invalidate();
    return created;
  }

  Future<void> edit(int autoId, int id, ServiceRecord record) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref
        .read(serviceRecordRepositoryModeProvider)
        .updateRecord(autoId, id, record));
    if (state.hasValue) _invalidate();
  }

  /// Create-or-update a record together with its attachments.
  ///
  /// New records: the record is created first (to get the note id), then
  /// pending picks are persisted under that id, then the attachments column
  /// is written. Existing records: picks persist under the existing id and
  /// the column is rewritten with the merged set. Vault work is skipped in
  /// cloudApi (service records aren't note-vault addressable there).
  Future<void> save({
    required int autoId,
    required ServiceRecord record,
    required bool isEdit,
    List<PickedImageBytes> pendingImages = const [],
    List<PickedFileBytes> pendingFiles = const [],
    List<VaultRef> retained = const [],
    List<VaultRef> removed = const [],
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(serviceRecordRepositoryModeProvider);

      // 1. Ensure a note id exists.
      final ServiceRecord saved =
          isEdit ? record : await repo.createRecord(autoId, record);
      final noteId = saved.id;

      // 2. Persist pending picks + delete removed bytes (skip in cloudApi).
      final newRefs = <VaultRef>[];
      if (ref.read(dataModeProvider) != DataMode.cloudApi) {
        final picker = await ref.read(imageAttachmentPickerProvider.future);
        for (final img in pendingImages) {
          newRefs.add(await picker.persistToVault(
            noteId: noteId,
            bytes: img.bytes,
            originalName: img.originalName,
            contentTypeHint: img.contentType,
          ));
        }
        for (final f in pendingFiles) {
          newRefs.add(await picker.persistFileToVault(
            noteId: noteId,
            bytes: f.bytes,
            originalName: f.originalName,
            contentType: f.contentType ?? 'application/pdf',
          ));
        }
        if (removed.isNotEmpty) {
          final store = await ref.read(vaultStoreProvider.future);
          for (final r in removed) {
            await store.delete(r.path);
          }
        }
      }

      // 3. Assemble the merged attachment set (retained + new), split by type.
      bool isImage(VaultRef r) => r.contentType.startsWith('image/');
      final all = [...retained, ...newRefs];
      final attachments = NoteAttachments(
        images: all.where(isImage).toList(),
        files: all.where((r) => !isImage(r)).toList(),
      );

      // 4. Write the column. For a brand-new record with no attachments and
      //    nothing removed, the create in step 1 already persisted it.
      final needsWrite = isEdit || attachments.isNotEmpty || removed.isNotEmpty;
      if (needsWrite) {
        await repo.updateRecord(
            autoId, noteId, saved.copyWith(attachments: attachments));
      }
    });
    if (state.hasValue) _invalidate();
  }

  Future<void> delete(int autoId, int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() =>
        ref.read(serviceRecordRepositoryModeProvider).deleteRecord(autoId, id));
    if (state.hasValue) _invalidate();
  }

  void _invalidate() {
    ref.invalidate(serviceRecordsStateProvider);
  }
}

final mutateServiceRecordStateProvider =
    AsyncNotifierProvider<MutateServiceRecordState, void>(
  () => MutateServiceRecordState(),
);
