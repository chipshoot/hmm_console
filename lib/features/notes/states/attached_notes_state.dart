import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/repository_providers.dart';
import '../data/general_catalog.dart';
import '../data/models/hmm_note.dart';

/// General notes attached to a given parent note (an entity or a subsystem
/// anchor). The list the AttachedNotesSection renders.
final attachedNotesProvider =
    FutureProvider.family<List<HmmNote>, int>((ref, parentId) async {
  final general = await ensureGeneralCatalog(ref);
  final page = await ref.read(hmmNoteRepositoryProvider).getNotes(
        parentNoteId: parentId,
        catalogId: general.id,
        pageSize: 500,
      );
  return page.items;
});
