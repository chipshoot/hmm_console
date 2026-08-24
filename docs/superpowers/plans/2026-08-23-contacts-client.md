# Contacts (Client) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Contacts address book of people and organizations in `hmm_console`, stored as note-content so it works in `local` and `cloudStorage` today, with `cloudApi` deferred to the backend plan.

**Architecture:** Composition, exactly like `cheatsheet` and `gas_log`: a typed `Contact` entity serialized into an `HmmNote`'s content under a fixed catalog, one note per contact, keyed by subject `Contact:{id}`. No schema change, no Drift migration. The client feature module owns entity, codec, states, and screens; `LocalContactRepository` owns storage and lives beside its peers in `lib/core/data/local/`.

**Tech Stack:** Flutter, Riverpod (`AsyncNotifier`), Drift (via the existing note repositories), `flutter_platform_widgets`, gen-l10n (ARB, en + zh).

**Spec:** `docs/superpowers/specs/2026-07-25-contacts-design.md`

## Global Constraints

- **Catalog name is `Hmm.ContactMan.Contact`, NOT the spec's `Hmm.Contact`.** Every existing catalog is three segments (`Hmm.AutomobileMan.GasLog`, `Hmm.CheatsheetMan.Cheatsheet`) because `CatalogPalette.domainKeyFor` takes the middle segment as the domain key for grouping and colour. A two-segment name has no domain key and would group wrongly. This is a deliberate, recorded deviation from the spec.
- **Note subject is identity, never a label:** `Contact:{id}`. Names are mutable and non-unique and live only inside the JSON.
- **`Contact.id` IS the owning note's `uuid`.** Generate it once and pass it as `HmmNoteCreate.uuid`, so the contact id, the note uuid and the subject `Contact:{id}` are all the same value. The spec calls the note uuid the cross-device stable identity, and a cheatsheet row binds a source by `noteUuid` - if the contact id were a separate generated value, a cheatsheet could not resolve a contact and the follow-up `agentContactId` on insurance would be ambiguous about which id it held. One value, no mapping table.
- **`RelationshipCategory.name` is PERSISTED** in the note JSON. It must never be localized. All display copy goes in `contact_labels.dart`. See `lib/core/i18n/enum_labels.dart` for why this split is load-bearing — the same mistake once wrote `"公里"` into saved settings.
- **Zero hardcoded user-facing strings** under `lib/features/`. Every string a person reads gets an ARB key in BOTH `lib/l10n/app_en.arb` and `lib/l10n/app_zh.arb`. Both files currently hold 488 keys and must stay at parity.
- **Unknown fields in stored JSON are preserved verbatim.** A newer client's fields must survive a save by an older one. Non-negotiable: an audit of the cheatsheet feature found exactly this class of silent data loss.
- **At most one contact may have `isSelf = true`**, enforced on both create and update.
- **Delete is soft** (`isActivated = false`), so a cheatsheet row referencing a contact degrades to "source removed" rather than dangling.
- `cloudApi` mode is OUT OF SCOPE. `contactRepositoryModeProvider` throws `UnimplementedError` for it, matching how cheatsheets shipped before their backend existed.
- Run `flutter analyze` (expect no new issues) and `flutter test` before every commit.

---

### Task 1: Domain entities

**Files:**
- Create: `lib/features/contacts/domain/entities/contact.dart`
- Create: `lib/features/contacts/domain/entities/contact_field.dart`
- Test: `test/features/contacts/domain/contact_test.dart`

**Interfaces:**
- Produces: `Contact`, `ContactType`, `RelationshipCategory`, `ContactRelationship`, `ContactPhone`, `ContactEmail`, `ContactAddress`, and `Contact.displayName`.

- [ ] **Step 1: Write the failing test**

Write `test/features/contacts/domain/contact_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact_field.dart';

void main() {
  Contact person() => const Contact(
        id: 'c-1',
        contactType: ContactType.person,
        firstName: 'Ada',
        lastName: 'Lovelace',
      );

  group('displayName', () {
    test('a person reads First Last', () {
      expect(person().displayName, 'Ada Lovelace');
    });

    test('a person with only a first name does not trail a space', () {
      expect(
        const Contact(id: 'c', contactType: ContactType.person, firstName: 'Ada')
            .displayName,
        'Ada',
      );
    });

    test('an organization reads its organization name', () {
      expect(
        const Contact(
          id: 'c',
          contactType: ContactType.organization,
          organizationName: 'Intact Insurance',
        ).displayName,
        'Intact Insurance',
      );
    });

    test('a nameless contact yields empty, never null', () {
      expect(const Contact(id: 'c', contactType: ContactType.person).displayName, '');
    });
  });

  test('value equality covers the repeatable field lists', () {
    const a = ContactPhone(label: 'mobile', number: '555');
    const b = ContactPhone(label: 'mobile', number: '555');
    expect(a, b);
    expect(
      person().copyWith(phones: const [a]),
      person().copyWith(phones: const [b]),
    );
  });

  test('copyWith replaces only what it is given', () {
    final edited = person().copyWith(firstName: 'Grace');
    expect(edited.firstName, 'Grace');
    expect(edited.lastName, 'Lovelace');
    expect(edited.id, 'c-1');
  });

  test('relationship defaults to other with no custom label', () {
    expect(person().relationship.category, RelationshipCategory.other);
    expect(person().relationship.customLabel, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/contacts/domain/contact_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../contact.dart'`

- [ ] **Step 3: Write the value objects**

Write `lib/features/contacts/domain/entities/contact_field.dart`:

```dart
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
```

- [ ] **Step 4: Write the Contact entity**

Write `lib/features/contacts/domain/entities/contact.dart`:

```dart
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
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/contacts/domain/contact_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 6: Commit**

```bash
cd ~/Projects/hmm_console
git add lib/features/contacts/domain test/features/contacts/domain
git commit -m "feat(contacts): add Contact domain entities"
```

---

### Task 2: Codec

**Files:**
- Create: `lib/features/contacts/data/contact_codec.dart`
- Test: `test/features/contacts/data/contact_codec_test.dart`

**Interfaces:**
- Consumes: `Contact` and friends (Task 1).
- Produces: `ContactCodec.toMap(Contact) -> Map<String, dynamic>`, `ContactCodec.fromMap(Map<String, dynamic>) -> Contact`, `ContactCodec.currentSchemaVersion` (int, 1).

- [ ] **Step 1: Write the failing test**

Write `test/features/contacts/data/contact_codec_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/contacts/data/contact_codec.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact_field.dart';

void main() {
  const full = Contact(
    id: 'c-1',
    contactType: ContactType.person,
    firstName: 'Ada',
    lastName: 'Lovelace',
    phones: [ContactPhone(label: 'mobile', number: '555-0100')],
    emails: [ContactEmail(label: 'work', address: 'ada@example.com')],
    addresses: [ContactAddress(label: 'home', value: '1 Analytical Way')],
    relationship: ContactRelationship(category: RelationshipCategory.insurer),
    notes: 'agent for policy 123',
  );

  test('round-trips a fully populated contact', () {
    expect(ContactCodec.fromMap(ContactCodec.toMap(full)), full);
  });

  test('round-trips an organization', () {
    const org = Contact(
      id: 'c-2',
      contactType: ContactType.organization,
      organizationName: 'Intact',
    );
    expect(ContactCodec.fromMap(ContactCodec.toMap(org)), org);
  });

  test('stores the relationship by enum name, not by a translated label', () {
    // Localizing this would write display copy into saved data.
    expect(ContactCodec.toMap(full)['relationship']['category'], 'insurer');
  });

  test('an unknown relationship category falls back rather than throwing', () {
    final decoded = ContactCodec.fromMap({
      'id': 'c',
      'contactType': 'person',
      'relationship': {'category': 'astrologer'},
    });
    expect(decoded.relationship.category, RelationshipCategory.other);
  });

  test('an unknown contactType falls back to person', () {
    final decoded = ContactCodec.fromMap({'id': 'c', 'contactType': 'alien'});
    expect(decoded.contactType, ContactType.person);
  });

  group('losslessness', () {
    test('unknown top-level fields survive a save', () {
      final decoded = ContactCodec.fromMap({
        'id': 'c-1',
        'contactType': 'person',
        'firstName': 'Ada',
        'favouriteColour': 'green',
        'futureBlock': {'a': 1},
      });

      expect(decoded.extraFields['favouriteColour'], 'green');

      final resaved = ContactCodec.toMap(decoded.copyWith(firstName: 'Grace'));
      expect(resaved['favouriteColour'], 'green');
      expect(resaved['futureBlock'], {'a': 1});
      expect(resaved['firstName'], 'Grace');
    });

    test('a known key never leaks into extraFields', () {
      final decoded = ContactCodec.fromMap({
        'id': 'c',
        'contactType': 'person',
        'firstName': 'Ada',
      });
      expect(decoded.extraFields.containsKey('firstName'), isFalse);
      expect(decoded.extraFields.containsKey('id'), isFalse);
    });

    test('a malformed phones list does not take the contact down', () {
      final decoded = ContactCodec.fromMap({
        'id': 'c',
        'contactType': 'person',
        'phones': 'not-a-list',
      });
      expect(decoded.id, 'c');
      expect(decoded.phones, isEmpty);
    });

    test('a malformed entry inside phones is skipped, not fatal', () {
      final decoded = ContactCodec.fromMap({
        'id': 'c',
        'contactType': 'person',
        'phones': [
          {'label': 'mobile', 'number': '555'},
          'garbage',
        ],
      });
      expect(decoded.phones, hasLength(1));
      expect(decoded.phones.single.number, '555');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/contacts/data/contact_codec_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../contact_codec.dart'`

- [ ] **Step 3: Write the codec**

Write `lib/features/contacts/data/contact_codec.dart`:

```dart
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

  static Map<String, dynamic> toMap(Contact c) => {
        // Preserved keys first so a typed field always wins on conflict.
        ...c.extraFields,
        'schemaVersion': currentSchemaVersion,
        'id': c.id,
        'contactType': c.contactType.name,
        if (c.firstName != null) 'firstName': c.firstName,
        if (c.lastName != null) 'lastName': c.lastName,
        if (c.organizationName != null) 'organizationName': c.organizationName,
        'phones': c.phones
            .map((p) => {'label': p.label, 'number': p.number})
            .toList(),
        'emails': c.emails
            .map((e) => {'label': e.label, 'address': e.address})
            .toList(),
        'addresses': c.addresses
            .map((a) => {'label': a.label, 'value': a.value})
            .toList(),
        'relationship': {
          // The enum NAME is the stored contract. Never a localized label.
          'category': c.relationship.category.name,
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

    return Contact(
      id: _str(m['id']) ?? '',
      contactType: ContactType.values.firstWhere(
        (t) => t.name == m['contactType'],
        orElse: () => ContactType.person,
      ),
      firstName: _str(m['firstName']),
      lastName: _str(m['lastName']),
      organizationName: _str(m['organizationName']),
      phones: _each(m['phones'], (e) => ContactPhone(
            label: _str(e['label']) ?? 'other',
            number: _str(e['number']) ?? '',
          )),
      emails: _each(m['emails'], (e) => ContactEmail(
            label: _str(e['label']) ?? 'other',
            address: _str(e['address']) ?? '',
          )),
      addresses: _each(m['addresses'], (e) => ContactAddress(
            label: _str(e['label']) ?? 'other',
            value: _str(e['value']) ?? '',
          )),
      relationship: ContactRelationship(
        category: RelationshipCategory.values.firstWhere(
          (c) => c.name == relMap['category'],
          orElse: () => RelationshipCategory.other,
        ),
        customLabel: _str(relMap['customLabel']),
      ),
      isSelf: _bool(m['isSelf']) ?? false,
      notes: _str(m['notes']),
      isActivated: _bool(m['isActivated']) ?? true,
      extraFields: {
        for (final entry in m.entries)
          if (!_knownKeys.contains(entry.key)) entry.key: entry.value,
      },
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/contacts/data/contact_codec_test.dart`
Expected: PASS (9 tests)

- [ ] **Step 5: Mutation-check the losslessness guarantee**

The preservation tests are the kind that pass without protecting anything, so prove they can fail. Temporarily change `toMap`'s first line from `...c.extraFields,` to nothing, then run the suite.

Run: `flutter test test/features/contacts/data/contact_codec_test.dart`
Expected: FAIL on `unknown top-level fields survive a save`. **Restore the line** and confirm the suite is green again before committing.

- [ ] **Step 6: Commit**

```bash
cd ~/Projects/hmm_console
git add lib/features/contacts/data test/features/contacts/data
git commit -m "feat(contacts): add ContactCodec with unknown-field preservation"
```

---

### Task 3: Local repository

**Files:**
- Create: `lib/features/contacts/data/i_contact_repository.dart`
- Create: `lib/core/data/local/local_contact_repository.dart`
- Modify: `lib/core/data/repository_providers.dart`
- Test: `test/features/contacts/data/local_contact_repository_test.dart`

**Interfaces:**
- Consumes: `ContactCodec` (Task 2); `IHmmNoteRepository`, `INoteCatalogRepository` from `lib/core/data/local/`; `HmmNoteCreate` / `HmmNoteUpdate` from `lib/core/data/hmm_note_input.dart`; `generateUuid()` from `lib/core/util/uuid.dart`.
- Produces: `IContactRepository` with `Future<List<Contact>> getContacts({bool includeDeactivated = false})`, `Future<Contact?> getContact(String id)`, `Future<Contact> saveContact(Contact contact)`, `Future<void> deactivateContact(String id)`; `contactCatalogName`, `contactSubjectFor(String)`; `localContactRepositoryProvider`; `contactRepositoryModeProvider`.

- [ ] **Step 1: Write the interface**

Write `lib/features/contacts/data/i_contact_repository.dart`:

```dart
import '../domain/entities/contact.dart';

/// CRUD over contacts, keyed by the contact's own stable [Contact.id] rather
/// than any storage-local identity.
abstract interface class IContactRepository {
  /// Active contacts only unless [includeDeactivated]; a deactivated contact
  /// still resolves by id so references to it degrade rather than dangle.
  Future<List<Contact>> getContacts({bool includeDeactivated = false});

  Future<Contact?> getContact(String id);

  /// Upsert by [Contact.id]. A blank id is minted here.
  ///
  /// Setting `isSelf` clears it from every other contact: at most one may be
  /// self, and enforcing it at the collection owner is the only place that can
  /// see the whole collection.
  Future<Contact> saveContact(Contact contact);

  /// Soft delete.
  Future<void> deactivateContact(String id);
}
```

- [ ] **Step 2: Write the failing test**

Write `test/features/contacts/data/local_contact_repository_test.dart`. Model the fakes on `test/features/cheatsheet/data/` — read `local_cheatsheet_repository.dart` first and mirror how its test doubles stand in for `IHmmNoteRepository` and `INoteCatalogRepository`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/local_contact_repository.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';

import 'contact_repository_fakes.dart';

void main() {
  late LocalContactRepository repo;
  late FakeNoteRepository notes;

  setUp(() {
    notes = FakeNoteRepository();
    repo = LocalContactRepository(notes, FakeCatalogRepository());
  });

  Contact person(String name, {bool isSelf = false}) => Contact(
        id: '',
        contactType: ContactType.person,
        firstName: name,
        isSelf: isSelf,
      );

  test('saving mints an id when the caller supplies none', () async {
    final saved = await repo.saveContact(person('Ada'));
    expect(saved.id, isNotEmpty);
  });

  test('saving stores under the subject identity, not the name', () async {
    final saved = await repo.saveContact(person('Ada'));
    expect(notes.stored.single.subject, contactSubjectFor(saved.id));
  });

  test('renaming updates in place rather than creating a second note', () async {
    final saved = await repo.saveContact(person('Ada'));
    await repo.saveContact(saved.copyWith(firstName: 'Grace'));

    expect(notes.stored, hasLength(1));
    expect((await repo.getContact(saved.id))!.firstName, 'Grace');
  });

  test('getContacts hides deactivated contacts by default', () async {
    final saved = await repo.saveContact(person('Ada'));
    await repo.deactivateContact(saved.id);

    expect(await repo.getContacts(), isEmpty);
    expect(await repo.getContacts(includeDeactivated: true), hasLength(1));
  });

  test('a deactivated contact still resolves by id, so references degrade', () async {
    final saved = await repo.saveContact(person('Ada'));
    await repo.deactivateContact(saved.id);

    final found = await repo.getContact(saved.id);
    expect(found, isNotNull);
    expect(found!.isActivated, isFalse);
  });

  test('setting isSelf clears it from every other contact', () async {
    final ada = await repo.saveContact(person('Ada', isSelf: true));
    final grace = await repo.saveContact(person('Grace', isSelf: true));

    expect((await repo.getContact(grace.id))!.isSelf, isTrue);
    expect((await repo.getContact(ada.id))!.isSelf, isFalse);
  });

  test('saving a non-self contact leaves the existing self alone', () async {
    final ada = await repo.saveContact(person('Ada', isSelf: true));
    await repo.saveContact(person('Grace'));

    expect((await repo.getContact(ada.id))!.isSelf, isTrue);
  });

  test('an unreadable note is omitted from the list, not fatal', () async {
    await repo.saveContact(person('Ada'));
    notes.stored.add(notes.stored.single.copyWith(
      id: 99,
      subject: 'Contact:broken',
      content: 'not json',
    ));

    expect(await repo.getContacts(), hasLength(1));
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/contacts/data/local_contact_repository_test.dart`
Expected: FAIL — `local_contact_repository.dart` does not exist.

Write `test/features/contacts/data/contact_repository_fakes.dart` alongside it, following the shape of the cheatsheet repository's existing fakes. The fakes must store real `HmmNote` values so the subject and content assertions above mean something.

- [ ] **Step 4: Write the repository**

Write `lib/core/data/local/local_contact_repository.dart`:

```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/contacts/data/contact_codec.dart';
import '../../../features/contacts/data/i_contact_repository.dart';
import '../../../features/contacts/domain/entities/contact.dart';
import '../../../features/notes/data/models/hmm_note.dart';
import '../../util/uuid.dart';
import '../hmm_note_input.dart';
import 'local_hmm_note_repository.dart';
import 'local_note_catalog_repository.dart';

/// Three segments so `CatalogPalette.domainKeyFor` reads `ContactMan` as the
/// domain key. The spec said `Hmm.Contact`; a two-segment name has no domain
/// key and would group and colour wrongly alongside every other catalog.
const contactCatalogName = 'Hmm.ContactMan.Contact';

/// The subject is identity, never a label: names are mutable and non-unique,
/// so they live only inside the contact JSON.
String contactSubjectFor(String contactId) => 'Contact:$contactId';

/// Stores each contact as an `HmmNote`'s content under a fixed catalog,
/// mirroring `LocalCheatsheetRepository`. Contact notes have no parent.
class LocalContactRepository implements IContactRepository {
  LocalContactRepository(this._notes, this._catalogs);

  final IHmmNoteRepository _notes;
  final INoteCatalogRepository _catalogs;

  static const _pageSize = 100;

  String _serialize(Contact c) => jsonEncode({
        'note': {
          'content': {'Contact': ContactCodec.toMap(c)},
        },
      });

  Contact? _deserialize(HmmNote? note) {
    final content = note?.content;
    if (content == null) return null;
    try {
      final data = (jsonDecode(content) as Map)['note']?['content']?['Contact'];
      if (data is Map) return ContactCodec.fromMap(data.cast<String, dynamic>());
      debugPrint('LocalContactRepository: note ${note!.id}/${note.uuid} has no '
          'Contact payload; omitted from the address book.');
      return null;
    } catch (e) {
      // The contact vanishes from the list with nothing on screen to explain
      // it, so name the note - otherwise this is undiagnosable without
      // reproducing it locally.
      debugPrint('LocalContactRepository: note ${note!.id}/${note.uuid} has '
          'unreadable contact JSON ($e); omitted from the address book.');
      return null;
    }
  }

  Future<List<Contact>> _all() async {
    final catalogId =
        (await _catalogs.getOrCreateCatalog(contactCatalogName, '{}')).id;
    final out = <Contact>[];
    var page = 1;
    while (true) {
      final notes = await _notes.getNotes(
        catalogId: catalogId,
        page: page,
        pageSize: _pageSize,
      );
      if (notes.isEmpty) break;
      for (final n in notes) {
        final c = _deserialize(n);
        if (c != null) out.add(c);
      }
      if (notes.length < _pageSize) break;
      page++;
    }
    return out;
  }

  @override
  Future<List<Contact>> getContacts({bool includeDeactivated = false}) async {
    final all = await _all();
    final visible =
        includeDeactivated ? all : all.where((c) => c.isActivated).toList();
    visible.sort((a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return visible;
  }

  @override
  Future<Contact?> getContact(String id) async =>
      (await _all()).where((c) => c.id == id).firstOrNull;

  @override
  Future<Contact> saveContact(Contact contact) async {
    final id = contact.id.isEmpty ? generateUuid() : contact.id;
    final toSave = contact.copyWith(id: id);

    if (toSave.isSelf) {
      // At most one self. Clearing the others here, at the only layer that can
      // see the whole collection, keeps the rule true no matter which screen
      // set the flag.
      for (final other in await _all()) {
        if (other.id != id && other.isSelf) {
          await _write(other.copyWith(isSelf: false));
        }
      }
    }

    await _write(toSave);
    return toSave;
  }

  Future<void> _write(Contact c) async {
    final catalogId =
        (await _catalogs.getOrCreateCatalog(contactCatalogName, '{}')).id;
    final subject = contactSubjectFor(c.id);
    final existing = await _notes.findBySubject(subject, catalogId: catalogId);

    if (existing == null) {
      await _notes.createNote(HmmNoteCreate(
        subject: subject,
        catalogId: catalogId,
        content: _serialize(c),
        // The note's uuid IS the contact id - see the identity constraint.
        uuid: c.id,
      ));
    } else {
      // Catalog and author are immutable after create; passing them to an
      // update throws. Only subject and content move.
      await _notes.updateNote(existing.id, HmmNoteUpdate(
        subject: subject,
        content: _serialize(c),
      ));
    }
  }

  @override
  Future<void> deactivateContact(String id) async {
    final existing = await getContact(id);
    if (existing == null) return;
    await _write(existing.copyWith(isActivated: false));
  }
}

final localContactRepositoryProvider = Provider<IContactRepository>((ref) {
  return LocalContactRepository(
    ref.watch(hmmNoteRepositoryProvider),
    ref.watch(noteCatalogRepositoryProvider),
  );
});
```

**Before writing this file, open `lib/core/data/local/local_cheatsheet_repository.dart` and match its actual method names** for `IHmmNoteRepository` / `INoteCatalogRepository` (`getNotes`, `findBySubject`, `createNote`, `updateNote`, `getOrCreateCatalog`) and the real names of `hmmNoteRepositoryProvider` / `noteCatalogRepositoryProvider`. If any differ, use the real ones — the shape above is the pattern, not a promise about those signatures.

- [ ] **Step 5: Wire the mode provider**

In `lib/core/data/repository_providers.dart`, add next to `cheatsheetRepositoryModeProvider`:

```dart
final contactRepositoryModeProvider = Provider<IContactRepository>((ref) {
  final mode = ref.watch(dataModeProvider);
  if (_useLocal(mode)) return ref.watch(localContactRepositoryProvider);
  // cloudApi arrives with the backend plan; until then this mode has no
  // contacts rather than silently showing an empty address book.
  throw UnimplementedError('contacts cloudApi repo ships in the backend plan');
});
```

Add the two imports it needs: `../../features/contacts/data/i_contact_repository.dart` and `local/local_contact_repository.dart`.

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/features/contacts/data/local_contact_repository_test.dart`
Expected: PASS (8 tests)

- [ ] **Step 7: Mutation-check the isSelf rule**

Temporarily delete the `if (toSave.isSelf) { ... }` block in `saveContact`.

Run: `flutter test test/features/contacts/data/local_contact_repository_test.dart`
Expected: FAIL on `setting isSelf clears it from every other contact`. **Restore the block** and confirm green.

- [ ] **Step 8: Commit**

```bash
cd ~/Projects/hmm_console
flutter analyze
git add lib/features/contacts lib/core/data test/features/contacts
git commit -m "feat(contacts): add local note-content repository"
```

---

### Task 4: Localized labels and ARB keys

Do this BEFORE any screen, so no UI is ever written with a hardcoded string.

**Files:**
- Create: `lib/features/contacts/presentation/contact_labels.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`
- Test: `test/features/contacts/presentation/contact_labels_test.dart`

**Interfaces:**
- Consumes: `RelationshipCategory`, `ContactType` (Task 1); `AppLocalizations` from `lib/l10n/gen/app_localizations.dart`.
- Produces: `relationshipLabel(RelationshipCategory, AppLocalizations)`, `contactTypeLabel(ContactType, AppLocalizations)`, `fieldLabelText(String, AppLocalizations)`.

- [ ] **Step 1: Add the ARB keys**

Add to `lib/l10n/app_en.arb` (and the matching keys to `app_zh.arb` — both files must stay at equal key count):

```json
"contactsTitle": "Contacts",
"contactsEmpty": "No contacts yet",
"contactsSearchHint": "Search contacts",
"contactAdd": "Add contact",
"contactEdit": "Edit contact",
"contactDelete": "Delete contact",
"contactDeleteConfirm": "Delete this contact? Anything referencing it will show as removed.",
"contactTypePerson": "Person",
"contactTypeOrganization": "Organization",
"contactFirstName": "First name",
"contactLastName": "Last name",
"contactOrganizationName": "Organization name",
"contactPhones": "Phones",
"contactEmails": "Emails",
"contactAddresses": "Addresses",
"contactNotes": "Notes",
"contactIsSelf": "This is me",
"contactIsSelfHint": "Only one contact can be marked as you",
"contactRelationship": "Relationship",
"contactAddPhone": "Add phone",
"contactAddEmail": "Add email",
"contactAddAddress": "Add address",
"contactNameRequired": "A contact needs a name",
"contactGroupFamily": "Family",
"contactGroupProviders": "Providers",
"contactGroupOther": "Other",
"relationshipSelf": "Me",
"relationshipSpouse": "Spouse",
"relationshipParent": "Parent",
"relationshipChild": "Child",
"relationshipFamily": "Family",
"relationshipFriend": "Friend",
"relationshipDoctor": "Doctor",
"relationshipPharmacy": "Pharmacy",
"relationshipInsurer": "Insurer",
"relationshipOther": "Other",
"fieldLabelMobile": "Mobile",
"fieldLabelHome": "Home",
"fieldLabelWork": "Work",
"fieldLabelPersonal": "Personal",
"fieldLabelOther": "Other"
```

Chinese values for `app_zh.arb`:

```json
"contactsTitle": "联系人",
"contactsEmpty": "暂无联系人",
"contactsSearchHint": "搜索联系人",
"contactAdd": "添加联系人",
"contactEdit": "编辑联系人",
"contactDelete": "删除联系人",
"contactDeleteConfirm": "删除此联系人？引用它的内容将显示为已移除。",
"contactTypePerson": "个人",
"contactTypeOrganization": "机构",
"contactFirstName": "名",
"contactLastName": "姓",
"contactOrganizationName": "机构名称",
"contactPhones": "电话",
"contactEmails": "电子邮箱",
"contactAddresses": "地址",
"contactNotes": "备注",
"contactIsSelf": "这是我",
"contactIsSelfHint": "只能有一个联系人标记为本人",
"contactRelationship": "关系",
"contactAddPhone": "添加电话",
"contactAddEmail": "添加邮箱",
"contactAddAddress": "添加地址",
"contactNameRequired": "联系人需要名称",
"contactGroupFamily": "家人",
"contactGroupProviders": "服务提供方",
"contactGroupOther": "其他",
"relationshipSelf": "本人",
"relationshipSpouse": "配偶",
"relationshipParent": "父母",
"relationshipChild": "子女",
"relationshipFamily": "家人",
"relationshipFriend": "朋友",
"relationshipDoctor": "医生",
"relationshipPharmacy": "药房",
"relationshipInsurer": "保险",
"relationshipOther": "其他",
"fieldLabelMobile": "手机",
"fieldLabelHome": "住宅",
"fieldLabelWork": "工作",
"fieldLabelPersonal": "个人",
"fieldLabelOther": "其他"
```

> These Chinese strings have NOT been reviewed by a native speaker, which is a known standing risk across the app. Flag them for review rather than assuming they are right.

- [ ] **Step 2: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: no errors; `AppLocalizations` gains the new getters.

- [ ] **Step 3: Write the failing test**

Write `test/features/contacts/presentation/contact_labels_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';
import 'package:hmm_console/features/contacts/presentation/contact_labels.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

void main() {
  late AppLocalizations en;
  late AppLocalizations zh;

  setUp(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
    zh = await AppLocalizations.delegate.load(const Locale('zh'));
  });

  test('every relationship category has a label in both locales', () {
    for (final c in RelationshipCategory.values) {
      expect(relationshipLabel(c, en), isNotEmpty, reason: '$c missing en');
      expect(relationshipLabel(c, zh), isNotEmpty, reason: '$c missing zh');
    }
  });

  test('labels are display copy, never the stored enum name', () {
    // If these ever coincide, someone has started rendering stored data.
    expect(relationshipLabel(RelationshipCategory.insurer, zh),
        isNot(RelationshipCategory.insurer.name));
    expect(relationshipLabel(RelationshipCategory.doctor, zh),
        isNot(RelationshipCategory.doctor.name));
  });

  test('an unknown stored field label falls back to the raw value', () {
    // A label this version does not know must still be readable, not blank.
    expect(fieldLabelText('carrier-pigeon', en), 'carrier-pigeon');
  });
}
```

Add `import 'dart:ui';` if `Locale` is not already in scope.

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/features/contacts/presentation/contact_labels_test.dart`
Expected: FAIL — `contact_labels.dart` does not exist.

- [ ] **Step 5: Write the labels**

Write `lib/features/contacts/presentation/contact_labels.dart`:

```dart
import '../../../l10n/gen/app_localizations.dart';
import '../domain/entities/contact.dart';

/// Display copy for the contact enums.
///
/// The split is deliberate and load-bearing. `RelationshipCategory.name` and
/// the phone/email/address `label` strings are PERSISTED in the contact's note
/// JSON and synced across devices. Localizing them at the source would write
/// display text into stored data, so the same contact would read differently
/// per device language - and a value saved on a Chinese device would no longer
/// match anything on an English one. See `lib/core/i18n/enum_labels.dart`,
/// where this exact mistake was found and fixed.
String relationshipLabel(RelationshipCategory c, AppLocalizations l) =>
    switch (c) {
      RelationshipCategory.self => l.relationshipSelf,
      RelationshipCategory.spouse => l.relationshipSpouse,
      RelationshipCategory.parent => l.relationshipParent,
      RelationshipCategory.child => l.relationshipChild,
      RelationshipCategory.family => l.relationshipFamily,
      RelationshipCategory.friend => l.relationshipFriend,
      RelationshipCategory.doctor => l.relationshipDoctor,
      RelationshipCategory.pharmacy => l.relationshipPharmacy,
      RelationshipCategory.insurer => l.relationshipInsurer,
      RelationshipCategory.other => l.relationshipOther,
    };

String contactTypeLabel(ContactType t, AppLocalizations l) => switch (t) {
      ContactType.person => l.contactTypePerson,
      ContactType.organization => l.contactTypeOrganization,
    };

/// Display copy for a stored field label (`mobile`, `work`, ...).
///
/// Falls back to the raw stored value so a label written by a newer client, or
/// typed by the user, still reads as itself rather than disappearing.
String fieldLabelText(String stored, AppLocalizations l) => switch (stored) {
      'mobile' => l.fieldLabelMobile,
      'home' => l.fieldLabelHome,
      'work' => l.fieldLabelWork,
      'personal' => l.fieldLabelPersonal,
      'other' => l.fieldLabelOther,
      _ => stored,
    };
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/features/contacts/presentation/contact_labels_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 7: Commit**

```bash
cd ~/Projects/hmm_console
git add lib/features/contacts/presentation lib/l10n test/features/contacts/presentation
git commit -m "feat(contacts): add localized labels, keeping stored enum names untranslated"
```

---

### Task 5: Contacts list state and screen

**Files:**
- Create: `lib/features/contacts/states/contacts_state.dart`
- Create: `lib/features/contacts/presentation/screens/contacts_list_screen.dart`
- Create: `lib/features/contacts/presentation/widgets/contact_tile.dart`
- Test: `test/features/contacts/states/contacts_state_test.dart`
- Test: `test/features/contacts/presentation/contacts_list_screen_test.dart`

**Interfaces:**
- Consumes: `contactRepositoryModeProvider` (Task 3); `relationshipLabel` (Task 4).
- Produces: `ContactsState extends AsyncNotifier<List<Contact>>` with `save(Contact)` and `deactivate(String)`; `contactsStateProvider`; `ContactsListScreen`; `ContactTile`.

- [ ] **Step 1: Write the state**

Write `lib/features/contacts/states/contacts_state.dart`, mirroring `lib/features/cheatsheet/states/cheatsheets_state.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/repository_providers.dart';
import '../domain/entities/contact.dart';

/// The address book.
///
/// Mutations write through the repository and then invalidate, so the list is
/// always re-read from storage rather than patched in memory - the repository
/// owns the isSelf rule, and mirroring it here is how the two would drift.
class ContactsState extends AsyncNotifier<List<Contact>> {
  @override
  Future<List<Contact>> build() =>
      ref.read(contactRepositoryModeProvider).getContacts();

  Future<void> save(Contact contact) async {
    await ref.read(contactRepositoryModeProvider).saveContact(contact);
    ref.invalidateSelf();
  }

  Future<void> deactivate(String id) async {
    await ref.read(contactRepositoryModeProvider).deactivateContact(id);
    ref.invalidateSelf();
  }
}

final contactsStateProvider =
    AsyncNotifierProvider<ContactsState, List<Contact>>(ContactsState.new);
```

- [ ] **Step 2: Write the failing state test**

Write `test/features/contacts/states/contacts_state_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';
import 'package:hmm_console/features/contacts/states/contacts_state.dart';

import '../data/contact_repository_fakes.dart';

void main() {
  test('build reads the address book from the repository', () async {
    final repo = InMemoryContactRepository()
      ..seed(const Contact(id: 'c-1', contactType: ContactType.person, firstName: 'Ada'));
    final container = ProviderContainer(overrides: [
      contactRepositoryModeProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    final contacts = await container.read(contactsStateProvider.future);
    expect(contacts, hasLength(1));
  });

  test('save writes through and re-reads rather than patching in memory', () async {
    final repo = InMemoryContactRepository();
    final container = ProviderContainer(overrides: [
      contactRepositoryModeProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    await container.read(contactsStateProvider.future);
    await container.read(contactsStateProvider.notifier).save(
          const Contact(id: 'c-1', contactType: ContactType.person, firstName: 'Ada'),
        );

    expect(repo.saveCalls, 1);
    expect(await container.read(contactsStateProvider.future), hasLength(1));
  });

  test('deactivate removes the contact from the list', () async {
    final repo = InMemoryContactRepository()
      ..seed(const Contact(id: 'c-1', contactType: ContactType.person, firstName: 'Ada'));
    final container = ProviderContainer(overrides: [
      contactRepositoryModeProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    await container.read(contactsStateProvider.future);
    await container.read(contactsStateProvider.notifier).deactivate('c-1');

    expect(await container.read(contactsStateProvider.future), isEmpty);
  });
}
```

Add `InMemoryContactRepository` (implementing `IContactRepository`, honouring `isActivated` and counting `saveCalls`) to `test/features/contacts/data/contact_repository_fakes.dart`.

- [ ] **Step 3: Run test to verify it fails, then passes**

Run: `flutter test test/features/contacts/states/contacts_state_test.dart`
Expected: FAIL first (missing fake), then PASS (3 tests) once the fake exists.

- [ ] **Step 4: Write the tile and the screen**

Write `lib/features/contacts/presentation/widgets/contact_tile.dart` — a `ListTile` showing `contact.displayName`, the relationship label under it via `relationshipLabel`, and an `onTap` callback. Use `flutter_platform_widgets` for anything with a platform-specific look, per the project rules.

Write `lib/features/contacts/presentation/screens/contacts_list_screen.dart`:

- a `ConsumerStatefulWidget` watching `contactsStateProvider`
- a search field (`l.contactsSearchHint`) filtering on `displayName`, case-insensitively
- contacts grouped into Family / Providers / Other by `RelationshipCategory`, with headers from `l.contactGroupFamily` / `l.contactGroupProviders` / `l.contactGroupOther`
- an empty state reading `l.contactsEmpty`
- an add action (`l.contactAdd`) routing to the edit screen
- `AsyncValue` handled with a loading indicator and an error state — never a bare `.value!`

Group mapping: `self`, `spouse`, `parent`, `child`, `family` -> Family; `doctor`, `pharmacy`, `insurer` -> Providers; `friend`, `other` -> Other.

- [ ] **Step 5: Write the failing widget test**

Write `test/features/contacts/presentation/contacts_list_screen_test.dart`. Mount `ContactsListScreen` inside a `ProviderScope` overriding `contactRepositoryModeProvider` with `InMemoryContactRepository`, and — critically — supply `AppLocalizations.localizationsDelegates` and `supportedLocales` on the `MaterialApp`, or the widget throws while building rather than failing an assertion. Assert:

- an empty repository shows the `contactsEmpty` copy
- two seeded contacts render both display names
- typing in the search field filters to one
- a contact with `RelationshipCategory.insurer` appears under the Providers header

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/contacts/`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
cd ~/Projects/hmm_console
flutter analyze
git add lib/features/contacts test/features/contacts
git commit -m "feat(contacts): add contacts list state and screen"
```

---

### Task 6: Contact detail screen

**Files:**
- Create: `lib/features/contacts/presentation/screens/contact_detail_screen.dart`
- Test: `test/features/contacts/presentation/contact_detail_screen_test.dart`

**Interfaces:**
- Consumes: `contactsStateProvider` (Task 5); `fieldLabelText`, `relationshipLabel` (Task 4).
- Produces: `ContactDetailScreen({required String contactId})`.

- [ ] **Step 1: Write the failing test**

Write `test/features/contacts/presentation/contact_detail_screen_test.dart` asserting:

- the display name, relationship label, and every phone/email/address render, each with its label rendered through `fieldLabelText` (so `mobile` shows as "Mobile", not `mobile`)
- a phone row is tappable and calls the injected launcher with `tel:` and that number
- an address row is tappable and calls the injected launcher with a maps URI containing the address
- an unknown contact id shows a not-found message instead of throwing
- a deactivated contact still renders (it resolves by id) rather than showing not-found

Inject the launcher as a provider override rather than calling `url_launcher` directly, so the test can assert the URI. Follow whatever the cheatsheet detail screen already does for tap-to-call — read `lib/features/cheatsheet/presentation/screens/cheatsheet_detail_screen.dart` and reuse its approach rather than inventing a second one.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/contacts/presentation/contact_detail_screen_test.dart`
Expected: FAIL — `contact_detail_screen.dart` does not exist.

- [ ] **Step 3: Write the screen**

Sections: name header (with the organization/person distinction), relationship, phones, emails, addresses, notes. Each repeatable row shows `fieldLabelText(label, l)` and the value, with tap-to-call on phones and tap-for-Maps on addresses. An edit action routes to the edit screen. A delete action confirms with `l.contactDeleteConfirm` and calls `deactivate`.

Skip empty sections entirely rather than rendering an empty header.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/contacts/presentation/contact_detail_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd ~/Projects/hmm_console
flutter analyze
git add lib/features/contacts test/features/contacts
git commit -m "feat(contacts): add contact detail screen with tap-to-call and maps"
```

---

### Task 7: Contact edit screen

**Files:**
- Create: `lib/features/contacts/presentation/screens/contact_edit_screen.dart`
- Create: `lib/features/contacts/presentation/widgets/labeled_field_editor.dart`
- Create: `lib/features/contacts/states/contact_edit_state.dart`
- Test: `test/features/contacts/presentation/contact_edit_screen_test.dart`

**Interfaces:**
- Consumes: `contactsStateProvider` (Task 5); `contactTypeLabel`, `relationshipLabel`, `fieldLabelText` (Task 4).
- Produces: `ContactEditScreen({String? contactId})` — null id means create.

- [ ] **Step 1: Write the failing test**

Write `test/features/contacts/presentation/contact_edit_screen_test.dart` asserting:

- creating: filling a first name and saving calls `saveContact` once with that name and a blank id (the repository mints it)
- editing: the form pre-populates from the existing contact, and saving preserves its id
- the person/organization toggle swaps the name fields (first/last vs organization name)
- "Add phone" appends an empty row; removing a row drops it
- saving with no name at all is refused with `l.contactNameRequired` and does not call the repository
- toggling `isSelf` on and saving passes `isSelf: true` through to the repository
- a save is not re-entrant: two rapid taps call the repository once

That last one matters — a double-tapped save on a create screen is exactly how the cheatsheet feature once created two records.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/contacts/presentation/contact_edit_screen_test.dart`
Expected: FAIL — `contact_edit_screen.dart` does not exist.

- [ ] **Step 3: Write the labeled field editor**

`LabeledFieldEditor` — a reusable row of (label dropdown, value text field, remove button) plus an "add" action, used three times for phones, emails and addresses. The label dropdown offers the known labels rendered via `fieldLabelText`, and **stores the literal** (`mobile`), never the displayed text.

- [ ] **Step 4: Write the edit state and screen**

`ContactEditState` holds the in-progress `Contact` and exposes field mutations plus `save()`. Guard `save()` with an in-flight flag so a second tap is ignored while the first is running.

The screen: type toggle, name field(s), the three `LabeledFieldEditor` sections, a relationship picker built from `RelationshipCategory.values` rendered with `relationshipLabel`, an `isSelf` switch with `l.contactIsSelfHint` as its subtitle, and a notes field.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/contacts/presentation/contact_edit_screen_test.dart`
Expected: PASS

- [ ] **Step 6: Mutation-check the re-entrancy guard**

Temporarily remove the in-flight flag from `save()`.

Run: `flutter test test/features/contacts/presentation/contact_edit_screen_test.dart`
Expected: FAIL on the double-tap test. **Restore the guard** and confirm green.

- [ ] **Step 7: Commit**

```bash
cd ~/Projects/hmm_console
flutter analyze
git add lib/features/contacts test/features/contacts
git commit -m "feat(contacts): add contact create/edit screen"
```

---

### Task 8: Navigation and entry point

**Files:**
- Modify: `lib/core/navigation/route_names.dart`
- Create: `lib/core/navigation/contact_routes.dart`
- Modify: the router that assembles the route list (find it with `grep -rn "cheatsheetRoutes" lib/core/navigation/`)
- Modify: the dashboard, to add a Contacts entry point
- Test: `test/features/contacts/presentation/contact_routes_test.dart`

**Interfaces:**
- Consumes: the three screens (Tasks 5-7).
- Produces: route names `contacts`, `contactCreate`, `contactDetail`, `contactEdit`.

- [ ] **Step 1: Write the failing test**

Write `test/features/contacts/presentation/contact_routes_test.dart` asserting that navigating to each of the four routes lands on the right screen, and that `contactDetail` and `contactEdit` are keyed by contact id.

**Key the edit route by contact id.** go_router's declarative page key uses the path template, so `/contacts/A/edit` and `/contacts/B/edit` collide under `context.go` unless the page carries a key of its own. That exact bug was found and fixed in the cheatsheet feature; do not reintroduce it.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/contacts/presentation/contact_routes_test.dart`
Expected: FAIL — the routes do not exist.

- [ ] **Step 3: Add the routes**

Add the four values to the `RouteNames` enum, then write `contact_routes.dart` modelled on `cheatsheet_routes.dart`, and register it wherever `cheatsheetRoutes` is registered.

- [ ] **Step 4: Add the dashboard entry point**

Add a Contacts tile beside the existing Cheatsheets tile, labelled `l.contactsTitle`, navigating to the `contacts` route.

- [ ] **Step 5: Write the failing dashboard test**

Assert the tile exists and that tapping it actually arrives at the contacts list — navigate for real and assert arrival, rather than asserting the tile's existence alone. A tile that renders but routes nowhere passes the weaker test.

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/contacts/`
Expected: PASS

- [ ] **Step 7: Mutation-check the dashboard route**

Temporarily change the route string in the dashboard tile to a nonexistent one.

Run the dashboard test. Expected: FAIL. **Restore it** and confirm green.

- [ ] **Step 8: Commit**

```bash
cd ~/Projects/hmm_console
flutter analyze
flutter test
git add lib/core/navigation lib/features test/features
git commit -m "feat(contacts): add routes and dashboard entry point"
```

---

### Task 9: Full verification

- [ ] **Step 1: Analyzer**

Run: `flutter analyze`
Expected: no NEW issues. Two pre-existing ones live in `onboarding_screen.dart` and `main.dart`; anything else is yours.

- [ ] **Step 2: Full suite**

Run: `flutter test`
Expected: every test passes. The suite stood at 1360 before this work.

- [ ] **Step 3: ARB parity**

Run:

```bash
cd ~/Projects/hmm_console
python3 -c "
import json
en = json.load(open('lib/l10n/app_en.arb'))
zh = json.load(open('lib/l10n/app_zh.arb'))
ek = {k for k in en if not k.startswith('@')}
zk = {k for k in zh if not k.startswith('@')}
print('en', len(ek), 'zh', len(zk))
print('missing from zh:', sorted(ek - zk))
print('missing from en:', sorted(zk - ek))
"
```

Expected: equal counts, both difference lists empty.

- [ ] **Step 4: No hardcoded user-facing strings**

Run: `grep -rnE "Text\('[A-Z]" lib/features/contacts/ || echo clean`
Expected: `clean`. Any hit is a string that should be an ARB key.

- [ ] **Step 5: Manual check in both languages**

Build to a device, switch language in Settings, and walk the three screens. The Chinese strings in Task 4 were written without native-speaker review; this is the cheapest chance to catch a wrong term before contacts start referencing each other.

- [ ] **Step 6: Commit**

```bash
cd ~/Projects/hmm_console
git add -A lib test docs
git commit -m "chore(contacts): verify analyzer, suite, and en/zh parity"
```

---

## Out of scope

- **`cloudApi` mode** — the `/v1/contacts` backend is a separate plan. `contactRepositoryModeProvider` throws for that mode until it lands.
- **Insurance integration** (`agentContactId` on `AutoInsurancePolicy`, plus policy attachments) — the follow-up this work unblocks. Small once Contacts exists.
- **Contact photos, device address-book import, dedup/merge, organization opening hours** — all named non-goals in the spec.
- **Family sharing** and **`Author.Contact` re-homing** — future phases in the spec.
