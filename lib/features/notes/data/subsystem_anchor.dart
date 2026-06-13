import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/hmm_note_input.dart';
import '../../../core/data/local/database.dart';
import '../../../core/data/repository_providers.dart';
import 'models/hmm_note.dart';

/// Catalog marking subsystem anchor notes. Anchors are infrastructure notes a
/// General note can be attached to (parentNoteId) for subsystem-level surfacing.
const String kSubsystemAnchorCatalogName = 'Hmm.System.Subsystem';
const String _anchorSchema = '{"type":"subsystem"}';

/// Deterministic, stable, cross-device uuid for a subsystem's anchor note, so
/// the anchor is one shared record (sync dedups by uuid) and child notes
/// resolve to a single anchor everywhere.
String subsystemAnchorUuid(String key) => 'hmm-subsystem-$key';

Future<int> _ensureAnchorCatalogId(Ref ref) async {
  final repo = ref.read(noteCatalogRepositoryProvider);
  final existing = await repo.getCatalogByName(kSubsystemAnchorCatalogName);
  if (existing != null) return existing.id;
  final created = await repo.createCatalog(NoteCatalogsCompanion.insert(
    name: kSubsystemAnchorCatalogName,
    schema: _anchorSchema,
  ));
  return created.id;
}

/// Ensure the anchor catalog + the anchor note for [key] exist (idempotent by
/// the deterministic uuid). Returns the anchor note.
Future<HmmNote> ensureSubsystemAnchor(
  Ref ref, {
  required String key,
  required String displayName,
}) async {
  final noteRepo = ref.read(hmmNoteRepositoryProvider);
  final uuid = subsystemAnchorUuid(key);
  final existing = await noteRepo.getNoteByUuid(uuid);
  if (existing != null) return existing;
  final catalogId = await _ensureAnchorCatalogId(ref);
  return noteRepo.createNote(HmmNoteCreate(
    subject: displayName,
    catalogId: catalogId,
    uuid: uuid,
  ));
}

/// The Automobile subsystem anchor (the reference subsystem). Future
/// subsystems add their own analogous provider.
final automobileAnchorProvider = FutureProvider<HmmNote>((ref) =>
    ensureSubsystemAnchor(ref, key: 'automobile', displayName: 'Automobile'));

/// All subsystem anchor notes.
final subsystemAnchorsProvider = FutureProvider<List<HmmNote>>((ref) async {
  await ref.watch(automobileAnchorProvider.future);
  final catalogRepo = ref.read(noteCatalogRepositoryProvider);
  final anchorCatalog =
      await catalogRepo.getCatalogByName(kSubsystemAnchorCatalogName);
  if (anchorCatalog == null) return [];
  final page = await ref
      .read(hmmNoteRepositoryProvider)
      .getNotes(catalogId: anchorCatalog.id, pageSize: 200);
  return page.items;
});
