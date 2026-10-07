import 'contact_field.dart';
import '../contact_name.dart';

/// Sentinel value for copyWith to distinguish "not provided" from "null".
const Object _kSentinel = Object();

enum ContactType { person, organization }

/// Per-contact display order override. Stored by `name` under `nameOrder`
/// only when not [auto]. NEVER localize; display copy is in
/// `contact_labels.dart`.
enum ContactNameOrder { auto, givenFirst, familyFirst }

/// Stored by `name` in the note JSON. NEVER localize these; add display copy
/// to `contact_labels.dart` instead.
enum RelationshipCategory {
  self,
  spouse,
  parent,
  child,
  family,
  friend,
  doctor,
  pharmacy,
  insurer,
  other,
}

class ContactRelationship {
  const ContactRelationship({
    this.category = RelationshipCategory.other,
    this.customLabel,
    this.extraFields = const {},
    this.rawKnownValues = const {},
    String? rawCategory,
  }) : _rawCategory = rawCategory;

  final RelationshipCategory category;

  /// Free text, used when [category] is [RelationshipCategory.other].
  final String? customLabel;

  /// Unknown keys from the stored entry, preserved verbatim on save.
  final Map<String, dynamic> extraFields;

  /// Known keys whose stored value had the wrong type; see `ContactCodec`.
  final Map<String, dynamic> rawKnownValues;

  /// Raw enum string from storage (to preserve unknown values).
  final String? _rawCategory;

  /// Returns the category name to store: raw value if available and unchanged,
  /// otherwise the typed enum name.
  String get storedCategoryName => _rawCategory ?? category.name;

  ContactRelationship copyWith({
    RelationshipCategory? category,
    Object? customLabel = _kSentinel,
    Map<String, dynamic>? extraFields,
  }) {
    final newCategory = category ?? this.category;
    final newCustomLabel = identical(customLabel, _kSentinel)
        ? this.customLabel
        : customLabel as String?;
    return ContactRelationship(
      category: newCategory,
      customLabel: newCustomLabel,
      extraFields: extraFields ?? this.extraFields,
      rawKnownValues: rawKnownValues,
      rawCategory: category != null ? null : _rawCategory,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactRelationship &&
          other.category == category &&
          other.customLabel == customLabel;

  @override
  int get hashCode => Object.hash(category, customLabel);
}

/// A person or organization in the address book.
///
/// Persisted as an `HmmNote`'s content under `Hmm.ContactMan.Contact`; see
/// `LocalContactRepository`. [id] is also the note's subject identity
/// (`Contact:{id}`), so it must never track the mutable name.
class Contact {
  const Contact({
    required this.id,
    required this.contactType,
    this.firstName,
    this.lastName,
    this.organizationName,
    this.nameOrder = ContactNameOrder.auto,
    this.phoneticFamily,
    this.phoneticGiven,
    this.phones = const [],
    this.emails = const [],
    this.addresses = const [],
    this.relationship = const ContactRelationship(),
    this.isSelf = false,
    this.notes,
    this.isActivated = true,
    this.extraFields = const {},
    this.storedSchemaVersion = 1,
    this.rawKnownValues = const {},
    this.unreadableEntries = const {},
    this.storedDisplayName,
    String? rawContactType,
  }) : _rawContactType = rawContactType;

  /// The `schemaVersion` this contact was read with. A save writes the larger
  /// of this and the codec's current version, so an older client never
  /// downgrades a newer client's data.
  final int storedSchemaVersion;

  final String id;
  final ContactType contactType;

  /// The GIVEN name (stored key `firstName`).
  final String? firstName;

  /// The FAMILY name (stored key `lastName`).
  final String? lastName;
  final String? organizationName;

  /// Display-order override; see `ContactName.effectiveOrder`.
  final ContactNameOrder nameOrder;

  /// Optional romanization of [lastName] / [firstName]. When set it wins over
  /// automatic pinyin for sort and search; it never changes the display.
  final String? phoneticFamily;
  final String? phoneticGiven;

  final List<ContactPhone> phones;
  final List<ContactEmail> emails;
  final List<ContactAddress> addresses;
  final ContactRelationship relationship;

  /// Marks the "me" contact. At most one across all contacts; enforced in the
  /// repository, not here, because it is a collection-wide rule.
  final bool isSelf;

  final String? notes;

  /// Soft delete. A deactivated contact still resolves, so a cheatsheet row
  /// bound to it degrades to "source removed" instead of dangling.
  final bool isActivated;

  /// Top-level JSON keys this version does not model, kept verbatim so a save
  /// here cannot destroy a newer client's data.
  final Map<String, dynamic> extraFields;

  /// Known top-level keys whose stored value had the wrong type, kept
  /// verbatim and written back while the typed field still holds what that
  /// value decoded to; see `ContactCodec`.
  final Map<String, dynamic> rawKnownValues;

  /// List entries (by list key: `phones`, `emails`, `addresses`) that could
  /// not be decoded. Never shown or edited; re-emitted after the readable
  /// entries on save so they are not lost.
  final Map<String, List<dynamic>> unreadableEntries;

  /// The `displayName` exactly as stored (any JSON type), or null for a
  /// contact never decoded. `ContactCodec.toMap` writes it back instead of
  /// the derived name while the contact is unchanged since decode, so an
  /// untouched save is byte-identical. [copyWith] drops it on any change.
  final Object? storedDisplayName;

  /// Raw enum string from storage (to preserve unknown values).
  final String? _rawContactType;

  /// Returns the contact type name to store: raw value if available and unchanged,
  /// otherwise the typed enum name.
  String get storedContactTypeName => _rawContactType ?? contactType.name;

  /// Derived, never read back: see `ContactName.displayName`.
  String get displayName => ContactName.displayName(this);

  /// [storedDisplayName] survives only a copy equal to this one (a no-op
  /// edit, `copyWith(id: sameId)` in the repository, a normalized but
  /// unchanged form). Any real change re-derives the name on save.
  Contact copyWith({
    String? id,
    ContactType? contactType,
    Object? firstName = _kSentinel,
    Object? lastName = _kSentinel,
    Object? organizationName = _kSentinel,
    ContactNameOrder? nameOrder,
    Object? phoneticFamily = _kSentinel,
    Object? phoneticGiven = _kSentinel,
    List<ContactPhone>? phones,
    List<ContactEmail>? emails,
    List<ContactAddress>? addresses,
    ContactRelationship? relationship,
    bool? isSelf,
    Object? notes = _kSentinel,
    bool? isActivated,
    Map<String, dynamic>? extraFields,
  }) {
    final next = Contact(
      id: id ?? this.id,
      contactType: contactType ?? this.contactType,
      firstName:
          identical(firstName, _kSentinel) ? this.firstName : firstName as String?,
      lastName: identical(lastName, _kSentinel) ? this.lastName : lastName as String?,
      organizationName: identical(organizationName, _kSentinel)
          ? this.organizationName
          : organizationName as String?,
      nameOrder: nameOrder ?? this.nameOrder,
      phoneticFamily: identical(phoneticFamily, _kSentinel)
          ? this.phoneticFamily
          : phoneticFamily as String?,
      phoneticGiven: identical(phoneticGiven, _kSentinel)
          ? this.phoneticGiven
          : phoneticGiven as String?,
      phones: phones ?? this.phones,
      emails: emails ?? this.emails,
      addresses: addresses ?? this.addresses,
      relationship: relationship ?? this.relationship,
      isSelf: isSelf ?? this.isSelf,
      notes: identical(notes, _kSentinel) ? this.notes : notes as String?,
      isActivated: isActivated ?? this.isActivated,
      extraFields: extraFields ?? this.extraFields,
      storedSchemaVersion: storedSchemaVersion,
      rawKnownValues: rawKnownValues,
      unreadableEntries: unreadableEntries,
      rawContactType: contactType != null ? null : _rawContactType,
    );
    if (storedDisplayName == null || next != this) return next;
    return Contact(
      id: next.id,
      contactType: next.contactType,
      firstName: next.firstName,
      lastName: next.lastName,
      organizationName: next.organizationName,
      nameOrder: next.nameOrder,
      phoneticFamily: next.phoneticFamily,
      phoneticGiven: next.phoneticGiven,
      phones: next.phones,
      emails: next.emails,
      addresses: next.addresses,
      relationship: next.relationship,
      isSelf: next.isSelf,
      notes: next.notes,
      isActivated: next.isActivated,
      extraFields: next.extraFields,
      storedSchemaVersion: next.storedSchemaVersion,
      rawKnownValues: next.rawKnownValues,
      unreadableEntries: next.unreadableEntries,
      storedDisplayName: storedDisplayName,
      rawContactType: next._rawContactType,
    );
  }

  static bool _sameList<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Contact &&
          other.id == id &&
          other.contactType == contactType &&
          other.firstName == firstName &&
          other.lastName == lastName &&
          other.organizationName == organizationName &&
          other.nameOrder == nameOrder &&
          other.phoneticFamily == phoneticFamily &&
          other.phoneticGiven == phoneticGiven &&
          _sameList(other.phones, phones) &&
          _sameList(other.emails, emails) &&
          _sameList(other.addresses, addresses) &&
          other.relationship == relationship &&
          other.isSelf == isSelf &&
          other.notes == notes &&
          other.isActivated == isActivated;

  @override
  int get hashCode => Object.hash(
        id,
        contactType,
        firstName,
        lastName,
        organizationName,
        nameOrder,
        phoneticFamily,
        phoneticGiven,
        Object.hashAll(phones),
        Object.hashAll(emails),
        Object.hashAll(addresses),
        relationship,
        isSelf,
        notes,
        isActivated,
      );
}
