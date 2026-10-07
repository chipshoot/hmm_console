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

  test('contact edit help describes the address country selector', () {
    final l = lookupAppLocalizations(const Locale('en'));
    final entries = helpFor(HelpId.contactEdit, l).entries;
    // address_editor.dart draws Icons.public beside the country selector.
    final address = entries.singleWhere((e) => e.icon == Icons.public);
    expect(address.title, l.helpContactEditAddressTitle);
    expect(address.body, contains('Other'));
    expect(address.body, contains('clears the state or province'));
  });

  test('zh help is translated, not copied from en', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final zh = lookupAppLocalizations(const Locale('zh'));
    for (final id in HelpId.values) {
      expect(helpFor(id, zh).summary, isNot(helpFor(id, en).summary),
          reason: '$id');
    }
  });

  test('contacts help explains the sort setting with its icon', () {
    final l = lookupAppLocalizations(const Locale('en'));
    final entry = helpFor(HelpId.contacts, l)
        .entries
        .singleWhere((e) => e.icon == Icons.sort_by_alpha);
    expect(entry.title, l.helpContactsSortTitle);
    expect(entry.body, contains('Settings'));
  });
}
