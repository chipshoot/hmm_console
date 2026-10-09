import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/repository_providers.dart';
import '../../../core/navigation/route_names.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../cheatsheet/presentation/cheatsheet_note_display.dart';
import '../../contacts/presentation/contact_note_display.dart';
import '../data/models/hmm_note.dart';
import '../presentation/util/note_preview.dart';

/// What the Notes UI prints for a note: a title and a one-line preview.
typedef NoteDisplay = ({String title, String preview});

/// Where tapping a note goes when it is not the generic note screen.
typedef NoteTarget = ({RouterNames route, Map<String, String> params});

/// One catalog's way of presenting its notes. Display only: the stored
/// subject and content are never touched.
abstract interface class NoteDisplayEntry {
  NoteDisplay display(HmmNote note, AppLocalizations l);

  /// Just the title: no preview work.
  String title(HmmNote note, AppLocalizations l);

  /// The screen that owns this note, or null when it cannot be determined.
  NoteTarget? target(HmmNote note);
}

/// Display-title lookup keyed by catalog name, mirroring `NoteRenderRegistry`.
/// Every catalog without an entry keeps the subject and `notePreview`.
class NoteDisplayRegistry {
  const NoteDisplayRegistry(this._byCatalog);

  final Map<String, NoteDisplayEntry> _byCatalog;

  NoteDisplay noteDisplay(
    HmmNote note,
    String? catalogName,
    AppLocalizations l,
  ) {
    final entry = catalogName == null ? null : _byCatalog[catalogName];
    if (entry == null) {
      return (title: note.subject, preview: notePreview(note.content));
    }
    return entry.display(note, l);
  }

  /// The title only. Zero work for a catalog without an entry, so the search
  /// and sort paths can call it per note.
  String title(HmmNote note, String? catalogName, AppLocalizations l) {
    final entry = catalogName == null ? null : _byCatalog[catalogName];
    return entry == null ? note.subject : entry.title(note, l);
  }

  NoteTarget? targetFor(HmmNote note, String? catalogName) =>
      catalogName == null ? null : _byCatalog[catalogName]?.target(note);

  /// Opens the owning screen and returns true; false means the caller should
  /// do today's navigation.
  bool open(BuildContext context, HmmNote note, String? catalogName) {
    final t = targetFor(note, catalogName);
    if (t == null) return false;
    context.pushNamed(t.route.name, pathParameters: t.params);
    return true;
  }
}

final noteDisplayRegistryProvider = Provider<NoteDisplayRegistry>((ref) {
  return const NoteDisplayRegistry({
    ContactNoteDisplay.catalogName: ContactNoteDisplay(),
    CheatsheetNoteDisplay.catalogName: CheatsheetNoteDisplay(),
  });
});

/// Catalog id -> name, for surfaces that only hold a note's `catalogId`.
/// Empty while loading or on failure, which degrades to the plain subject.
final noteCatalogNamesProvider = FutureProvider<Map<int, String>>((ref) async {
  final all = await ref.watch(noteCatalogRepositoryProvider).getCatalogs();
  return {for (final c in all) c.id: c.name};
});
