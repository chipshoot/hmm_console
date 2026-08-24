import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/cheatsheet/data/datasources/cheatsheet_remote_datasource.dart';
import 'package:hmm_console/features/cheatsheet/data/repositories/cheatsheet_api_repository.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';

/// Records what the repository asked of the network, so the tests can assert
/// the verb chosen and the body sent rather than only the value returned.
class _FakeDataSource implements CheatsheetRemoteDataSource {
  _FakeDataSource({this.existing});

  Map<String, dynamic>? existing;
  final calls = <String>[];
  Map<String, dynamic>? lastBody;
  int? deleteStatus;

  @override
  Future<List<Map<String, dynamic>>> getCards({
    String? walletGroup,
    String? tag,
  }) async {
    calls.add('getCards');
    return existing == null ? const [] : [existing!];
  }

  @override
  Future<Map<String, dynamic>?> getCard(String id) async {
    calls.add('getCard');
    return existing;
  }

  @override
  Future<Map<String, dynamic>> createCard(Map<String, dynamic> body) async {
    calls.add('createCard');
    lastBody = body;
    return body;
  }

  @override
  Future<void> updateCard(String id, Map<String, dynamic> body) async {
    calls.add('updateCard');
    lastBody = body;
  }

  @override
  Future<void> deleteCard(String id) async {
    calls.add('deleteCard');
    if (deleteStatus != null) {
      throw DioException(
        requestOptions: RequestOptions(path: '/cheatsheets/$id'),
        response: Response(
          requestOptions: RequestOptions(path: '/cheatsheets/$id'),
          statusCode: deleteStatus,
        ),
      );
    }
  }
}

void main() {
  const card = CheatsheetCard(
    id: 'c-1',
    title: 'Passport',
    walletGroup: 'Travel',
    tags: ['trip'],
    templateId: 'blank',
    rows: [],
  );

  test('saveCard creates when the card is absent', () async {
    final fake = _FakeDataSource();
    final repo = CheatsheetApiRepository(fake);

    await repo.saveCard(card);

    expect(fake.calls, ['getCard', 'createCard']);
    expect(fake.lastBody!['Title'], 'Passport');
  });

  test('saveCard updates when the card already exists', () async {
    final fake = _FakeDataSource(existing: {'Id': 'c-1', 'Title': 'Old'});
    final repo = CheatsheetApiRepository(fake);

    final saved = await repo.saveCard(card);

    expect(fake.calls, ['getCard', 'updateCard']);
    // PUT answers 204, so the caller gets back what it sent.
    expect(saved.title, 'Passport');
  });

  test('getCard returns null for a card that is not there', () async {
    final repo = CheatsheetApiRepository(_FakeDataSource());

    expect(await repo.getCard('nope'), isNull);
  });

  test('deleteCard treats an already-deleted card as done', () async {
    final fake = _FakeDataSource()..deleteStatus = 404;
    final repo = CheatsheetApiRepository(fake);

    await repo.deleteCard('c-1');

    expect(fake.calls, ['deleteCard']);
  });

  test('deleteCard still surfaces a real failure', () async {
    final fake = _FakeDataSource()..deleteStatus = 500;
    final repo = CheatsheetApiRepository(fake);

    expect(() => repo.deleteCard('c-1'), throwsA(isA<DioException>()));
  });

  test('an unreadable row survives an unrelated edit through saveCard', () async {
    final fake = _FakeDataSource(existing: {
      'Id': 'c-1',
      'Title': 'Passport',
      'Rows': [
        {'Label': 'Broken', 'Source': 42},
      ],
    });
    final repo = CheatsheetApiRepository(fake);

    final loaded = await repo.getCard('c-1');
    await repo.saveCard(loaded!.copyWith(title: 'Renamed'));

    expect((fake.lastBody!['Rows'] as List).single,
        {'Label': 'Broken', 'Source': 42});
  });
}
