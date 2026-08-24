import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/cheatsheet_card.dart';
import '../datasources/cheatsheet_remote_datasource.dart';
import '../i_cheatsheet_repository.dart';
import '../mappers/cheatsheet_api_mapper.dart';

/// `cloudApi` implementation of [ICheatsheetRepository], talking to
/// `/v1/cheatsheets`. The local Drift repository backs `local` and
/// `cloudStorage`; this one backs `cloudApi`.
class CheatsheetApiRepository implements ICheatsheetRepository {
  CheatsheetApiRepository(this._remote);

  final CheatsheetRemoteDataSource _remote;

  @override
  Future<List<CheatsheetCard>> getCards() async {
    final raw = await _remote.getCards();
    return raw.map(CheatsheetApiMapper.fromApi).toList();
  }

  @override
  Future<CheatsheetCard?> getCard(String id) async {
    final raw = await _remote.getCard(id);
    return raw == null ? null : CheatsheetApiMapper.fromApi(raw);
  }

  /// Upsert by [CheatsheetCard.id], matching the interface contract. The API
  /// splits create and update, so this probes first and picks.
  ///
  /// The probe is not a uniqueness check - the server does its own, and returns
  /// 409 if it loses a race - it is only how an upsert chooses a verb. A create
  /// that races another create still surfaces as a conflict rather than
  /// silently overwriting.
  @override
  Future<CheatsheetCard> saveCard(CheatsheetCard card) async {
    final body = CheatsheetApiMapper.toApi(card);
    final existing = await _remote.getCard(card.id);

    if (existing == null) {
      final created = await _remote.createCard(body);
      return CheatsheetApiMapper.fromApi(created);
    }

    await _remote.updateCard(card.id, body);
    // PUT answers 204, so return what was sent rather than inventing a read.
    return card;
  }

  @override
  Future<void> deleteCard(String id) async {
    try {
      await _remote.deleteCard(id);
    } on DioException catch (e) {
      // Deleting something already gone is the outcome the caller wanted.
      if (e.response?.statusCode == 404) return;
      rethrow;
    }
  }
}

final cheatsheetApiRepositoryProvider = Provider<ICheatsheetRepository>((ref) {
  return CheatsheetApiRepository(ref.watch(cheatsheetRemoteDataSourceProvider));
});
