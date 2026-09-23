import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/repository_providers.dart';
import '../data/general_catalog.dart';
import '../data/models/hmm_note.dart';

/// General notes attached to a given parent note (an entity or a subsystem
/// anchor). The list the AttachedNotesSection renders.
///
/// autoDispose: nothing streams this, so it only refreshes where a mutation
/// explicitly invalidates it (e.g. detaching a note here). Deleting the note
/// from elsewhere — the notes list, note detail — has no such invalidation,
/// so a stale count (e.g. the hub's badge) would otherwise persist for the
/// whole session. autoDispose recovers it: once nothing watches this family
/// member (the screen showing it is left), it drops its cached value and
/// re-fetches on the next watch.
final attachedNotesProvider = FutureProvider.autoDispose
    .family<List<HmmNote>, int>((ref, parentId) async {
      final general = await ensureGeneralCatalog(ref);
      final page = await ref
          .read(hmmNoteRepositoryProvider)
          .getNotes(
            parentNoteId: parentId,
            catalogId: general.id,
            pageSize: 500,
          );
      return page.items;
    });
