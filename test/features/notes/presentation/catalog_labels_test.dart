import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/notes/catalog_palette.dart';
import 'package:hmm_console/features/notes/presentation/catalog_labels.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

/// Catalogs invert the trap found in the other three features.
///
/// Settings units, gas-log dropdowns and service types all had display text
/// doubling as stored data. Here the *key* is what gets stored — `'General'`,
/// `'Hmm.AutomobileMan.GasLog'` — and the label is purely derived, so the label
/// is safe to translate outright. These tests pin that asymmetry so nobody
/// later "fixes" it in the wrong direction.
void main() {
  late AppLocalizations en;
  late AppLocalizations zh;

  setUp(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
    zh = await AppLocalizations.delegate.load(const Locale('zh'));
  });

  group('catalog labels', () {
    test('known catalogs translate', () {
      expect(catalogLabel('Hmm.AutomobileMan.GasLog', zh), '加油记录');
      expect(catalogLabel(kGeneralCatalogName, zh), '常规');
      // Negative too: a locale silently falling back to English would still
      // satisfy a "returns something" check.
      expect(catalogLabel(kGeneralCatalogName, zh),
          isNot(catalogLabel(kGeneralCatalogName, en)));
    });

    test('a null catalog reads as a plain note', () {
      expect(catalogLabel(null, en), 'Note');
      expect(catalogLabel(null, zh), '笔记');
    });

    test('an unknown catalog falls back to its last segment, not blank', () {
      // A catalog added by a newer client must stay readable — untranslated is
      // acceptable, invisible is not.
      expect(catalogLabel('Hmm.FutureMan.SomethingNew', zh), 'SomethingNew');
    });

    test('every known catalog has a label in both locales', () {
      for (final name in const [
        kGeneralCatalogName,
        'Hmm.AutomobileMan.GasLog',
        'Hmm.AutomobileMan.AutomobileInfo',
        'Hmm.AutomobileMan.AutoInsurancePolicy',
        'Hmm.AutomobileMan.AutoScheduledService',
        'Hmm.AutomobileMan.ServiceRecord',
      ]) {
        expect(catalogLabel(name, en), isNotEmpty, reason: 'en missing $name');
        expect(catalogLabel(name, zh), isNotEmpty, reason: 'zh missing $name');
      }
    });
  });

  group('domain labels', () {
    test('domain keys translate', () {
      expect(domainLabel('AutomobileMan', zh), '车辆');
      expect(domainLabel('Other', zh), '其他');
    });

    test('an unknown domain falls back to the palette label', () {
      // domainStyle strips a trailing "Man": FutureMan -> Future.
      expect(domainLabel('FutureMan', zh), 'Future');
    });
  });

  group('subsystem anchors', () {
    // The anchor note's subject is a persisted English literal set by
    // ensureSubsystemAnchor. It is mapped to a label at render time and must
    // never be translated at the point it is stored.
    test('the anchor label is translated for display', () {
      expect(subsystemLabel('Automobile', zh), '车辆');
    });

    test('in English the label is the stored subject, unchanged', () {
      expect(subsystemLabel('Automobile', en), 'Automobile');
    });

    test('an unknown anchor renders its stored subject', () {
      expect(subsystemLabel('Boat', zh), 'Boat');
    });
  });
}
