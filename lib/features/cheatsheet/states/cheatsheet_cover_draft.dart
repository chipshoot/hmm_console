import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/attachments/attachment_ref.dart';
import '../../../core/data/attachments/picker/image_byte_source.dart';

/// The designer's unsaved cover changes, kept beside the card being edited
/// because neither belongs in the card: [pending] has no vault path until the
/// save writes it, and [released] are covers this edit dropped — deleted only
/// after the save lands (see `CheatsheetsState.save`).
class CoverDraft {
  const CoverDraft({this.pending, this.released = const []});

  final PickedImageBytes? pending;
  final List<VaultRef> released;
}

class CheatsheetCoverDraft extends Notifier<CoverDraft> {
  @override
  CoverDraft build() => const CoverDraft();

  void clear() => state = const CoverDraft();

  void stage(PickedImageBytes pick) =>
      state = CoverDraft(pending: pick, released: state.released);

  void dropPending() => state = CoverDraft(released: state.released);

  void release(VaultRef cover) => state = CoverDraft(
    pending: state.pending,
    released: [...state.released, cover],
  );
}

final cheatsheetCoverDraftProvider =
    NotifierProvider<CheatsheetCoverDraft, CoverDraft>(
      CheatsheetCoverDraft.new,
    );
