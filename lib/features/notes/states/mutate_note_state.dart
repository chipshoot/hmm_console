import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/attachments/attachment_ref.dart';
import '../../../core/data/attachments/attachment_providers.dart';
import '../../../core/data/attachments/picker/image_attachment_picker.dart';
import '../../../core/data/hmm_note_input.dart';
import '../../../core/data/repository_providers.dart';
import '../data/general_catalog.dart';
import '../data/models/hmm_note.dart';
import 'notes_list_state.dart';

class MutateNote {
  MutateNote(this.ref);
  final Ref ref;

  Future<HmmNote> createGeneral({
    required String subject,
    String? markdownBody,
  }) async {
    final catalog = await ensureGeneralCatalog(ref);
    final note = await ref.read(hmmNoteRepositoryProvider).createNote(
          HmmNoteCreate(
            subject: subject.trim(),
            catalogId: catalog.id,
            content: markdownBody,
          ),
        );
    ref.invalidate(notesListStateProvider);
    return note;
  }

  Future<HmmNote> updateGeneral(
    int id, {
    String? subject,
    String? markdownBody,
  }) async {
    final note = await ref.read(hmmNoteRepositoryProvider).updateNote(
          id,
          HmmNoteUpdate(subject: subject?.trim(), content: markdownBody),
        );
    ref.invalidate(notesListStateProvider);
    return note;
  }

  Future<void> delete(int id) async {
    await ref.read(hmmNoteRepositoryProvider).deleteNote(id);
    ref.invalidate(notesListStateProvider);
  }

  /// Picks an image for [noteId] (which must already exist), appends it, and
  /// persists. Returns null if the user cancels.
  Future<HmmNote?> addImage(
    int noteId, {
    AttachmentPickSource source = AttachmentPickSource.gallery,
  }) async {
    final picker = await ref.read(imageAttachmentPickerProvider.future);
    final VaultRef? picked =
        await picker.pickForNote(noteId: noteId, source: source);
    if (picked == null) return null;

    final repo = ref.read(hmmNoteRepositoryProvider);
    final current = await repo.getNoteById(noteId);
    if (current == null) return null;
    final existing = current.effectiveAttachments;
    final updated = NoteAttachments(
      primaryImage: existing.primaryImage ?? picked,
      images: existing.primaryImage == null
          ? existing.images
          : [...existing.images, picked],
    );
    final note =
        await repo.updateNote(noteId, HmmNoteUpdate(attachments: updated));
    ref.invalidate(notesListStateProvider);
    return note;
  }
}

final mutateNoteProvider = Provider<MutateNote>((ref) => MutateNote(ref));
