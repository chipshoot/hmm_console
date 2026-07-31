import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/cheatsheet/data/cheatsheet_codec.dart';
import '../../../features/cheatsheet/data/i_cheatsheet_repository.dart';
import '../../../features/cheatsheet/domain/entities/cheatsheet_card.dart';
import '../../../features/notes/data/models/hmm_note.dart';
import '../hmm_note_input.dart';
import 'local_hmm_note_repository.dart';
import 'local_note_catalog_repository.dart';

/// 3-segment name so `CatalogPalette.domainKeyFor` groups it as its own
/// "Cheatsheet" domain.
const cheatsheetCatalogName = 'Hmm.CheatsheetMan.Cheatsheet';

/// The note subject is an identity, never a label: card titles are mutable
/// and non-unique, so they live only inside the card JSON.
String cheatsheetSubjectFor(String cardId) => 'Cheatsheet:$cardId';

/// Stores each card as an `HmmNote`'s content under a fixed catalog, mirroring
/// `LocalGasLogRepository`. Cheatsheet notes have no parent.
class LocalCheatsheetRepository implements ICheatsheetRepository {
  LocalCheatsheetRepository(this._notes, this._catalogs);

  final IHmmNoteRepository _notes;
  final INoteCatalogRepository _catalogs;

  static const _pageSize = 100;

  String _serialize(CheatsheetCard c) => jsonEncode({
        'note': {
          'content': {'Cheatsheet': CheatsheetCodec.toMap(c)},
        },
      });

  CheatsheetCard? _deserialize(String? content) {
    if (content == null) return null;
    try {
      final data =
          (jsonDecode(content) as Map)['note']?['content']?['Cheatsheet'];
      return data is Map
          ? CheatsheetCodec.fromMap(data.cast<String, dynamic>())
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<int> _catalogId() async =>
      (await _catalogs.getOrCreateCatalog(cheatsheetCatalogName, '{}')).id;

  /// Pages until exhausted. A fixed ceiling here would silently hide cards —
  /// the user would simply never see them again.
  Future<List<HmmNote>> _allNotes() async {
    final catalogId = await _catalogId();
    final out = <HmmNote>[];
    var page = 1;
    while (true) {
      final res = await _notes.getNotes(
        catalogId: catalogId,
        page: page,
        pageSize: _pageSize,
      );
      out.addAll(res.items);
      if (res.items.isEmpty || page >= res.meta.totalPages) break;
      page++;
    }
    return out;
  }

  @override
  Future<List<CheatsheetCard>> getCards() async => (await _allNotes())
      .map((n) => _deserialize(n.content))
      .whereType<CheatsheetCard>()
      .toList();

  /// Finds a card's note by **subject**, not by decoding its content.
  ///
  /// The subject already is the card's identity (`Cheatsheet:{id}`), and it
  /// stays readable when the content does not. Matching on the decoded id
  /// instead meant a note whose JSON had become unreadable was invisible
  /// here — so `saveCard` would decide it was new and write a *second* note
  /// under the same subject, and `deleteCard` could never reach the original.
  Future<HmmNote?> _noteForCard(String id) async {
    final subject = cheatsheetSubjectFor(id);
    for (final n in await _allNotes()) {
      if (n.subject == subject) return n;
    }
    return null;
  }

  @override
  Future<CheatsheetCard?> getCard(String id) async =>
      _deserialize((await _noteForCard(id))?.content);

  @override
  Future<CheatsheetCard> saveCard(CheatsheetCard card) async {
    final subject = cheatsheetSubjectFor(card.id);
    final existing = await _noteForCard(card.id);
    if (existing == null) {
      await _notes.createNote(HmmNoteCreate(
        subject: subject,
        catalogId: await _catalogId(),
        content: _serialize(card),
      ));
    } else {
      await _notes.updateNote(
        existing.id,
        HmmNoteUpdate(subject: subject, content: _serialize(card)),
      );
    }
    return card;
  }

  @override
  Future<void> deleteCard(String id) async {
    final n = await _noteForCard(id);
    if (n != null) await _notes.deleteNote(n.id);
  }
}

final localCheatsheetRepositoryProvider = Provider<ICheatsheetRepository>(
  (ref) => LocalCheatsheetRepository(
    ref.watch(localHmmNoteRepositoryProvider),
    ref.watch(localNoteCatalogRepositoryProvider),
  ),
);
