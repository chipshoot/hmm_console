import 'dart:collection';

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
    this.mobile,
    this.fax,
    this.email,
    this.address,
    this.notes,
    Map<String, dynamic> extraFields = const {},
  }) : _extraFields = extraFields;

  /// A STORED literal (`agent`, `doctor`, ...), never a translated label.
  /// Free text is accepted so a role this version does not know still round
  /// trips. Display copy lives in `contact_info_labels.dart`.
  final String role;

  final String name;
  final String? organization;

  /// Three separate numbers rather than one, because an agent's landline,
  /// cell and fax are genuinely different things to reach them on and a
  /// single field forces the user to pick one.
  ///
  /// All three are stored EXACTLY as typed, punctuation included. Normalizing
  /// to digits would make what is stored differ from what was entered, and
  /// re-rendering an international number correctly needs a real phone
  /// library. A `tel:` launcher can strip non-digits at the point of use.
  final String? phone;
  final String? mobile;
  final String? fax;

  final String? email;

  /// Structured rather than one free-text line, so a postal code and a city
  /// are separately enterable, autofillable and bindable. Reading tolerates
  /// the legacy plain string - see `ContactInfoCodec`.
  final ContactAddress? address;

  final String? notes;

  final Map<String, dynamic> _extraFields;

  /// Keys this version does not model, kept verbatim so an older client cannot
  /// destroy a newer one's data.
  ///
  /// Exposed unmodifiable: this map's entire job is preservation, so editing
  /// it through the getter must not be possible. A view rather than a copy, to
  /// keep the constructor const - a caller that holds on to the map it passed
  /// in can still change it, but that takes deliberate effort rather than a
  /// slip.
  Map<String, dynamic> get extraFields => UnmodifiableMapView(_extraFields);

  /// Note this is a SAVE-TIME FILTER: ContactInfoCodec.listTo drops empty
  /// blocks. So a block carrying only fields this version does not understand
  /// must NOT count as empty, or the save would destroy exactly the data
  /// extraFields exists to preserve.
  bool get isEmpty =>
      extraFields.isEmpty &&
      name.trim().isEmpty &&
      (organization ?? '').trim().isEmpty &&
      (phone ?? '').trim().isEmpty &&
      (mobile ?? '').trim().isEmpty &&
      (fax ?? '').trim().isEmpty &&
      (email ?? '').trim().isEmpty &&
      (address?.isEmpty ?? true) &&
      (notes ?? '').trim().isEmpty;

  /// The block's heading: a person's name when there is one, otherwise the
  /// organization, so a hospital entry with no named contact still reads as
  /// something.
  String get displayName =>
      name.trim().isNotEmpty ? name.trim() : (organization ?? '').trim();

  /// Deliberately limited to the two NON-NULLABLE fields.
  ///
  /// A general copyWith would read `phone ?? this.phone`, so passing null
  /// could not express "clear the phone" - it is indistinguishable from "leave
  /// it alone", which fails silently with wrong data rather than loudly. Since
  /// role and name can never be null, that ambiguity cannot arise here. To
  /// change any nullable field, construct a ContactInfo directly and say
  /// exactly what every field should be - see `ContactInfoEditor._emit`.
  ContactInfo copyWith({String? role, String? name}) => ContactInfo(
        role: role ?? this.role,
        name: name ?? this.name,
        organization: organization,
        phone: phone,
        mobile: mobile,
        fax: fax,
        email: email,
        address: address,
        notes: notes,
        extraFields: extraFields,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactInfo &&
          other.role == role &&
          other.name == name &&
          other.organization == organization &&
          other.phone == phone &&
          other.mobile == mobile &&
          other.fax == fax &&
          other.email == email &&
          other.address == address &&
          other.notes == notes;

  @override
  int get hashCode => Object.hash(
      role, name, organization, phone, mobile, fax, email, address, notes);
}

/// The postal parts of a contact's address.
///
/// A value object inside a value object: no id, no lifecycle, meaningless
/// apart from the [ContactInfo] that holds it. Split into fields so the OS can
/// autofill a saved address, so a postal code is enterable without hunting
/// through one long line, and so a cheatsheet row can bind `address.city`.
class ContactAddress {
  const ContactAddress({
    this.street,
    this.city,
    this.region,
    this.postalCode,
    this.country,
    Map<String, dynamic> extraFields = const {},
  }) : _extraFields = extraFields;

  final String? street;
  final String? city;

  /// Province, state, prefecture - whatever the country calls the tier
  /// between city and country. Deliberately neutral: naming it `province`
  /// would read wrong for most of the world.
  final String? region;

  final String? postalCode;
  final String? country;

  final Map<String, dynamic> _extraFields;

  /// Unknown keys found INSIDE the address object, kept verbatim. The block's
  /// losslessness contract has to hold one level down too, or nesting the
  /// address would open a hole exactly where none existed.
  Map<String, dynamic> get extraFields => UnmodifiableMapView(_extraFields);

  bool get isEmpty =>
      extraFields.isEmpty &&
      (street ?? '').trim().isEmpty &&
      (city ?? '').trim().isEmpty &&
      (region ?? '').trim().isEmpty &&
      (postalCode ?? '').trim().isEmpty &&
      (country ?? '').trim().isEmpty;

  /// The address as one searchable line, for handing to a maps app.
  ///
  /// Region and postal code join with a space rather than a comma because
  /// that is how a printed address reads: `Ottawa, ON K1A 0B1`.
  String get singleLine {
    final regionAndPostal =
        [region, postalCode].map(_clean).whereType<String>().join(' ');
    return [
      _clean(street),
      _clean(city),
      regionAndPostal.isEmpty ? null : regionAndPostal,
      _clean(country),
    ].whereType<String>().join(', ');
  }

  /// The lines a human reads, top to bottom, with the empty ones left out.
  List<String> get displayLines {
    final regionAndPostal =
        [region, postalCode].map(_clean).whereType<String>().join(' ');
    return [
      _clean(street),
      [_clean(city), regionAndPostal.isEmpty ? null : regionAndPostal]
          .whereType<String>()
          .join(', '),
      _clean(country),
    ].whereType<String>().where((l) => l.isNotEmpty).toList();
  }

  static String? _clean(String? v) {
    final t = (v ?? '').trim();
    return t.isEmpty ? null : t;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactAddress &&
          other.street == street &&
          other.city == city &&
          other.region == region &&
          other.postalCode == postalCode &&
          other.country == country;

  @override
  int get hashCode => Object.hash(street, city, region, postalCode, country);
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
