import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';

/// Raw `/v1/cheatsheets` transport. Returns decoded JSON maps; shaping them
/// into entities is [CheatsheetApiMapper]'s job.
class CheatsheetRemoteDataSource {
  CheatsheetRemoteDataSource(this._apiClient);

  static const _path = '/cheatsheets';

  final ApiClient _apiClient;

  Future<List<Map<String, dynamic>>> getCards({
    String? walletGroup,
    String? tag,
  }) async {
    final response = await _apiClient.dio.get(
      _path,
      queryParameters: {
        'walletGroup': ?walletGroup,
        'tag': ?tag,
      },
    );

    final data = response.data;
    // The list endpoint pages server-side; an empty or unexpected body is an
    // empty wallet, not a crash.
    if (data is! List) return const [];
    return data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  /// Null when the card does not exist, rather than throwing: a 404 here is an
  /// ordinary answer to "is this card there?".
  Future<Map<String, dynamic>?> getCard(String id) async {
    try {
      final response = await _apiClient.dio.get('$_path/$id');
      final data = response.data;
      return data is Map ? data.cast<String, dynamic>() : null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createCard(Map<String, dynamic> body) async {
    final response = await _apiClient.dio.post(_path, data: body);
    final data = response.data;
    return data is Map ? data.cast<String, dynamic>() : body;
  }

  /// PUT returns 204 No Content, so there is no body to read back.
  Future<void> updateCard(String id, Map<String, dynamic> body) async {
    await _apiClient.dio.put('$_path/$id', data: body);
  }

  Future<void> deleteCard(String id) async {
    await _apiClient.dio.delete('$_path/$id');
  }
}

final cheatsheetRemoteDataSourceProvider =
    Provider<CheatsheetRemoteDataSource>((ref) {
  return CheatsheetRemoteDataSource(ref.watch(apiClientProvider));
});
