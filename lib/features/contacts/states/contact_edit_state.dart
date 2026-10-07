import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/contact_name.dart';
import '../domain/entities/contact.dart';
import '../domain/entities/contact_field.dart';
import '../presentation/widgets/labeled_field_editor.dart';
import 'contacts_state.dart';

/// The in-progress contact plus form-level flags.
class ContactEditData {
  const ContactEditData({required this.contact, this.nameError = false});

  final Contact contact;

  /// Set after a refused save, cleared as soon as a name is typed.
  final bool nameError;
}

/// Form state for creating or editing one contact. Family-keyed by the
/// starting contact (a blank-id contact means create).
class ContactEditState extends Notifier<ContactEditData> {
  ContactEditState(this.initial);

  final Contact initial;

  /// Held from the first save call until it FAILS. It is deliberately not
  /// released on success: the screen is about to pop, and a second tap in that
  /// gap must not mint a second record (cheatsheet once did exactly that).
  bool _inFlight = false;

  bool _addressesInvalid = false;

  /// An edited address has a malformed postal code, so [save] will refuse.
  bool get addressesInvalid => _addressesInvalid;

  /// A phonetic field holds something other than Latin letters, spaces and
  /// apostrophes, so [save] will refuse.
  bool get phoneticInvalid {
    final c = state.contact;
    // Phonetic fields are person-only: for a known organization they are
    // hidden and dropped on save, so they cannot refuse it.
    final knownType =
        ContactType.values.any((t) => t.name == c.storedContactTypeName);
    if (knownType && c.contactType == ContactType.organization) return false;
    return !ContactName.isValidPhonetic(c.phoneticFamily ?? '') ||
        !ContactName.isValidPhonetic(c.phoneticGiven ?? '');
  }

  @override
  ContactEditData build() => ContactEditData(contact: initial);

  void _set(Contact c, {bool? nameError}) => state = ContactEditData(
    contact: c,
    nameError: nameError ?? state.nameError,
  );

  void setType(ContactType t) => _set(state.contact.copyWith(contactType: t));

  void setFirstName(String v) =>
      _set(state.contact.copyWith(firstName: v), nameError: false);
  void setLastName(String v) =>
      _set(state.contact.copyWith(lastName: v), nameError: false);
  void setOrganizationName(String v) =>
      _set(state.contact.copyWith(organizationName: v), nameError: false);

  void setNameOrder(ContactNameOrder o) =>
      _set(state.contact.copyWith(nameOrder: o));
  void setPhoneticFamily(String v) =>
      _set(state.contact.copyWith(phoneticFamily: v));
  void setPhoneticGiven(String v) =>
      _set(state.contact.copyWith(phoneticGiven: v));

  void setPhones(List<LabeledFieldEntry> rows) => _set(
    state.contact.copyWith(
      phones: [
        for (final r in rows)
          ContactPhone(
            label: r.label,
            number: r.value,
            extraFields: r.extraFields,
            rawKnownValues: r.rawKnownValues,
          ),
      ],
    ),
  );

  void setEmails(List<LabeledFieldEntry> rows) => _set(
    state.contact.copyWith(
      emails: [
        for (final r in rows)
          ContactEmail(
            label: r.label,
            address: r.value,
            extraFields: r.extraFields,
            rawKnownValues: r.rawKnownValues,
          ),
      ],
    ),
  );

  /// [invalid]: an edited address has a malformed postal code; [save] is
  /// refused until a later call clears it.
  void setAddresses(List<ContactAddress> addresses, {bool invalid = false}) {
    _addressesInvalid = invalid;
    _set(state.contact.copyWith(addresses: addresses));
  }

  /// Leaving `other` drops the free-text label: it only describes `other`, and
  /// keeping it would persist a stale label under, say, Doctor.
  void setRelationship(RelationshipCategory c) {
    final rel = state.contact.relationship;
    _set(
      state.contact.copyWith(
        relationship: c == RelationshipCategory.other
            ? rel.copyWith(category: c)
            : rel.copyWith(category: c, customLabel: null),
      ),
    );
  }

  void setCustomLabel(String v) => _set(
    state.contact.copyWith(
      relationship: state.contact.relationship.copyWith(
        customLabel: v.trim().isEmpty ? null : v,
      ),
    ),
  );

  /// Marking a contact as "me" also files it under the `self` relationship;
  /// switching it off leaves the relationship as the user last had it.
  void setIsSelf(bool v) => _set(
    state.contact.copyWith(
      isSelf: v,
      relationship: v
          ? state.contact.relationship.copyWith(
              category: RelationshipCategory.self,
              customLabel: null,
            )
          : null,
    ),
  );

  void setNotes(String v) =>
      _set(state.contact.copyWith(notes: v.trim().isEmpty ? null : v));

  String? _blankToNull(String? s) {
    final t = s?.trim() ?? '';
    return t.isEmpty ? null : t;
  }

  /// [edited] trimmed (blank → null), unless its trimmed value equals the
  /// trimmed [original]: then the stored value is kept verbatim, so opening
  /// and saving without a real edit writes back exactly what was stored.
  String? _part(String? edited, String? original) {
    final t = _blankToNull(edited);
    return t == _blankToNull(original) ? original : t;
  }

  /// The contact as it will be stored: edited names trimmed, empty rows
  /// dropped. A row whose stored value this version could not read shows
  /// empty but is not empty: it is kept so the codec can write that value
  /// back.
  Contact _normalized() {
    final c = state.contact;
    final o = initial;
    // The inactive type's names are nulled here, not on toggle, so toggling
    // back and forth before saving keeps the typed text but nothing hidden
    // is persisted.
    final isOrg = c.contactType == ContactType.organization;
    // A stored type this version does not know (a newer client's) is neither
    // person nor organization here, so neither set of names may be dropped.
    final knownType =
        ContactType.values.any((t) => t.name == c.storedContactTypeName);
    final dropPerson = knownType && isOrg;
    return c.copyWith(
      firstName: dropPerson ? null : _part(c.firstName, o.firstName),
      lastName: dropPerson ? null : _part(c.lastName, o.lastName),
      organizationName: !knownType || isOrg
          ? _part(c.organizationName, o.organizationName)
          : null,
      // Person-only options, dropped with the person names.
      nameOrder: dropPerson ? ContactNameOrder.auto : c.nameOrder,
      phoneticFamily:
          dropPerson ? null : _part(c.phoneticFamily, o.phoneticFamily),
      phoneticGiven:
          dropPerson ? null : _part(c.phoneticGiven, o.phoneticGiven),
      phones: c.phones
          .where((p) =>
              p.number.trim().isNotEmpty ||
              p.rawKnownValues.containsKey('number'))
          .toList(),
      emails: c.emails
          .where((e) =>
              e.address.trim().isNotEmpty ||
              e.rawKnownValues.containsKey('address'))
          .toList(),
      // Any raw (malformed) stored part keeps the address: the codec still
      // has a value to write back.
      addresses: c.addresses
          .where((a) =>
              a.value.trim().isNotEmpty || a.rawKnownValues.isNotEmpty)
          .toList(),
    );
  }

  /// Returns true when the contact was saved. A refused (nameless) or
  /// duplicate call returns false; a repository failure rethrows after
  /// releasing the guard so the user can retry.
  Future<bool> save() async {
    if (_inFlight || _addressesInvalid || phoneticInvalid) return false;
    _inFlight = true;
    final contact = _normalized();
    if (contact.displayName.isEmpty) {
      _inFlight = false;
      _set(state.contact, nameError: true);
      return false;
    }
    try {
      await ref.read(contactsStateProvider.notifier).save(contact);
      return true;
    } catch (_) {
      _inFlight = false;
      rethrow;
    }
  }
}

final contactEditStateProvider = NotifierProvider.autoDispose
    .family<ContactEditState, ContactEditData, Contact>(ContactEditState.new);
