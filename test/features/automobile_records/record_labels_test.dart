import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/line_item_type.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/service_type.dart';
import 'package:hmm_console/features/automobile_records/presentation/record_labels.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

/// Guards the split between what a user reads and what gets stored.
///
/// `ServiceType` carries three names and only one of them is translatable:
///
/// * `wireValue`   — sent to the API. English forever.
/// * `displayName` — composed into the persisted note subject by
///   `LocalServiceRecordRepository._subjectFor`. English forever.
/// * `.label(l)`   — shown on screen. Translated.
///
/// Nothing else in the suite would notice if `displayName` were localized: the
/// repository would keep working, the screens would keep rendering, and the
/// only symptom would be note subjects that quietly differ by device language.
void main() {
  late AppLocalizations en;
  late AppLocalizations zh;

  setUp(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
    zh = await AppLocalizations.delegate.load(const Locale('zh'));
  });

  group('labels are translated', () {
    test('service types render in Chinese', () {
      expect(ServiceType.oilChange.label(zh), '更换机油');
      expect(ServiceType.tireRotation.label(zh), '轮胎换位');
      // Asserted negatively too: a locale silently falling back to English
      // would still satisfy a "returns something" check.
      expect(ServiceType.oilChange.label(zh),
          isNot(ServiceType.oilChange.label(en)));
    });

    test('line item types render in Chinese', () {
      expect(LineItemType.labour.label(zh), '工时');
      expect(LineItemType.part.label(zh), '配件');
      expect(LineItemType.fee.label(zh), '费用');
    });

    test('every service type has a label in both locales', () {
      for (final t in ServiceType.values) {
        expect(t.label(en), isNotEmpty, reason: 'en label missing for $t');
        expect(t.label(zh), isNotEmpty, reason: 'zh label missing for $t');
      }
    });
  });

  group('stored names are not translated', () {
    test('wireValue is the API contract and stays English', () {
      expect(ServiceType.oilChange.wireValue, 'OilChange');
      expect(ServiceType.tireRotation.wireValue, 'TireRotation');
      expect(LineItemType.labour.wireName, 'Labour');
    });

    test('every wire value round-trips', () {
      for (final t in ServiceType.values) {
        expect(ServiceType.fromWire(t.wireValue), t);
      }
    });

    test('displayName stays English — it feeds the persisted note subject', () {
      // If this ever fails, service records created on a Chinese device will
      // carry a different note subject from the same record created in
      // English, and the two stop lining up across a user's own devices.
      expect(ServiceType.oilChange.displayName, 'Oil change');
      expect(ServiceType.tireRotation.displayName, 'Tire rotation');
      expect(ServiceType.other.displayName, 'Other');
    });

    test('displayName and the on-screen label are genuinely different things',
        () {
      // The whole point of record_labels.dart. In English they coincide; in
      // Chinese they must not, or displayName is being translated somewhere.
      expect(
          ServiceType.oilChange.displayName, ServiceType.oilChange.label(en));
      expect(ServiceType.oilChange.displayName,
          isNot(ServiceType.oilChange.label(zh)));
    });
  });
}
