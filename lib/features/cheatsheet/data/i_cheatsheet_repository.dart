import '../domain/entities/cheatsheet_card.dart';

/// CRUD over cheatsheet cards, keyed by the card's own stable
/// [CheatsheetCard.id] rather than any storage-local identity.
abstract interface class ICheatsheetRepository {
  Future<List<CheatsheetCard>> getCards();

  Future<CheatsheetCard?> getCard(String id);

  /// Upsert by [CheatsheetCard.id].
  Future<CheatsheetCard> saveCard(CheatsheetCard card);

  Future<void> deleteCard(String id);
}
