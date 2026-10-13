import '../domain/entities/cheatsheet_card.dart';

/// CRUD over cheatsheet cards, keyed by the card's own stable
/// [CheatsheetCard.id] rather than any storage-local identity.
abstract interface class ICheatsheetRepository {
  Future<List<CheatsheetCard>> getCards();

  Future<CheatsheetCard?> getCard(String id);

  /// Upsert by [CheatsheetCard.id].
  Future<CheatsheetCard> saveCard(CheatsheetCard card);

  Future<void> deleteCard(String id);

  /// The local int id of the note that stores card [cardId], or null when
  /// there is none yet — or when this store has no local notes at all
  /// (cloudApi). Vault paths are keyed by note id, so a cover can only be
  /// written once this answers non-null.
  Future<int?> noteIdFor(String cardId);
}
