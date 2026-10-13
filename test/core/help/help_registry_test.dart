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
      expect(
        helpFor(id, zh).summary,
        isNot(helpFor(id, en).summary),
        reason: '$id',
      );
    }
  });

  test('contacts help explains the sort setting with its icon', () {
    final l = lookupAppLocalizations(const Locale('en'));
    final entry = helpFor(
      HelpId.contacts,
      l,
    ).entries.singleWhere((e) => e.icon == Icons.sort_by_alpha);
    expect(entry.title, l.helpContactsSortTitle);
    expect(entry.body, contains('Settings'));
  });

  test('contact edit help covers More name options with its icon', () {
    final l = lookupAppLocalizations(const Locale('en'));
    final entry = helpFor(
      HelpId.contactEdit,
      l,
    ).entries.singleWhere((e) => e.icon == Icons.translate);
    expect(entry.title, l.helpContactEditNameOptionsTitle);
    expect(entry.body, contains('pinyin'));
  });

  test('wallet help explains tiles, both chip rows and the lock badge', () {
    final l = lookupAppLocalizations(const Locale('en'));
    final entries = helpFor(HelpId.cheatsheetWallet, l).entries;
    // card_tile.dart draws Icons.lock_outline on a protected card. Tiles and
    // chips draw no Material icon, so they use the closest stand-in (the
    // vehicleNotes "Open" entry's precedent).
    expect(entries.map((e) => e.icon), [
      Icons.touch_app_outlined,
      Icons.filter_list,
      Icons.label_outline,
      Icons.lock_outline,
    ]);
    expect(entries.map((e) => e.title), [
      l.helpCheatsheetWalletTilesTitle,
      l.helpCheatsheetWalletGroupsTitle,
      l.helpCheatsheetWalletTagsTitle,
      l.helpCheatsheetWalletLockTitle,
    ]);
  });

  test('wallet help is translated entry by entry in zh', () {
    final en = helpFor(
      HelpId.cheatsheetWallet,
      lookupAppLocalizations(const Locale('en')),
    );
    final zh = helpFor(
      HelpId.cheatsheetWallet,
      lookupAppLocalizations(const Locale('zh')),
    );
    expect(zh.entries.length, en.entries.length);
    for (var i = 0; i < en.entries.length; i++) {
      expect(zh.entries[i].title, isNot(en.entries[i].title), reason: '$i');
      expect(zh.entries[i].body, isNot(en.entries[i].body), reason: '$i');
    }
  });

  test('detail help covers both layouts, the header and the lock tile', () {
    final l = lookupAppLocalizations(const Locale('en'));
    final entries = helpFor(HelpId.cheatsheetDetail, l).entries;
    // The designer's layout control draws list_alt / format_list_numbered;
    // sensitive_attachment_image.dart's lock tile draws lock_outline.
    expect(entries.map((e) => e.icon), [
      Icons.list_alt,
      Icons.format_list_numbered,
      Icons.image_outlined,
      Icons.lock_outline,
    ]);
    expect(entries.map((e) => e.title), [
      l.helpCheatsheetDetailFactsTitle,
      l.helpCheatsheetDetailKeyPointsTitle,
      l.helpCheatsheetDetailHeaderTitle,
      l.helpCheatsheetDetailLockTitle,
    ]);
  });

  test('detail help is translated entry by entry in zh', () {
    final en = helpFor(
      HelpId.cheatsheetDetail,
      lookupAppLocalizations(const Locale('en')),
    );
    final zh = helpFor(
      HelpId.cheatsheetDetail,
      lookupAppLocalizations(const Locale('zh')),
    );
    expect(zh.entries.length, en.entries.length);
    for (var i = 0; i < en.entries.length; i++) {
      expect(zh.entries[i].title, isNot(en.entries[i].title), reason: '$i');
      expect(zh.entries[i].body, isNot(en.entries[i].body), reason: '$i');
    }
  });
}
