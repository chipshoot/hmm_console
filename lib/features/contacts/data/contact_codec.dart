import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../domain/entities/contact.dart';
import '../domain/entities/contact_field.dart';

/// `Contact` <-> the JSON map stored as note content.
///
/// Persisted JSON is never lost silently. Three mechanisms keep a save here
/// from destroying data this version cannot read:
///
/// * **Unknown keys** go to `extraFields` (on the contact, the relationship
///   and every list entry) and are written back untouched.
/// * **Known keys with the wrong type** (`"isActivated": "false"`,
///   `"number": 5551234`, a non-Map `relationship`, a non-List `phones`) decode
///   to the field's default for display, and the stored value is kept in that
///   entity's `rawKnownValues`. [toMap] writes the raw value back verbatim
///   while the typed field still equals what the raw value decoded to - i.e.
///   until the user actually changes that field. An explicit JSON `null` is
///   treated as absent, not as malformed.
/// * **Unreadable list entries** (not a Map) are kept per list in
///   `Contact.unreadableEntries` and re-emitted after the readable entries.
///
/// `isActivated` is special-cased: a malformed `"false"`, `0` or `"0"` reads
/// as deactivated, so a malformed value can never resurrect a removed
/// contact. Any other malformed value reads as active. Either way the raw
/// value is what gets saved back.
///
/// Every reader is defensive: a type error here would lose the whole contact
/// rather than one field.
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
    // Written only when not auto / non-empty; see toMap.
    'nameOrder',
    'phoneticFamily',
    'phoneticGiven',
    'phones',
    'emails',
    'addresses',
    'relationship',
    'isSelf',
    'notes',
    'isActivated',
    // Kept verbatim on an untouched save (Contact.storedDisplayName),
    // otherwise derived from ContactName.displayName.
    'displayName',
  };

  static const _phoneKnownKeys = <String>{'label', 'number'};
  static const _emailKnownKeys = <String>{'label', 'address'};
  /// Structured address parts, written only when non-null (in this order,
  /// after `label` and `value`) so a free-form address keeps its two keys.
  static const _addressPartKeys = <String>[
    'country',
    'street1',
    'street2',
    'city',
    'district',
    'region',
    'postalCode',
  ];
  static const _addressKnownKeys = <String>{
    'label',
    'value',
    ..._addressPartKeys,
  };
  static const _relationshipKnownKeys = <String>{'category', 'customLabel'};

  static const _defaultFieldLabel = 'other';

  static Map<String, dynamic> toMap(Contact c) {
    final raw = c.rawKnownValues;
    final out = <String, dynamic>{
      // Preserved keys first so a typed field always wins on conflict.
      ...c.extraFields,
      'schemaVersion': raw.containsKey('schemaVersion')
          ? raw['schemaVersion']
          : math.max(c.storedSchemaVersion, currentSchemaVersion),
      // Stored bytes while untouched (no bulk rewrite); else derived in the
      // contact's name order. A cheatsheet resolves the order at read time.
      'displayName': c.storedDisplayName ?? c.displayName,
      'id': _keep(raw, 'id', c.id, ''),
      // Raw enum string if the type was not explicitly changed.
      'contactType': _keep(
        raw,
        'contactType',
        c.storedContactTypeName,
        ContactType.person.name,
      ),
    };
    _putOptional(out, raw, 'firstName', c.firstName);
    _putOptional(out, raw, 'lastName', c.lastName);
    _putOptional(out, raw, 'organizationName', c.organizationName);
    // Auto is the default and is never written; an unknown or explicit
    // stored value is held raw and written back while still auto.
    final order = _keep(
      raw,
      'nameOrder',
      c.nameOrder == ContactNameOrder.auto ? null : c.nameOrder.name,
      null,
    );
    if (order != null) out['nameOrder'] = order;
    _putOptional(out, raw, 'phoneticFamily', c.phoneticFamily);
    _putOptional(out, raw, 'phoneticGiven', c.phoneticGiven);
    out['phones'] = _list(c, 'phones', [
      for (final p in c.phones)
        {
          ...p.extraFields,
          'label': _keep(
            p.rawKnownValues,
            'label',
            p.label,
            _defaultFieldLabel,
          ),
          'number': _keep(p.rawKnownValues, 'number', p.number, ''),
        },
    ]);
    out['emails'] = _list(c, 'emails', [
      for (final e in c.emails)
        {
          ...e.extraFields,
          'label': _keep(
            e.rawKnownValues,
            'label',
            e.label,
            _defaultFieldLabel,
          ),
          'address': _keep(e.rawKnownValues, 'address', e.address, ''),
        },
    ]);
    out['addresses'] = _list(c, 'addresses', [
      for (final a in c.addresses)
        {
          ...a.extraFields,
          'label': _keep(
            a.rawKnownValues,
            'label',
            a.label,
            _defaultFieldLabel,
          ),
          'value': _keep(a.rawKnownValues, 'value', a.value, ''),
        }..addAll(_addressParts(a)),
    ]);
    out['relationship'] = _relationshipToJson(c);
    out['isSelf'] = _keep(raw, 'isSelf', c.isSelf, false);
    _putOptional(out, raw, 'notes', c.notes);
    out['isActivated'] =
        raw.containsKey('isActivated') &&
            c.isActivated == _activatedFromMalformed(raw['isActivated'])
        ? raw['isActivated']
        : c.isActivated;
    return out;
  }

  /// The structured parts of [a] that are set (or held raw), in
  /// [_addressPartKeys] order. `value` is written as stored, never
  /// re-derived here: an untouched address must save byte-identical.
  static Map<String, dynamic> _addressParts(ContactAddress a) {
    final out = <String, dynamic>{};
    final typed = <String, String?>{
      'country': a.country,
      'street1': a.street1,
      'street2': a.street2,
      'city': a.city,
      'district': a.district,
      'region': a.region,
      'postalCode': a.postalCode,
    };
    for (final k in _addressPartKeys) {
      _putOptional(out, a.rawKnownValues, k, typed[k]);
    }
    return out;
  }

  static Object? _relationshipToJson(Contact c) {
    final rel = c.relationship;
    // A non-Map relationship decoded to the default; keep it until edited.
    if (c.rawKnownValues.containsKey('relationship') &&
        rel.category == RelationshipCategory.other &&
        rel.storedCategoryName == RelationshipCategory.other.name &&
        rel.customLabel == null &&
        rel.extraFields.isEmpty) {
      return c.rawKnownValues['relationship'];
    }
    final out = <String, dynamic>{
      ...rel.extraFields,
      // Raw enum string if the category was not explicitly changed.
      'category': _keep(
        rel.rawKnownValues,
        'category',
        rel.storedCategoryName,
        RelationshipCategory.other.name,
      ),
    };
    _putOptional(out, rel.rawKnownValues, 'customLabel', rel.customLabel);
    return out;
  }

  /// The readable entries, then any unreadable ones; or the raw non-List
  /// value while the list is still empty.
  static Object? _list(
    Contact c,
    String key,
    List<Map<String, dynamic>> typed,
  ) {
    if (typed.isEmpty && c.rawKnownValues.containsKey(key)) {
      return c.rawKnownValues[key];
    }
    return [...typed, ...?c.unreadableEntries[key]];
  }

  /// [typed], unless [raw] holds a malformed stored value for [key] and
  /// [typed] still equals what that value decoded to ([decoded]).
  static Object? _keep(
    Map<String, dynamic> raw,
    String key,
    Object? typed,
    Object? decoded,
  ) => raw.containsKey(key) && typed == decoded ? raw[key] : typed;

  /// Writes an optional string field: omitted when null, unless a malformed
  /// stored value is being kept.
  static void _putOptional(
    Map<String, dynamic> out,
    Map<String, dynamic> raw,
    String key,
    String? typed,
  ) {
    final v = _keep(raw, key, typed, null);
    if (v != null) out[key] = v;
  }

  static Contact fromMap(Map<String, dynamic> m) {
    final r = _Reader(m);
    final relMap = r.map('relationship');
    final rel = _Reader(relMap);
    final unreadable = <String, List<dynamic>>{};

    final storedContactType = r.str('contactType');
    final id = r.str('id') ?? '';
    final rawCategory = rel.str('category');
    final storedOrder = m['nameOrder'];
    final nameOrder = ContactNameOrder.values.firstWhere(
      (o) => o != ContactNameOrder.auto && o.name == storedOrder,
      orElse: () => ContactNameOrder.auto,
    );
    // Unknown, explicit "auto" or wrong-typed: decode as auto, keep the raw
    // value so an untouched save writes it back.
    if (storedOrder != null && nameOrder == ContactNameOrder.auto) {
      r.raw['nameOrder'] = storedOrder;
    }

    final contact = Contact(
      id: id,
      contactType: ContactType.values.firstWhere(
        (t) => t.name == storedContactType,
        orElse: () => ContactType.person,
      ),
      firstName: r.str('firstName'),
      lastName: r.str('lastName'),
      organizationName: r.str('organizationName'),
      nameOrder: nameOrder,
      phoneticFamily: r.str('phoneticFamily'),
      phoneticGiven: r.str('phoneticGiven'),
      phones: _each(r.list('phones'), 'phones', unreadable, (e) {
        final er = _Reader(e);
        return ContactPhone(
          label: er.str('label') ?? _defaultFieldLabel,
          number: er.str('number') ?? '',
          extraFields: _extras(e, _phoneKnownKeys),
          rawKnownValues: er.raw,
        );
      }),
      emails: _each(r.list('emails'), 'emails', unreadable, (e) {
        final er = _Reader(e);
        return ContactEmail(
          label: er.str('label') ?? _defaultFieldLabel,
          address: er.str('address') ?? '',
          extraFields: _extras(e, _emailKnownKeys),
          rawKnownValues: er.raw,
        );
      }),
      addresses: _each(r.list('addresses'), 'addresses', unreadable, (e) {
        final er = _Reader(e);
        return ContactAddress(
          label: er.str('label') ?? _defaultFieldLabel,
          value: er.str('value') ?? '',
          country: er.str('country'),
          street1: er.str('street1'),
          street2: er.str('street2'),
          city: er.str('city'),
          district: er.str('district'),
          region: er.str('region'),
          postalCode: er.str('postalCode'),
          extraFields: _extras(e, _addressKnownKeys),
          rawKnownValues: er.raw,
        );
      }),
      relationship: ContactRelationship(
        category: RelationshipCategory.values.firstWhere(
          (c) => c.name == rawCategory,
          orElse: () => RelationshipCategory.other,
        ),
        customLabel: rel.str('customLabel'),
        extraFields: _extras(relMap, _relationshipKnownKeys),
        rawKnownValues: rel.raw,
        rawCategory: rawCategory,
      ),
      isSelf: r.boolean('isSelf') ?? false,
      notes: r.str('notes'),
      isActivated: r.activated(),
      extraFields: _extras(m, _knownKeys),
      storedSchemaVersion: r.integer('schemaVersion') ?? 1,
      rawKnownValues: r.raw,
      unreadableEntries: unreadable,
      storedDisplayName: m['displayName'],
      rawContactType: storedContactType,
    );

    if (unreadable.isNotEmpty) {
      // Ids and list names only: the entries themselves are personal data.
      debugPrint(
        'ContactCodec: contact ${id.isEmpty ? '(no id)' : id} has '
        'unreadable entries in ${unreadable.keys.join(', ')}; kept verbatim.',
      );
    }
    return contact;
  }

  static Map<String, dynamic> _extras(
    Map<String, dynamic> m,
    Set<String> known,
  ) => {
    for (final entry in m.entries)
      if (!known.contains(entry.key)) entry.key: entry.value,
  };

  /// Decodes each map entry. An entry that is not a map, or that throws, is
  /// kept raw under [name] in [unreadable] - one malformed entry is neither
  /// fatal to the contact nor silently dropped.
  static List<T> _each<T>(
    List<dynamic> raw,
    String name,
    Map<String, List<dynamic>> unreadable,
    T Function(Map<String, dynamic>) build,
  ) {
    final out = <T>[];
    for (final e in raw) {
      try {
        if (e is! Map) throw const FormatException('not a map');
        out.add(build(e.cast<String, dynamic>()));
      } catch (_) {
        (unreadable[name] ??= []).add(e);
      }
    }
    return out;
  }

  /// `"false"`, `0` and `"0"` read as deactivated; anything else as active.
  static bool _activatedFromMalformed(Object? v) =>
      !(v == 'false' || v == 0 || v == '0');
}

/// Typed reads over one JSON object. A key that is present (and not null)
/// with the wrong type yields null / empty and is recorded in [raw].
class _Reader {
  _Reader(this._m);

  final Map<String, dynamic> _m;
  final Map<String, dynamic> raw = {};

  T? _read<T>(String key) {
    final v = _m[key];
    if (v == null) return null;
    if (v is T) return v;
    raw[key] = v;
    return null;
  }

  String? str(String key) => _read<String>(key);

  bool? boolean(String key) => _read<bool>(key);

  int? integer(String key) => _read<num>(key)?.toInt();

  List<dynamic> list(String key) => _read<List>(key) ?? const [];

  Map<String, dynamic> map(String key) =>
      _read<Map>(key)?.cast<String, dynamic>() ?? const {};

  bool activated() {
    final v = _m['isActivated'];
    if (v == null) return true;
    if (v is bool) return v;
    raw['isActivated'] = v;
    return ContactCodec._activatedFromMalformed(v);
  }
}
