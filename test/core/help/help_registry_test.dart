import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/help/help_registry.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

void main() {
  for (final code in ['en', 'zh']) {
    test('every HelpId has complete help in $code', () {
      final l = lookupAppLocalizations(Locale(code));
      for (final id in HelpId.values) {
        final h = helpFor(id, l);
        expect(h.title.trim(), isNotEmpty, reason: '$id title');
        expect(h.summary.trim(), isNotEmpty, reason: '$id summary');
        expect(h.entries, isNotEmpty, reason: '$id entries');
        for (final e in h.entries) {
          expect(e.title.trim(), isNotEmpty, reason: '$id entry title');
          expect(e.body.trim(), isNotEmpty, reason: '$id ${e.title} body');
        }
      }
    });
  }

  test('help shows the icons the hub row actually uses', () {
    final l = lookupAppLocalizations(const Locale('en'));
    final icons = helpFor(HelpId.automobileHub, l).entries.map((e) => e.icon);
    // automobile_list_tile.dart draws the filled car.
    expect(icons, contains(Icons.directions_car));
    expect(icons, isNot(contains(Icons.directions_car_outlined)));
  });

  test('zh help is translated, not copied from en', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final zh = lookupAppLocalizations(const Locale('zh'));
    for (final id in HelpId.values) {
      expect(helpFor(id, zh).summary, isNot(helpFor(id, en).summary),
          reason: '$id');
    }
  });
}
