import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/attachments/attachment_providers.dart';
import '../../../core/data/attachments/attachment_ref.dart';
import '../../../core/data/attachments/picker/file_byte_source.dart';
import '../../../core/data/attachments/picker/image_byte_source.dart';
import '../../../core/data/data_mode.dart';
import '../../../core/data/repository_providers.dart';
import '../domain/entities/auto_insurance_policy.dart';
import 'insurance_policies_state.dart';

/// Tracks the in-flight create / edit / delete operation for insurance
/// policies. Screens listen to this to drive snackbars / loading
/// indicators. After every successful mutation we invalidate the list
/// state for the affected automobile so it refetches.
class MutateInsurancePolicyState extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<AutoInsurancePolicy?> create(
    int autoId,
    AutoInsurancePolicy policy, {
    List<PickedImageBytes> pendingImages = const [],
    List<PickedFileBytes> pendingFiles = const [],
  }) async {
    state = const AsyncValue.loading();
    AutoInsurancePolicy? created;
    state = await AsyncValue.guard(() async {
      final saved = await ref
          .read(insuranceRepositoryModeProvider)
          .createPolicy(autoId, policy);

      // Two phases, because a vault path is keyed by the note id and the
      // policy has none until it is written.
      final refs = await _persistPicks(saved.id, pendingImages, pendingFiles);
      if (refs.isEmpty) {
        created = saved;
        return;
      }

      final withFiles = _withAttachments(saved, refs);
      await ref
          .read(insuranceRepositoryModeProvider)
          .updatePolicy(autoId, saved.id, withFiles);
      created = withFiles;
    });
    if (state.hasValue) _invalidate();
    return created;
  }

  Future<void> edit(
    int autoId,
    int id,
    AutoInsurancePolicy policy, {
    List<PickedImageBytes> pendingImages = const [],
    List<PickedFileBytes> pendingFiles = const [],
    List<VaultRef> removed = const [],
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final refs = await _persistPicks(id, pendingImages, pendingFiles);
      await _deleteRemoved(removed);

      // policy.attachments already holds whatever the form retained, so new
      // picks are appended rather than replacing the set.
      final merged = refs.isEmpty ? policy : _withAttachments(policy, refs);
      await ref
          .read(insuranceRepositoryModeProvider)
          .updatePolicy(autoId, id, merged);
    });
    if (state.hasValue) _invalidate();
  }

  /// Writes picked bytes into the vault and returns their refs.
  ///
  /// Only touches the vault when there is real attachment work: initialising
  /// it can fail or stall, and a plain policy save must never report failure
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
      ));
    }
    for (final f in files) {
      refs.add(await picker.persistFileToVault(
        noteId: noteId,
        bytes: f.bytes,
        originalName: f.originalName,
        contentType: f.contentType ?? 'application/pdf',
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

  /// Splits refs by content type, the same rule the service-record path uses.
  AutoInsurancePolicy _withAttachments(
    AutoInsurancePolicy p,
    List<VaultRef> newRefs,
  ) {
    bool isImage(VaultRef r) => r.contentType.startsWith('image/');
    final all = <VaultRef>[
      ...p.attachments.images.whereType<VaultRef>(),
      ...p.attachments.files.whereType<VaultRef>(),
      ...newRefs,
    ];
    return AutoInsurancePolicy(
      id: p.id,
      automobileId: p.automobileId,
      provider: p.provider,
      policyNumber: p.policyNumber,
      effectiveDate: p.effectiveDate,
      expiryDate: p.expiryDate,
      premium: p.premium,
      currency: p.currency,
      deductible: p.deductible,
      coverage: p.coverage,
      notes: p.notes,
      isActive: p.isActive,
      contacts: p.contacts,
      createdDate: p.createdDate,
      lastModifiedDate: p.lastModifiedDate,
      attachments: NoteAttachments(
        images: all.where(isImage).toList(),
        files: all.where((r) => !isImage(r)).toList(),
      ),
    );
  }

  Future<void> delete(int autoId, int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
        () => ref.read(insuranceRepositoryModeProvider).deletePolicy(autoId, id));
    if (state.hasValue) _invalidate();
  }

  void _invalidate() {
    ref.invalidate(insurancePoliciesStateProvider);
    ref.invalidate(activeInsurancePolicyStateProvider);
  }
}

final mutateInsurancePolicyStateProvider =
    AsyncNotifierProvider<MutateInsurancePolicyState, void>(
  () => MutateInsurancePolicyState(),
);
