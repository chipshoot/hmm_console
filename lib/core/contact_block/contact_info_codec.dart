import 'contact_info.dart';

/// `ContactInfo` <-> the JSON map embedded in an owning record's content.
///
/// The owner stores a LIST under a fixed key, so every feature embeds the same
/// shape at a predictable path. That predictability is what makes cheatsheet
/// binding work without configuration, and what would make a future migration
/// into real Contact records a mechanical sweep rather than archaeology.
class ContactInfoCodec {
  const ContactInfoCodec._();

  /// The agreed key. Every feature embedding contact blocks uses this exact
  /// name; nothing about the design works if features each pick their own.
  static const contactsKey = 'contacts';

  static const _knownKeys = <String>{
    'role',
    'name',
    'organization',
    'phone',
    'mobile',
    'fax',
    'email',
    'address',
    'notes',
  };

  /// Keys modelled INSIDE the address object; anything else found there is
  /// preserved in the address's own extraFields.
  static const _knownAddressKeys = <String>{
    'street',
    'city',
    'region',
    'postalCode',
    'country',
  };

  static Map<String, dynamic> toMap(ContactInfo c) => {
        // Preserved keys first, so a typed field overwrites them. Note this
        // only holds when the typed field is non-null: the optional keys below
        // are written conditionally, so a preserved value for a known key
        // survives when its typed field is absent.
        ...c.extraFields,
        'role': c.role,
        'name': c.name,
        if (c.organization != null) 'organization': c.organization,
        if (c.phone != null) 'phone': c.phone,
        if (c.mobile != null) 'mobile': c.mobile,
        if (c.fax != null) 'fax': c.fax,
        if (c.email != null) 'email': c.email,
        // An empty address is omitted entirely rather than written as an empty
        // object, so a block the user never filled in stays byte-identical.
        if (c.address != null && !c.address!.isEmpty)
          'address': _addressToMap(c.address!),
        if (c.notes != null) 'notes': c.notes,
      };

  static ContactInfo fromMap(Map<String, dynamic> m) => ContactInfo(
        role: _str(m['role']) ?? ContactRoles.other,
        name: _str(m['name']) ?? '',
        organization: _str(m['organization']),
        phone: _str(m['phone']),
        mobile: _str(m['mobile']),
        fax: _str(m['fax']),
        email: _str(m['email']),
        address: _addressFrom(m['address']),
        notes: _str(m['notes']),
        extraFields: {
          for (final e in m.entries)
            if (!_knownKeys.contains(e.key)) e.key: e.value,
        },
      );

  /// Reads the whole list out of an owning record's decoded content.
  ///
  /// Tolerant on purpose: persisted data may hold anything, and a type error
  /// here would cost the owning record, not just its contacts.
  static List<ContactInfo> listFrom(Object? raw) {
    if (raw is! List) return const [];
    final out = <ContactInfo>[];
    for (final e in raw) {
      if (e is! Map) continue;
      out.add(fromMap(e.cast<String, dynamic>()));
    }
    return out;
  }

  /// Writes the list back. Empty blocks are dropped so an untouched editor row
  /// does not persist as a blank contact.
  static List<Map<String, dynamic>> listTo(List<ContactInfo> contacts) =>
      contacts.where((c) => !c.isEmpty).map(toMap).toList();

  static Map<String, dynamic> _addressToMap(ContactAddress a) => {
        // Preserved keys first, so a typed field overwrites them - the same
        // ordering rule the block itself uses.
        ...a.extraFields,
        if (a.street != null) 'street': a.street,
        if (a.city != null) 'city': a.city,
        if (a.region != null) 'region': a.region,
        if (a.postalCode != null) 'postalCode': a.postalCode,
        if (a.country != null) 'country': a.country,
      };

  /// Reads either shape.
  ///
  /// Contacts saved before the address was structured hold a plain String
  /// here. That is not a malformed value to discard - it is a real address the
  /// user typed - so it is read as the street line.
  static ContactAddress? _addressFrom(Object? raw) {
    if (raw is String) {
      return raw.trim().isEmpty ? null : ContactAddress(street: raw);
    }
    if (raw is! Map) return null;
    final m = raw.cast<String, dynamic>();
    return ContactAddress(
      street: _str(m['street']),
      city: _str(m['city']),
      region: _str(m['region']),
      postalCode: _str(m['postalCode']),
      country: _str(m['country']),
      extraFields: {
        for (final e in m.entries)
          if (!_knownAddressKeys.contains(e.key)) e.key: e.value,
      },
    );
  }

  static String? _str(Object? v) => v is String ? v : null;
}
