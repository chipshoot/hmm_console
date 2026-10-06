/// One labelled, repeatable contact field.
///
/// `label` is a STORED literal (`mobile` / `home` / `work` / `other`), never
/// translated - see `contact_labels.dart` for the display copy. Free text is
/// allowed so a user can keep a label this version does not know.
class ContactPhone {
  const ContactPhone({
    required this.label,
    required this.number,
    this.extraFields = const {},
    this.rawKnownValues = const {},
  });

  final String label;
  final String number;

  /// Unknown keys from the stored entry, preserved verbatim on save.
  final Map<String, dynamic> extraFields;

  /// Known keys whose stored value had the wrong type, kept verbatim and
  /// written back while the typed field still holds its decode default; see
  /// `ContactCodec`.
  final Map<String, dynamic> rawKnownValues;

  ContactPhone copyWith({
    String? label,
    String? number,
    Map<String, dynamic>? extraFields,
  }) =>
      ContactPhone(
        label: label ?? this.label,
        number: number ?? this.number,
        extraFields: extraFields ?? this.extraFields,
        rawKnownValues: rawKnownValues,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactPhone && other.label == label && other.number == number;

  @override
  int get hashCode => Object.hash(label, number);
}

class ContactEmail {
  const ContactEmail({
    required this.label,
    required this.address,
    this.extraFields = const {},
    this.rawKnownValues = const {},
  });

  final String label;
  final String address;

  /// Unknown keys from the stored entry, preserved verbatim on save.
  final Map<String, dynamic> extraFields;

  /// Known keys whose stored value had the wrong type, kept verbatim and
  /// written back while the typed field still holds its decode default; see
  /// `ContactCodec`.
  final Map<String, dynamic> rawKnownValues;

  ContactEmail copyWith({
    String? label,
    String? address,
    Map<String, dynamic>? extraFields,
  }) =>
      ContactEmail(
        label: label ?? this.label,
        address: address ?? this.address,
        extraFields: extraFields ?? this.extraFields,
        rawKnownValues: rawKnownValues,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactEmail && other.label == label && other.address == address;

  @override
  int get hashCode => Object.hash(label, address);
}

/// One labelled postal address.
///
/// Free-form when [country] is null: [value] is the user's text (possibly
/// multi-line). Structured when [country] is an ISO 3166-1 alpha-2 code the
/// editor knows (`US`, `CA`, `CN`; see `address_format.dart`): the parts live
/// in the nullable fields below and [value] is DERIVED from them on edit
/// (`formatSingleLine`), so tap-for-Maps, cheatsheet bindings
/// (`Contact.addresses.N.value`), search and older clients keep working.
class ContactAddress {
  const ContactAddress({
    required this.label,
    required this.value,
    this.country,
    this.street1,
    this.street2,
    this.city,
    this.district,
    this.region,
    this.postalCode,
    this.extraFields = const {},
    this.rawKnownValues = const {},
  });

  final String label;

  /// The canonical single-line address: the user's text for a free-form
  /// address, `formatSingleLine` of the parts for a structured one.
  final String value;

  /// ISO 3166-1 alpha-2, or null for a free-form address.
  final String? country;

  /// US/CA: street line. CN: 详细地址 (street, building, room).
  final String? street1;

  /// US/CA: apartment / suite / unit.
  final String? street2;

  /// US/CA: city. CN: 市.
  final String? city;

  /// CN only: 区/县.
  final String? district;

  /// State / province / territory code (`NY`, `ON`, `GD`); see
  /// `address_regions.dart`.
  final String? region;

  final String? postalCode;

  bool get isStructured => country != null;

  /// Unknown keys from the stored entry, preserved verbatim on save.
  final Map<String, dynamic> extraFields;

  /// Known keys whose stored value had the wrong type, kept verbatim and
  /// written back while the typed field still holds its decode default; see
  /// `ContactCodec`.
  final Map<String, dynamic> rawKnownValues;

  /// Copies with [label] / [value] / [extraFields] replaced. The structured
  /// parts are carried over; build a new [ContactAddress] to change them.
  ContactAddress copyWith({
    String? label,
    String? value,
    Map<String, dynamic>? extraFields,
  }) =>
      ContactAddress(
        label: label ?? this.label,
        value: value ?? this.value,
        country: country,
        street1: street1,
        street2: street2,
        city: city,
        district: district,
        region: region,
        postalCode: postalCode,
        extraFields: extraFields ?? this.extraFields,
        rawKnownValues: rawKnownValues,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactAddress &&
          other.label == label &&
          other.value == value &&
          other.country == country &&
          other.street1 == street1 &&
          other.street2 == street2 &&
          other.city == city &&
          other.district == district &&
          other.region == region &&
          other.postalCode == postalCode;

  @override
  int get hashCode => Object.hash(
        label,
        value,
        country,
        street1,
        street2,
        city,
        district,
        region,
        postalCode,
      );
}
