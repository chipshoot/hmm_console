import '../domain/entities/contact.dart';
import '../domain/entities/contact_field.dart';

/// `Contact` <-> the JSON map stored as note content.
///
/// Every reader below is defensive: persisted data may hold anything, and a
/// type error here would lose the whole contact rather than one field. Keys
/// this version does not know are carried in `extraFields` and written back
/// untouched, so an older client cannot destroy a newer one's data.
class ContactCodec {
  const ContactCodec._();

  static const currentSchemaVersion = 1;

  /// Keys this version owns. Anything else is preserved verbatim.
  static const _knownKeys = <String>{
    'schemaVersion',
    'id',
    'contactType',
    'firstName',
    'lastName',
    'organizationName',
    'phones',
    'emails',
    'addresses',
    'relationship',
    'isSelf',
    'notes',
    'isActivated',
  };

  static const _phoneKnownKeys = <String>{'label', 'number'};
  static const _emailKnownKeys = <String>{'label', 'address'};
  static const _addressKnownKeys = <String>{'label', 'value'};
  static const _relationshipKnownKeys = <String>{'category', 'customLabel'};

  static Map<String, dynamic> toMap(Contact c) => {
        // Preserved keys first so a typed field always wins on conflict.
        ...c.extraFields,
        'schemaVersion': currentSchemaVersion,
        'id': c.id,
        // Use raw value if enum wasn't explicitly changed; use .name if it was.
        'contactType': c.storedContactTypeName,
        if (c.firstName != null) 'firstName': c.firstName,
        if (c.lastName != null) 'lastName': c.lastName,
        if (c.organizationName != null) 'organizationName': c.organizationName,
        'phones': c.phones
            .map((p) => {
                  ...p.extraFields,
                  'label': p.label,
                  'number': p.number,
                })
            .toList(),
        'emails': c.emails
            .map((e) => {
                  ...e.extraFields,
                  'label': e.label,
                  'address': e.address,
                })
            .toList(),
        'addresses': c.addresses
            .map((a) => {
                  ...a.extraFields,
                  'label': a.label,
                  'value': a.value,
                })
            .toList(),
        'relationship': {
          ...c.relationship.extraFields,
          // Use raw value if enum wasn't explicitly changed; use .name if it was.
          'category': c.relationship.storedCategoryName,
          if (c.relationship.customLabel != null)
            'customLabel': c.relationship.customLabel,
        },
        'isSelf': c.isSelf,
        if (c.notes != null) 'notes': c.notes,
        'isActivated': c.isActivated,
      };

  static Contact fromMap(Map<String, dynamic> m) {
    final rel = m['relationship'];
    final relMap = rel is Map ? rel.cast<String, dynamic>() : const {};
    final storedContactType = _str(m['contactType']) ?? 'person';

    return Contact(
      id: _str(m['id']) ?? '',
      contactType: ContactType.values.firstWhere(
        (t) => t.name == storedContactType,
        orElse: () => ContactType.person,
      ),
      firstName: _str(m['firstName']),
      lastName: _str(m['lastName']),
      organizationName: _str(m['organizationName']),
      phones: _each(m['phones'], (e) => ContactPhone(
            label: _str(e['label']) ?? 'other',
            number: _str(e['number']) ?? '',
            extraFields: {
              for (final entry in e.entries)
                if (!_phoneKnownKeys.contains(entry.key))
                  entry.key: entry.value,
            },
          )),
      emails: _each(m['emails'], (e) => ContactEmail(
            label: _str(e['label']) ?? 'other',
            address: _str(e['address']) ?? '',
            extraFields: {
              for (final entry in e.entries)
                if (!_emailKnownKeys.contains(entry.key))
                  entry.key: entry.value,
            },
          )),
      addresses: _each(m['addresses'], (e) => ContactAddress(
            label: _str(e['label']) ?? 'other',
            value: _str(e['value']) ?? '',
            extraFields: {
              for (final entry in e.entries)
                if (!_addressKnownKeys.contains(entry.key))
                  entry.key: entry.value,
            },
          )),
      relationship: ContactRelationship(
        category: RelationshipCategory.values.firstWhere(
          (c) => c.name == _str(relMap['category']),
          orElse: () => RelationshipCategory.other,
        ),
        customLabel: _str(relMap['customLabel']),
        extraFields: {
          for (final entry in relMap.entries)
            if (!_relationshipKnownKeys.contains(entry.key))
              entry.key: entry.value,
        },
        rawCategory: _str(relMap['category']),
      ),
      isSelf: _bool(m['isSelf']) ?? false,
      notes: _str(m['notes']),
      isActivated: _bool(m['isActivated']) ?? true,
      extraFields: {
        for (final entry in m.entries)
          if (!_knownKeys.contains(entry.key)) entry.key: entry.value,
      },
      rawContactType: storedContactType,
    );
  }

  /// Decodes each map entry, skipping any that is not a map or that throws.
  /// One malformed entry costs that entry, never the contact.
  static List<T> _each<T>(Object? raw, T Function(Map<String, dynamic>) build) {
    if (raw is! List) return const [];
    final out = <T>[];
    for (final e in raw) {
      if (e is! Map) continue;
      try {
        out.add(build(e.cast<String, dynamic>()));
      } catch (_) {
        continue;
      }
    }
    return out;
  }

  static String? _str(Object? v) => v is String ? v : null;

  static bool? _bool(Object? v) => v is bool ? v : null;
}
