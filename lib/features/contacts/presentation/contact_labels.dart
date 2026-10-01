import '../../../l10n/gen/app_localizations.dart';
import '../domain/entities/contact.dart';

/// Display copy for the contact enums.
///
/// The split is deliberate and load-bearing. `RelationshipCategory.name` and
/// the phone/email/address `label` strings are PERSISTED in the contact's note
/// JSON and synced across devices. Localizing them at the source would write
/// display text into stored data, so the same contact would read differently
/// per device language - and a value saved on a Chinese device would no longer
/// match anything on an English one. See `lib/core/i18n/enum_labels.dart`,
/// where this exact mistake was found and fixed.
String relationshipLabel(RelationshipCategory c, AppLocalizations l) =>
    switch (c) {
      RelationshipCategory.self => l.relationshipSelf,
      RelationshipCategory.spouse => l.relationshipSpouse,
      RelationshipCategory.parent => l.relationshipParent,
      RelationshipCategory.child => l.relationshipChild,
      RelationshipCategory.family => l.relationshipFamily,
      RelationshipCategory.friend => l.relationshipFriend,
      RelationshipCategory.doctor => l.relationshipDoctor,
      RelationshipCategory.pharmacy => l.relationshipPharmacy,
      RelationshipCategory.insurer => l.relationshipInsurer,
      RelationshipCategory.other => l.relationshipOther,
    };

String contactTypeLabel(ContactType t, AppLocalizations l) => switch (t) {
  ContactType.person => l.contactTypePerson,
  ContactType.organization => l.contactTypeOrganization,
};

/// The stored labels each kind of field offers in the editor. Defined once
/// here, next to [fieldLabelText], so the picker and the display copy cannot
/// drift: every entry must have copy in [_fieldLabelCopy] (asserted by test).
const phoneFieldLabels = ['mobile', 'home', 'work', 'other'];
const emailFieldLabels = ['personal', 'work', 'other'];
const addressFieldLabels = ['home', 'work', 'other'];

final Map<String, String Function(AppLocalizations)> _fieldLabelCopy = {
  'mobile': (l) => l.fieldLabelMobile,
  'home': (l) => l.fieldLabelHome,
  'work': (l) => l.fieldLabelWork,
  'personal': (l) => l.fieldLabelPersonal,
  'other': (l) => l.fieldLabelOther,
};

/// True when [stored] has translated display copy (not just a raw fallback).
bool isKnownFieldLabel(String stored) => _fieldLabelCopy.containsKey(stored);

/// Display copy for a stored field label (`mobile`, `work`, ...).
///
/// Falls back to the raw stored value so a label written by a newer client, or
/// typed by the user, still reads as itself rather than disappearing.
String fieldLabelText(String stored, AppLocalizations l) =>
    _fieldLabelCopy[stored]?.call(l) ?? stored;
