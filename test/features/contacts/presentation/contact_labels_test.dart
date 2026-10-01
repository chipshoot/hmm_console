import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';
import 'package:hmm_console/features/contacts/presentation/contact_labels.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

void main() {
  late AppLocalizations en;
  late AppLocalizations zh;

  setUp(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
    zh = await AppLocalizations.delegate.load(const Locale('zh'));
  });

  test('every relationship category has a label in both locales', () {
    for (final c in RelationshipCategory.values) {
      expect(relationshipLabel(c, en), isNotEmpty, reason: '$c missing en');
      expect(relationshipLabel(c, zh), isNotEmpty, reason: '$c missing zh');
    }
  });

  test('labels are display copy, never the stored enum name', () {
    expect(
      relationshipLabel(RelationshipCategory.insurer, zh),
      isNot(RelationshipCategory.insurer.name),
    );
    expect(
      relationshipLabel(RelationshipCategory.doctor, zh),
      isNot(RelationshipCategory.doctor.name),
    );
  });

  test('an unknown stored field label falls back to the raw value', () {
    expect(fieldLabelText('carrier-pigeon', en), 'carrier-pigeon');
  });

  test('every label the editor offers has display copy in both locales', () {
    for (final label in [
      ...phoneFieldLabels,
      ...emailFieldLabels,
      ...addressFieldLabels,
    ]) {
      expect(isKnownFieldLabel(label), isTrue, reason: '$label');
      expect(fieldLabelText(label, en), isNot(label), reason: '$label en');
      expect(fieldLabelText(label, zh), isNot(label), reason: '$label zh');
    }
  });
}
