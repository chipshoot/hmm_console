import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/launcher/domain/launcher_matcher.dart';
import 'package:hmm_console/features/launcher/domain/launcher_registry.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

/// The launcher holds three kinds of string with three different rules, and
/// only one of them is ordinary UI copy.
///
/// * `id` — the persisted key. Favorites are stored as a list of ids and
///   aliases map *alias → id*, so a favorite saved in one language must still
///   resolve in the other.
/// * `title` — display only. Translated.
/// * `synonyms` — *input vocabulary*, matched against what the user typed.
///   Translating these by replacement would mean a bilingual user on a Chinese
///   UI could no longer find Gas Log by typing `gas`. They are added to.
void main() {
  late AppLocalizations en;
  late AppLocalizations zh;

  setUp(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
    zh = await AppLocalizations.delegate.load(const Locale('zh'));
  });

  group('ids are stable — favorites survive a language change', () {
    test('the same ids appear in both locales, in the same order', () {
      // If this drifts, a favorite or alias saved in English silently stops
      // resolving after the user switches to Chinese.
      expect(launcherDestinations(zh).map((d) => d.id),
          launcherDestinations(en).map((d) => d.id));
    });

    test('a favorite id resolves in either locale', () {
      expect(launcherDestinationsById(en)['gasLog'], isNotNull);
      expect(launcherDestinationsById(zh)['gasLog'], isNotNull);
      expect(launcherDestinationsById(zh)['gasLog']!.id, 'gasLog');
    });

    test('route names are keys too and do not translate', () {
      final enList = launcherDestinations(en);
      final zhList = launcherDestinations(zh);
      for (var i = 0; i < enList.length; i++) {
        expect(zhList[i].routeName, enList[i].routeName,
            reason: 'routeName drifted for ${enList[i].id}');
      }
    });
  });

  group('titles are translated', () {
    test('destination titles render in Chinese', () {
      final byId = launcherDestinationsById(zh);
      expect(byId['gasLog']!.title, '加油记录');
      expect(byId['cheatsheets']!.title, '速查卡');
      // Negative too: a locale falling back to English would still be non-empty.
      expect(byId['gasLog']!.title,
          isNot(launcherDestinationsById(en)['gasLog']!.title));
    });

    test('every destination has a title in both locales', () {
      for (final l in [en, zh]) {
        for (final d in launcherDestinations(l)) {
          expect(d.title, isNotEmpty, reason: 'missing title for ${d.id}');
        }
      }
    });
  });

  group('search works in both languages, in either locale', () {
    // The point of adding synonyms rather than swapping them.
    test('an English term matches while the UI is Chinese', () {
      final hits = match('gas', registry: launcherDestinations(zh), aliases: {});
      expect(hits.map((d) => d.id), contains('gasLog'));
    });

    test('a Chinese term matches while the UI is English', () {
      final hits =
          match('加油', registry: launcherDestinations(en), aliases: {});
      expect(hits.map((d) => d.id), contains('gasLog'));
    });

    test('the English name still matches once the title is Chinese', () {
      // `title` is the Chinese word in this registry, so 'Gas Log' only matches
      // because the English name is repeated in synonyms.
      final hits =
          match('Gas Log', registry: launcherDestinations(zh), aliases: {});
      expect(hits.map((d) => d.id), contains('gasLog'));
    });

    test('the Chinese name matches in the Chinese UI', () {
      final hits =
          match('速查卡', registry: launcherDestinations(zh), aliases: {});
      expect(hits.map((d) => d.id), contains('cheatsheets'));
    });
  });
}
