import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/cheatsheet/data/cheatsheet_templates.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

void main() {
  late AppLocalizations en;

  setUp(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  CheatsheetTemplate byId(String id) =>
      CheatsheetTemplates.all(en).firstWhere((t) => t.id == id);

  test('accidentClaim instantiates labelled unbound rows', () {
    final card = CheatsheetTemplates.instantiate(byId('accidentClaim'), 'c1');

    expect(card.id, 'c1');
    expect(card.templateId, 'accidentClaim');
    expect(card.walletGroup, 'Vehicle');
    expect(card.rows, isNotEmpty);
    expect(card.rows.every((r) => r.source == null), isTrue);
    expect(card.rows.map((r) => r.label), contains('Plate'));
  });

  test('blank has no rows', () {
    expect(CheatsheetTemplates.instantiate(byId('blank'), 'c2').rows, isEmpty);
  });

  test('every template instantiates cleanly with unbound rows', () {
    for (final t in CheatsheetTemplates.all(en)) {
      final card = CheatsheetTemplates.instantiate(t, 'id-${t.id}');
      expect(card.id, 'id-${t.id}');
      expect(card.templateId, t.id);
      expect(card.title, t.title);
      expect(card.walletGroup, t.walletGroup);
      expect(card.tags, isEmpty);
      expect(card.protected, isFalse);
      expect(card.rows.map((r) => r.label).toList(), t.rowLabels);
      expect(card.rows.every((r) => !r.isBound), isTrue);
    }
  });

  test('template ids are unique', () {
    final ids = CheatsheetTemplates.all(en).map((t) => t.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('the expected starter set ships', () {
    expect(
      CheatsheetTemplates.all(en).map((t) => t.id),
      containsAll(['accidentClaim', 'healthInfo', 'document', 'blank']),
    );
  });

  test('instantiate takes the id from its caller, never invents one', () {
    // T9 owns id generation; templates must stay a pure shape factory.
    final a = CheatsheetTemplates.instantiate(byId('blank'), 'fixed');
    final b = CheatsheetTemplates.instantiate(byId('blank'), 'fixed');
    expect(a.id, 'fixed');
    expect(b.id, 'fixed');
  });
}
