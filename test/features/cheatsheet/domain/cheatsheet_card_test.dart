import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_row.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_source.dart';

void main() {
  const source = CheatsheetSource(
    noteUuid: 'n1',
    kind: SourceGranularity.field,
    locator: 'GasLog.station',
  );
  const row = CheatsheetRow(
    label: 'Station',
    source: source,
    valueAction: ValueAction.none,
    openSource: true,
  );
  const card = CheatsheetCard(
    id: 'c1',
    title: 'Fuel',
    walletGroup: 'Vehicle',
    tags: ['a'],
    templateId: 'blank',
    rows: [row],
  );

  test('card value-equality + copyWith', () {
    expect(card, equals(card.copyWith()));
    expect(card.copyWith(title: 'X').title, 'X');
    expect(card.copyWith(title: 'X'), isNot(equals(card)));
    expect(card.copyWith(title: 'X').id, 'c1'); // identity survives edits
  });

  test('cards differing only by a row are not equal', () {
    final other = card.copyWith(
      rows: const [CheatsheetRow(label: 'Other', source: source)],
    );
    expect(other, isNot(equals(card)));
  });

  test('cards differing only by a tag are not equal', () {
    expect(card.copyWith(tags: const ['b']), isNot(equals(card)));
  });

  test('equal cards share a hashCode', () {
    expect(card.copyWith().hashCode, card.hashCode);
  });

  test('an unbound row is representable', () {
    expect(row.copyWith(clearSource: true).source, isNull);
    expect(row.copyWith(clearSource: true).isBound, isFalse);
    expect(row.isBound, isTrue);
  });

  test('row copyWith replaces a binding', () {
    const other = CheatsheetSource(noteUuid: 'n2', kind: SourceGranularity.whole);
    expect(row.copyWith(source: other).source, other);
  });

  test('source value-equality', () {
    expect(
      source,
      equals(const CheatsheetSource(
        noteUuid: 'n1',
        kind: SourceGranularity.field,
        locator: 'GasLog.station',
      )),
    );
    expect(source, isNot(equals(source.copyWith(noteUuid: 'n2'))));
  });

  test('protected defaults to false and is Phase-2 reserved', () {
    expect(card.protected, isFalse);
    expect(card.copyWith(protected: true).protected, isTrue);
  });
}
