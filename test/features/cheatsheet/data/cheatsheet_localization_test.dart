import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/cheatsheet/data/cheatsheet_templates.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

/// Templates seed **two kinds of string into the same saved card**, and only
/// one of them may be translated. This file is the guard for that split.
///
/// * Row labels become the user's own editable document content. Nothing
///   matches on them, so a card created in Chinese should read in Chinese.
/// * `walletGroup` is a grouping key — the wallet does
///   `groups.putIfAbsent(c.walletGroup, …)`, an exact string match. Translating
///   the seed would silently split one group in two the moment the user changed
///   language, with cards created before and after landing in different
///   sections of their own wallet.
///
/// Both are persisted by `CheatsheetCodec`, so neither mistake would surface as
/// a crash — only as data that quietly varies by device language.
void main() {
  late AppLocalizations en;
  late AppLocalizations zh;

  setUp(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
    zh = await AppLocalizations.delegate.load(const Locale('zh'));
  });

  CheatsheetTemplate byId(String id, AppLocalizations l) =>
      CheatsheetTemplates.all(l).firstWhere((t) => t.id == id);

  group('row labels are translated — they seed a document', () {
    test('an accident claim instantiates Chinese row labels', () {
      final card =
          CheatsheetTemplates.instantiate(byId('accidentClaim', zh), 'c1');
      final labels = card.rows.map((r) => r.label).toList();

      expect(labels, contains('车牌号'));
      expect(labels, contains('车架号'));
      // Negative too: a locale silently falling back to English would still
      // satisfy a "has labels" check.
      expect(labels, isNot(contains('Plate')));
    });

    test('the same template in English keeps the English labels', () {
      final card =
          CheatsheetTemplates.instantiate(byId('accidentClaim', en), 'c2');
      expect(card.rows.map((r) => r.label), contains('Plate'));
    });

    test('template titles translate', () {
      expect(byId('accidentClaim', zh).title, '事故理赔');
      expect(byId('accidentClaim', en).title, 'Accident Claim');
    });
  });

  group('walletGroup is a key — it must NOT be translated', () {
    test('the stored group is the English key in every locale', () {
      // The failure this prevents: cards created before and after a language
      // change landing in two different wallet groups.
      for (final l in [en, zh]) {
        expect(byId('accidentClaim', l).walletGroup, 'Vehicle');
        expect(byId('healthInfo', l).walletGroup, 'Health');
        expect(byId('document', l).walletGroup, 'Reference');
        expect(byId('blank', l).walletGroup, 'Ungrouped');
      }
    });

    test('an instantiated card carries the English group', () {
      final card =
          CheatsheetTemplates.instantiate(byId('accidentClaim', zh), 'c3');
      expect(card.walletGroup, 'Vehicle');
    });

    test('templateId is a key too and stays stable', () {
      for (final l in [en, zh]) {
        expect(CheatsheetTemplates.all(l).map((t) => t.id),
            ['accidentClaim', 'healthInfo', 'document', 'blank']);
      }
    });
  });

  group('the group is translated at display instead', () {
    test('seeded groups render in the active language', () {
      expect(cheatsheetGroupLabel('Vehicle', zh), '车辆');
      expect(cheatsheetGroupLabel('Health', zh), '健康');
      expect(cheatsheetGroupLabel('Vehicle', en), 'Vehicle');
    });

    test('a group the user typed is shown exactly as typed', () {
      // Free text the user owns — already in whatever language they chose, and
      // not ours to reinterpret.
      expect(cheatsheetGroupLabel('我的车', zh), '我的车');
      expect(cheatsheetGroupLabel('Boat stuff', zh), 'Boat stuff');
    });
  });
}
