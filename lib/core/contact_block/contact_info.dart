/// A reusable block of contact details, embedded in another record's own
/// note content rather than stored as a record of its own.
///
/// One shape, one editor, one renderer, used by any feature that needs to
/// record "who to call": an insurance agent, a family doctor, a hospital's
/// main line, a friend. The owning note carries a `contacts` LIST, so a record
/// needing two numbers (a main line and an emergency line) holds two entries
/// rather than growing a nested structure.
///
/// Deliberately a value object, not an entity. It has no id and no independent
/// lifecycle: it is created, edited and deleted with whatever owns it. The
/// trade-off is real and worth knowing - the same doctor embedded in three
/// notes is three copies, and changing the number means three edits. That buys
/// no catalog, no repository, and no address-book feature.
///
/// Because `NotePieceExtractor` walks note content into dotted leaf paths, an
/// embedded block is cheatsheet-bindable for free: a row can bind
/// `AutoInsurancePolicy.contacts.0.phone` with no extra plumbing.
class ContactInfo {
  const ContactInfo({
    this.role = ContactRoles.other,
    this.name = '',
    this.organization,
    this.phone,
    this.email,
    this.address,
    this.notes,
    this.extraFields = const {},
  });

  /// A STORED literal (`agent`, `doctor`, ...), never a translated label.
  /// Free text is accepted so a role this version does not know still round
  /// trips. Display copy lives in `contact_info_labels.dart`.
  final String role;

  final String name;
  final String? organization;
  final String? phone;
  final String? email;

  /// A single free-text postal address; tap-for-Maps needs only a string, and
  /// the app already has a `geocoding` feature for lookup.
  final String? address;

  final String? notes;

  /// Keys this version does not model, kept verbatim so an older client cannot
  /// destroy a newer one's data.
  final Map<String, dynamic> extraFields;

  bool get isEmpty =>
      name.trim().isEmpty &&
      (organization ?? '').trim().isEmpty &&
      (phone ?? '').trim().isEmpty &&
      (email ?? '').trim().isEmpty &&
      (address ?? '').trim().isEmpty &&
      (notes ?? '').trim().isEmpty;

  /// The block's heading: a person's name when there is one, otherwise the
  /// organization, so a hospital entry with no named contact still reads as
  /// something.
  String get displayName =>
      name.trim().isNotEmpty ? name.trim() : (organization ?? '').trim();

  /// Note this CANNOT clear a field: every parameter falls back to the current
  /// value, so passing null means "leave it alone". To clear something, build a
  /// ContactInfo directly - see `ContactInfoEditor._emit`.
  ContactInfo copyWith({
    String? role,
    String? name,
    String? organization,
    String? phone,
    String? email,
    String? address,
    String? notes,
    Map<String, dynamic>? extraFields,
  }) =>
      ContactInfo(
        role: role ?? this.role,
        name: name ?? this.name,
        organization: organization ?? this.organization,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        address: address ?? this.address,
        notes: notes ?? this.notes,
        extraFields: extraFields ?? this.extraFields,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactInfo &&
          other.role == role &&
          other.name == name &&
          other.organization == organization &&
          other.phone == phone &&
          other.email == email &&
          other.address == address &&
          other.notes == notes;

  @override
  int get hashCode =>
      Object.hash(role, name, organization, phone, email, address, notes);
}

/// The roles offered in the picker. These are the values written to JSON, so
/// they stay literal and stable; anything else the user types is kept as typed.
/// See `contactRoleLabel` for what a person reads.
class ContactRoles {
  const ContactRoles._();

  static const agent = 'agent';
  static const doctor = 'doctor';
  static const hospital = 'hospital';
  static const pharmacy = 'pharmacy';
  static const emergency = 'emergency';
  static const friend = 'friend';
  static const family = 'family';
  static const other = 'other';

  static const known = <String>[
    agent,
    doctor,
    hospital,
    pharmacy,
    emergency,
    friend,
    family,
    other,
  ];
}
