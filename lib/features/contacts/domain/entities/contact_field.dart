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
  }) => ContactPhone(
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
  }) => ContactEmail(
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

class ContactAddress {
  const ContactAddress({
    required this.label,
    required this.value,
    this.extraFields = const {},
    this.rawKnownValues = const {},
  });

  final String label;

  /// A single free-text postal address. Deliberately not split into
  /// street/city/postcode: the app already has a `geocoding` feature for
  /// lookup, and tap-for-Maps needs only a string.
  final String value;

  /// Unknown keys from the stored entry, preserved verbatim on save.
  final Map<String, dynamic> extraFields;

  /// Known keys whose stored value had the wrong type, kept verbatim and
  /// written back while the typed field still holds its decode default; see
  /// `ContactCodec`.
  final Map<String, dynamic> rawKnownValues;

  ContactAddress copyWith({
    String? label,
    String? value,
    Map<String, dynamic>? extraFields,
  }) => ContactAddress(
    label: label ?? this.label,
    value: value ?? this.value,
    extraFields: extraFields ?? this.extraFields,
    rawKnownValues: rawKnownValues,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactAddress && other.label == label && other.value == value;

  @override
  int get hashCode => Object.hash(label, value);
}
