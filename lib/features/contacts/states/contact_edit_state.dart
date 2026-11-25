import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/attachments/attachment_providers.dart';
import '../../../core/data/attachments/picker/image_attachment_picker.dart';
import '../../../core/data/attachments/picker/image_byte_source.dart';
import '../../../core/data/repository_providers.dart';

import '../domain/contact_name.dart';
import '../domain/entities/contact.dart';
import '../domain/entities/contact_birthday.dart';
import '../domain/entities/contact_field.dart';
import '../presentation/widgets/labeled_field_editor.dart';
import 'contacts_state.dart';

/// The in-progress contact plus form-level flags.
class ContactEditData {
  const ContactEditData({
    required this.contact,
    this.nameError = false,
    this.pendingPhoto,
    this.photoRemoved = false,
  });

  final Contact contact;

  /// Set after a refused save, cleared as soon as a name is typed.
  final bool nameError;

  /// A picked photo held until save (a new contact has no note to file it
  /// under yet).
  final PickedImageBytes? pendingPhoto;

  /// The stored photo is to be removed on save.
  final bool photoRemoved;
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
    final knownType = ContactType.values.any(
      (t) => t.name == c.storedContactTypeName,
    );
    if (knownType && c.contactType == ContactType.organization) return false;
    return !ContactName.isValidPhonetic(c.phoneticFamily ?? '') ||
        !ContactName.isValidPhonetic(c.phoneticGiven ?? '');
  }

  @override
  ContactEditData build() => ContactEditData(contact: initial);

  void _set(Contact c, {bool? nameError}) => state = ContactEditData(
    contact: c,
    nameError: nameError ?? state.nameError,
    pendingPhoto: state.pendingPhoto,
    photoRemoved: state.photoRemoved,
  );

  /// A photo will show after save: a picked one, or the stored one unless
  /// removed.
  bool get hasPhoto =>
      state.pendingPhoto != null ||
      (state.contact.photo != null && !state.photoRemoved);

  /// Opens the picker. A cancelled pick changes nothing; picker errors
  /// (e.g. `AttachmentPickerException`) propagate to the screen.
  Future<void> pickPhoto(AttachmentPickSource source) async {
    final picked = await ref.read(imageByteSourceProvider).pick(source);
    if (picked == null) return;
    // Refuse now what persistToVault would refuse at save, so the user hears
    // about the photo instead of a contact-save failure on every retry.
    checkImageForVault(
      bytes: picked.bytes,
      originalName: picked.originalName,
      contentTypeHint: picked.contentType,
    );
    state = ContactEditData(
      contact: state.contact,
      nameError: state.nameError,
      pendingPhoto: picked,
    );
  }

  void removePhoto() => state = ContactEditData(
    contact: state.contact,
    nameError: state.nameError,
    photoRemoved: true,
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
  void setEnglishName(String v) => _set(state.contact.copyWith(englishName: v));

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

  /// Clearing the birthday also turns Remind me off: there is nothing to
  /// remind about.
  void setBirthday(ContactBirthday? b) => _set(
    state.contact.copyWith(
      birthday: b,
      remindBirthday: b == null ? false : state.contact.remindBirthday,
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
    final knownType = ContactType.values.any(
      (t) => t.name == c.storedContactTypeName,
    );
    final dropPerson = knownType && isOrg;
    return c.copyWith(
      firstName: dropPerson ? null : _part(c.firstName, o.firstName),
      lastName: dropPerson ? null : _part(c.lastName, o.lastName),
      organizationName: !knownType || isOrg
          ? _part(c.organizationName, o.organizationName)
          : null,
      // Person-only options, dropped with the person names.
      nameOrder: dropPerson ? ContactNameOrder.auto : c.nameOrder,
      phoneticFamily: dropPerson
          ? null
          : _part(c.phoneticFamily, o.phoneticFamily),
      phoneticGiven: dropPerson
          ? null
          : _part(c.phoneticGiven, o.phoneticGiven),
      // Both types have one: a clinic has an English name too.
      englishName: _part(c.englishName, o.englishName),
      phones: c.phones
          .where(
            (p) =>
                p.number.trim().isNotEmpty ||
                p.rawKnownValues.containsKey('number'),
          )
          .toList(),
      emails: c.emails
          .where(
            (e) =>
                e.address.trim().isNotEmpty ||
                e.rawKnownValues.containsKey('address'),
          )
          .toList(),
      // Any raw (malformed) stored part keeps the address: the codec still
      // has a value to write back.
      addresses: c.addresses
          .where(
            (a) => a.value.trim().isNotEmpty || a.rawKnownValues.isNotEmpty,
          )
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
      final contacts = ref.read(contactsStateProvider.notifier);
      final pending = state.pendingPhoto;
      final saved = await contacts.save(
        state.photoRemoved ? contact.copyWith(photo: null) : contact,
      );
      if (pending != null) {
        // Hold the saved contact (and its minted id) so a retry after a failed
        // photo store updates this contact instead of creating a second one.
        _set(saved);
        // Filed under the contact's note, which exists only after the save.
        final noteId = await ref
            .read(contactRepositoryModeProvider)
            .noteIdFor(saved.id);
        final picker = await ref.read(imageAttachmentPickerProvider.future);
        final photo = await picker.persistToVault(
          noteId: noteId!,
          bytes: pending.bytes,
          originalName: pending.originalName,
          contentTypeHint: pending.contentType,
        );
        await contacts.save(saved.copyWith(photo: photo));
      }
      return true;
    } catch (_) {
      _inFlight = false;
      rethrow;
    }
  }
}

final contactEditStateProvider = NotifierProvider.autoDispose
    .family<ContactEditState, ContactEditData, Contact>(ContactEditState.new);
