import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/cheatsheet/data/cheatsheet_codec.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_row.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_source.dart';

void main() {
  const card = CheatsheetCard(
    id: 'c1',
    title: 'Claim',
    walletGroup: 'Vehicle',
    tags: ['legal'],
    templateId: 'accidentClaim',
    rows: [
      CheatsheetRow(
        label: 'Plate',
        source: CheatsheetSource(
          noteUuid: 'auto1',
          kind: SourceGranularity.field,
          locator: 'AutomobileInfo.plate',
        ),
        valueAction: ValueAction.call,
        openSource: true,
      ),
      CheatsheetRow(label: 'Unbound', source: null),
    ],
  );

  test('round-trips including an unbound row', () {
    expect(CheatsheetCodec.fromMap(CheatsheetCodec.toMap(card)), equals(card));
  });

  test('round-trips every granularity', () {
    for (final kind in SourceGranularity.values) {
      final c = card.copyWith(rows: [
        CheatsheetRow(
          label: kind.name,
          source: CheatsheetSource(noteUuid: 'n', kind: kind, locator: 'x'),
        ),
      ]);
      expect(CheatsheetCodec.fromMap(CheatsheetCodec.toMap(c)), equals(c));
    }
  });

  test('stamps and reads schemaVersion', () {
    expect(CheatsheetCodec.toMap(card)['schemaVersion'], 1);
    expect(CheatsheetCodec.schemaVersionOf(const {}), 1); // absent -> 1
    expect(CheatsheetCodec.schemaVersionOf(const {'schemaVersion': 7}), 7);
  });

  test('tolerates absent optional keys', () {
    final c = CheatsheetCodec.fromMap({'id': 'x', 'title': 'T', 'rows': []});
    expect(c.id, 'x');
    expect(c.walletGroup, 'Ungrouped');
    expect(c.templateId, 'blank');
    expect(c.tags, isEmpty);
    expect(c.rows, isEmpty);
  });

  test('a newer schemaVersion still decodes known fields', () {
    final c = CheatsheetCodec.fromMap({
      'schemaVersion': 99,
      'id': 'x',
      'title': 'T',
      'rows': [],
      'futureKey': {'a': 1},
    });
    expect(c.id, 'x');
    expect(c.title, 'T');
  });

  test('one malformed row is dropped, the rest of the card survives', () {
    final c = CheatsheetCodec.fromMap({
      'id': 'x',
      'title': 'T',
      'rows': [
        {'label': 'good', 'openSource': true},
        'not-a-map', // malformed row
        {'label': 'alsoBad', 'source': 'not-a-map'}, // malformed source
      ],
    });
    expect(c.rows.map((r) => r.label), ['good']);
    expect(c.title, 'T'); // whole card NOT discarded
  });

  test('an unreadable row survives a decode/encode round trip', () {
    // Saving rewrites the whole card, so a row merely *dropped* on read would
    // be erased by the next unrelated edit. It must come back out.
    final decoded = CheatsheetCodec.fromMap({
      'id': 'x',
      'title': 'T',
      'rows': [
        {'label': 'good', 'openSource': true},
        {'label': 'future', 'source': 'not-a-map'},
      ],
    });
    expect(decoded.rows.map((r) => r.label), ['good']);
    expect(decoded.unreadableRows, hasLength(1));

    final reEncoded = CheatsheetCodec.toMap(decoded);
    final rows = (reEncoded['rows'] as List).cast<Map<String, dynamic>>();
    expect(rows, hasLength(2), reason: 'the unreadable row is written back');
    expect(
      rows.any((r) => r['label'] == 'future' && r['source'] == 'not-a-map'),
      isTrue,
      reason: 'preserved verbatim, not normalised away',
    );
  });

  test('editing a card does not erase its unreadable rows', () {
    final decoded = CheatsheetCodec.fromMap({
      'id': 'x',
      'title': 'T',
      'rows': [
        {'label': 'good', 'openSource': true},
        {'label': 'future', 'source': 'not-a-map'},
      ],
    });

    // The designer's flow: mutate the working copy, then write it back.
    final edited = decoded.copyWith(title: 'Renamed');
    final rows = CheatsheetCodec.toMap(edited)['rows'] as List;

    expect(rows, hasLength(2));
    expect(edited.title, 'Renamed');
  });

  test('a non-map row element is dropped without losing the rest', () {
    // 'not-a-map' at row level cannot be preserved as a row map; dropping it
    // is the only option, but it must not crash or lose sibling rows.
    final decoded = CheatsheetCodec.fromMap({
      'id': 'x',
      'title': 'T',
      'rows': [
        'not-a-map',
        {'label': 'good'},
      ],
    });
    expect(decoded.rows.map((r) => r.label), ['good']);
    expect(decoded.unreadableRows, isEmpty);
  });

  test('non-string tag elements are skipped', () {
    final c = CheatsheetCodec.fromMap({
      'id': 'x',
      'title': 'T',
      'tags': ['ok', 7, null],
      'rows': [],
    });
    expect(c.tags, ['ok']);
  });

  test('wrong-typed scalars fall back to defaults', () {
    final c = CheatsheetCodec.fromMap({
      'id': 'x',
      'title': 42,
      'protected': 'yes',
      'rows': [],
    });
    expect(c.title, '');
    expect(c.protected, isFalse);
  });

  test('an unknown valueAction or kind degrades to a safe default', () {
    final c = CheatsheetCodec.fromMap({
      'id': 'x',
      'title': 'T',
      'rows': [
        {
          'label': 'r',
          'valueAction': 'teleport',
          'source': {'noteUuid': 'n', 'kind': 'quantum'},
        },
      ],
    });
    expect(c.rows.single.valueAction, ValueAction.none);
    expect(c.rows.single.source!.kind, SourceGranularity.whole);
  });

  test('a rows value of the wrong type yields no rows, not a throw', () {
    final c = CheatsheetCodec.fromMap({'id': 'x', 'title': 'T', 'rows': 'nope'});
    expect(c.rows, isEmpty);
    expect(c.id, 'x');
  });
}
