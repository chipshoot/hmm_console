/// One labelled, repeatable contact field.
///
/// `label` is a STORED literal (`mobile` / `home` / `work` / `other`), never
/// translated - see `contact_labels.dart` for the display copy. Free text is
/// allowed so a user can keep a label this version does not know.
class ContactPhone {
  const ContactPhone({required this.label, required this.number});

  final String label;
  final String number;

  ContactPhone copyWith({String? label, String? number}) =>
      ContactPhone(label: label ?? this.label, number: number ?? this.number);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactPhone && other.label == label && other.number == number;

  @override
  int get hashCode => Object.hash(label, number);
}

class ContactEmail {
  const ContactEmail({required this.label, required this.address});

  final String label;
  final String address;

  ContactEmail copyWith({String? label, String? address}) =>
      ContactEmail(label: label ?? this.label, address: address ?? this.address);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactEmail && other.label == label && other.address == address;

  @override
  int get hashCode => Object.hash(label, address);
}

class ContactAddress {
  const ContactAddress({required this.label, required this.value});

  final String label;

  /// A single free-text postal address. Deliberately not split into
  /// street/city/postcode: the app already has a `geocoding` feature for
  /// lookup, and tap-for-Maps needs only a string.
  final String value;

  ContactAddress copyWith({String? label, String? value}) =>
      ContactAddress(label: label ?? this.label, value: value ?? this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactAddress && other.label == label && other.value == value;

  @override
  int get hashCode => Object.hash(label, value);
}
