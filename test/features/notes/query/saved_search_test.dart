import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/query/saved_search.dart';

void main() {
  test('round-trips with unknown fields', () {
    final s = SavedSearch.fromJson({
      'id': 'a',
      'name': 'Oil',
      'order': 0,
      'query': {'text': 'oil'},
      'color': 'x',
    });
    final json = s.toJson();
    expect(json['color'], 'x');
    expect(json['id'], 'a');
    expect(json['name'], 'Oil');
    expect(json['order'], 0);
    expect((json['query'] as Map)['text'], 'oil');
  });

  test('an entry without a name is skipped', () {
    final list = parseSavedSearches([
      {'id': 'a', 'order': 0, 'query': <String, Object?>{}},
      {'id': 'b', 'name': 'Ok', 'order': 1, 'query': <String, Object?>{}},
      'junk',
    ]);
    expect([for (final s in list) s.id], ['b']);
  });

  test('the query keeps an unknown token', () {
    final s = SavedSearch.fromJson({
      'id': 'a',
      'name': 'N',
      'order': 0,
      'query': {
        'tokens': [
          {'type': 'future', 'x': 1},
        ],
      },
    });
    final tokens = (s.toJson()['query'] as Map)['tokens'] as List;
    expect(tokens.single, {'type': 'future', 'x': 1});
  });
}
