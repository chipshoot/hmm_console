import 'contact_field.dart';

enum ContactType { person, organization }

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
  });

  final RelationshipCategory category;

  /// Free text, used when [category] is [RelationshipCategory.other].
  final String? customLabel;

  ContactRelationship copyWith({
    RelationshipCategory? category,
    String? customLabel,
  }) =>
      ContactRelationship(
        category: category ?? this.category,
        customLabel: customLabel ?? this.customLabel,
      );

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
    this.phones = const [],
    this.emails = const [],
    this.addresses = const [],
    this.relationship = const ContactRelationship(),
    this.isSelf = false,
    this.notes,
    this.isActivated = true,
    this.extraFields = const {},
  });

  final String id;
  final ContactType contactType;
  final String? firstName;
  final String? lastName;
  final String? organizationName;
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

  /// Derived, never stored: person and organization both present one name to
  /// the UI and to cheatsheet binding.
  String get displayName => switch (contactType) {
        ContactType.organization => organizationName ?? '',
        ContactType.person =>
          [firstName, lastName].whereType<String>().where((s) => s.isNotEmpty).join(' '),
      };

  Contact copyWith({
    String? id,
    ContactType? contactType,
    String? firstName,
    String? lastName,
    String? organizationName,
    List<ContactPhone>? phones,
    List<ContactEmail>? emails,
    List<ContactAddress>? addresses,
    ContactRelationship? relationship,
    bool? isSelf,
    String? notes,
    bool? isActivated,
    Map<String, dynamic>? extraFields,
  }) =>
      Contact(
        id: id ?? this.id,
        contactType: contactType ?? this.contactType,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        organizationName: organizationName ?? this.organizationName,
        phones: phones ?? this.phones,
        emails: emails ?? this.emails,
        addresses: addresses ?? this.addresses,
        relationship: relationship ?? this.relationship,
        isSelf: isSelf ?? this.isSelf,
        notes: notes ?? this.notes,
        isActivated: isActivated ?? this.isActivated,
        extraFields: extraFields ?? this.extraFields,
      );

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
        Object.hashAll(phones),
        Object.hashAll(emails),
        Object.hashAll(addresses),
        relationship,
        isSelf,
        notes,
        isActivated,
      );
}
