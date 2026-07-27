import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/repository_providers.dart';
import '../domain/entities/cheatsheet_card.dart';

/// The wallet's card list.
///
/// Mutations write through the repository and then invalidate, so the list is
/// always re-read from storage rather than patched in memory — the repository
/// upserts by card id, and mirroring that merge logic here is how the two
/// would drift apart.
class CheatsheetsState extends AsyncNotifier<List<CheatsheetCard>> {
  @override
  Future<List<CheatsheetCard>> build() =>
      ref.read(cheatsheetRepositoryModeProvider).getCards();

  Future<void> save(CheatsheetCard card) async {
    await ref.read(cheatsheetRepositoryModeProvider).saveCard(card);
    ref.invalidateSelf();
  }

  Future<void> remove(String id) async {
    await ref.read(cheatsheetRepositoryModeProvider).deleteCard(id);
    ref.invalidateSelf();
  }

  void refresh() => ref.invalidateSelf();
}

final cheatsheetsStateProvider =
    AsyncNotifierProvider<CheatsheetsState, List<CheatsheetCard>>(
  () => CheatsheetsState(),
);
