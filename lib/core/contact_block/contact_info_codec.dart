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
    'email',
    'address',
    'notes',
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
        if (c.email != null) 'email': c.email,
        if (c.address != null) 'address': c.address,
        if (c.notes != null) 'notes': c.notes,
      };

  static ContactInfo fromMap(Map<String, dynamic> m) => ContactInfo(
        role: _str(m['role']) ?? ContactRoles.other,
        name: _str(m['name']) ?? '',
        organization: _str(m['organization']),
        phone: _str(m['phone']),
        email: _str(m['email']),
        address: _str(m['address']),
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

  static String? _str(Object? v) => v is String ? v : null;
}
