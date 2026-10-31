import '../../../core/data/local/local_cheatsheet_repository.dart'
    show cheatsheetCatalogName;
import '../../../core/data/local/local_contact_repository.dart'
    show contactCatalogName;
import '../../../core/notes/catalog_palette.dart';
import '../data/models/hmm_note.dart';

/// Where an entity note is managed instead of the Notes delete (G7).
enum NoteManagePlace { contacts, cheatsheets, automobile, ownScreen }

/// True only for ordinary notes: the General catalog, or a legacy row with
/// no catalog. Contacts, cheatsheet cards, gas logs, cars, service records,
/// insurance, scheduled services, gas stations, the driver licence,
/// subsystem anchors and any catalog this build does not know belong to
/// their own feature, which owns their delete (G7). Pin, flag and tags still
/// work on every note.
bool canDeleteFromNotes(HmmNote note, String? catalogName) =>
    catalogName == null || catalogName == kGeneralCatalogName;

/// The screen that manages an entity note, or null for an ordinary note.
NoteManagePlace? managePlaceFor(String? catalogName) {
  if (catalogName == null || catalogName == kGeneralCatalogName) return null;
  if (catalogName == contactCatalogName) return NoteManagePlace.contacts;
  if (catalogName == cheatsheetCatalogName) return NoteManagePlace.cheatsheets;
  if (CatalogPalette.domainKeyFor(catalogName) == 'AutomobileMan') {
    return NoteManagePlace.automobile;
  }
  return NoteManagePlace.ownScreen;
}

/// Thrown by `MutateNote.delete` for an entity note.
class EntityNoteDeleteRefused implements Exception {
  const EntityNoteDeleteRefused(this.place);

  final NoteManagePlace place;

  @override
  String toString() => 'EntityNoteDeleteRefused(${place.name})';
}
