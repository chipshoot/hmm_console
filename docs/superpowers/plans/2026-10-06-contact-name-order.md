# Contact Name Order, Pinyin Sort and Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show each contact's name in the order that name is written (张伟, John Smith), sort and search contacts by family or given name, and let Chinese names sort and search through pinyin alongside Latin names.

**Architecture:** One pure module (`contact_name.dart`) owns every ordering and display rule; `Contact.displayName` delegates to it, so all existing call sites (tile, detail, Me, codec, cheatsheet) update without change. Pinyin sits behind a `PinyinTranscriber` interface, is computed only at read time in a list provider (`contact_list_entries.dart`) that precomputes sort keys and search terms with `contact_sort.dart`, and is never persisted. The codec adds three optional known keys and keeps an untouched contact's stored bytes (including its stored `displayName`); cheatsheet cards get the read-time name through a new `DerivedFieldRegistry`.

**Tech Stack:** Flutter 3.41.9, Dart `^3.11.0`, Riverpod 3 (`flutter_riverpod ^3.0.3`), gen-l10n (`lib/l10n/app_en.arb` template + `app_zh.arb`, generated into the committed `lib/l10n/gen/`), shared_preferences, plus one new pinyin dependency chosen by the Task 1 spike (`pinyin_pro_flutter ^1.0.3`, or fallback `pinyin ^3.3.0`).

**Spec:** docs/superpowers/specs/2026-10-06-contact-name-order-design.md

## Global Constraints

- A contact opened and saved without edits is written back byte-identical: no new keys, and the stored `displayName` is kept.
- The new keys `nameOrder`, `phoneticFamily` and `phoneticGiven` are written only when non-default (`nameOrder` ≠ `auto`, phonetics non-empty), apart from preserved raw values.
- Pinyin is computed at read time and never persisted, in the contact JSON or anywhere else.
- Logs carry ids and error types only (`${e.runtimeType}`), never names, phonetics, phones or JSON.
- Icon buttons are `HmmIconButton` with a localized tooltip only. `test/core/help/icon_button_guard_test.dart` must stay green.
- Every new user-visible string goes into both `app_en.arb` and `app_zh.arb` (key parity). Run `flutter gen-l10n` after every ARB edit and commit `lib/l10n/gen/`.
- Platform controls branch on `Theme.of(context).platform`: `CupertinoSlidingSegmentedControl` on iOS, `SegmentedButton` elsewhere. `flutter_platform_widgets` is not a dependency.
- `flutter analyze` must stay at exactly the 2 pre-existing infos (`onboarding_screen.dart`, `main.dart`).
- Full `flutter test` baseline is 1925 passing. It may only grow, with 0 failures.
- Stage only the files each task names (`git add <paths>`), never `git add -A`.
- Every commit message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- No push and no merge. The branch stays `feat/contacts-client`.

## Review Focus

1. **Chinese only in the given part** (`Smith` / `伟`). Auto must pick family-first with a space (`Smith 伟`), the sort key must transcribe only the given part (`smith|wei`), and search must find it by `smithwei` and `sw`. Pinned in Task 2 (`display: Chinese only in the given part`) and Task 4 (`sort: Chinese only in the given part`, `search: Chinese only in the given part`).
2. **Leading/trailing or full-width spaces** (`' 张 '` / `'伟　'`, a phonetic `' Zhāng '`). Display must trim each part to `张伟` while keeping an inner typed space (`娜 娜`). Sort must collapse U+3000. The phonetic validator must accept surrounding spaces. Pinned in Task 2 (`display: surrounding ASCII and full-width spaces are trimmed`, `phonetic validation table`) and Task 4 (`sort: full-width spaces collapse`).
3. **An empty phonetic field next to a filled one** (`phoneticFamily: 'Tsang'`, `phoneticGiven: ''` or `'  '`). The filled one must win and the empty one must fall back to automatic pinyin, not to an empty string. The edit form must not store the blank. Pinned in Task 4 (`sort: an empty phonetic beside a filled one falls back to pinyin`) and Task 8 (`phonetics are trimmed; blank phonetics are not stored`).
4. **The transcriber throws for one contact mid-list.** The list must still render, the other contacts must stay pinyin-sorted, the failing one must sort by its raw text, and exactly one log line must carry only the error type. Pinned in Task 4 (`sort: a throwing transcriber falls back to raw text`) and Task 7 (`one transcriber failure leaves the rest sorted and logs the type once`).
5. **Other scripts: kana, hangul, emoji, supplementary-plane Han.** Kana/hangul/emoji must be given-first with a space and never reach the transcriber. Kanji and `𠮷` (U+20BB7) must count as Han. Pinned in Task 2 (`display: other scripts`, `hasChinese reads supplementary-plane Han by rune`) and Task 4 (`sort: kana, hangul and emoji never reach the transcriber`).

### Deviations from the spec's task boundaries (forced by the code)

- **Entity fields move from Task 5 to Task 2.** The spec's Display-rules table has an Override column, so `ContactName.displayName(Contact)` needs `Contact.nameOrder`. Task 2 therefore adds `ContactNameOrder` and the three `Contact` fields (constructor, `copyWith`, `==`). Task 5 keeps everything about persistence: codec keys, raw preservation and the stored `displayName`.
- **The "untouched ⇒ stored `displayName` kept" rule needs new entity state.** Today the codec always rewrites `displayName` from the getter, and `contact_codec_test.dart` has a test asserting exactly that (`a stale stored displayName is ignored on read and rewritten`). Task 5 adds `Contact.storedDisplayName` (written back while the contact is unchanged since decode) and rewrites that test to match the spec.
- **The `|` key separator is compared part-wise.** As a raw string, `li|` sorts after `lin|` because `|` (U+007C) is greater than every letter. Task 4 keeps the spec's `family|given` key text but compares it with `compareContactKeys`, which splits on the single `|`. `normalizeForSearch` maps any `|` typed in a name to a space, so a key holds at most one `|`.
- **Registration is a Riverpod provider, not a startup call.** CLAUDE.md says Riverpod is the only DI. `derivedFieldRegistryProvider` lists the resolvers Contacts exports (`contactDerivedFields`) instead of Contacts mutating a global registry from `main.dart`.
- **The Settings help entry goes in the Contacts help sheet.** `SettingsScreen` has no `HelpId` or `HelpButton`. The sort-order help goes into `HelpId.contacts`, whose list it reorders. The Settings row gets `Icons.sort_by_alpha` so the help icon matches the control.

---

### Task 1: Pinyin library spike (THROWAWAY, outside the repo)

**Files:**
- Create (scratch only, never in the repo): `/private/tmp/claude-501/-Users-fchy-Projects-hmm-console/5c3f0d26-def2-4093-b2ee-61b4f0d0ed7f/scratchpad/pinyin_spike/`
- Modify: `docs/superpowers/plans/2026-10-06-contact-name-order.md` (fill in the `## Spike outcome` section at the end)

**Interfaces:**
- Consumes: nothing from the app.
- Produces: a decision, **A** (`pinyin_pro_flutter`) or **B** (`pinyin` 3.3.0 + surname table), that Task 3 uses to pick its implementation and dependency.

- [ ] **Step 1: Create the scratch project and record a baseline size**

```bash
SPIKE_ROOT=/private/tmp/claude-501/-Users-fchy-Projects-hmm-console/5c3f0d26-def2-4093-b2ee-61b4f0d0ed7f/scratchpad
mkdir -p "$SPIKE_ROOT" && cd "$SPIKE_ROOT"
rm -rf pinyin_spike
flutter create --org com.example.spike --platforms ios pinyin_spike
cd pinyin_spike
flutter --version | head -1
grep -n "sdk:" pubspec.yaml          # expect: sdk: ^3.11.x (same toolchain as the app)
flutter build ios --release --no-codesign
du -sk build/ios/iphoneos/Runner.app | tee size_before.txt
```

Expected: the build succeeds and `size_before.txt` holds one line of KB.

- [ ] **Step 2: Add the candidate library and make the app reference it** (so tree-shaking keeps the dictionary in the size measurement)

```bash
cd /private/tmp/claude-501/-Users-fchy-Projects-hmm-console/5c3f0d26-def2-4093-b2ee-61b4f0d0ed7f/scratchpad/pinyin_spike
flutter pub add pinyin_pro_flutter
grep -n "pinyin_pro_flutter" pubspec.yaml pubspec.lock
```

Replace `lib/main.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:pinyin_pro_flutter/pinyin_pro_flutter.dart' as pp;

void main() => runApp(const SpikeApp());

class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final out = pp.pinyin(
      '曾伟',
      options: pp.PinyinOptions(
        toneType: pp.ToneType.none,
        returnType: pp.PinyinReturnType.array,
        surname: pp.SurnameMode.head,
      ),
    );
    return MaterialApp(home: Scaffold(body: Center(child: Text('$out'))));
  }
}
```

- [ ] **Step 3: Write the surname test**

Replace `test/widget_test.dart` with `test/surname_test.dart` (delete the generated `test/widget_test.dart`):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pinyin_pro_flutter/pinyin_pro_flutter.dart' as pp;

List<String> family(String s) {
  final r = pp.pinyin(
    s,
    options: pp.PinyinOptions(
      toneType: pp.ToneType.none,
      returnType: pp.PinyinReturnType.array,
      surname: pp.SurnameMode.head,
    ),
  );
  return [for (final x in r as List) (x as String).trim().toLowerCase()];
}

void main() {
  const expected = {
    '曾': 'zeng',
    '单': 'shan',
    '解': 'xie',
    '区': 'ou',
    '仇': 'qiu',
    '朴': 'piao',
    '查': 'zha',
    '盖': 'ge',
  };

  for (final e in expected.entries) {
    test('surname ${e.key} -> ${e.value}', () {
      expect(family(e.key), [e.value]);
    });
  }

  test('is synchronous and needs no init call', () {
    // Called cold, first thing: no ensureInitialized / asset load.
    expect(family('欧阳'), ['ou', 'yang']);
  });
}
```

```bash
cd /private/tmp/claude-501/-Users-fchy-Projects-hmm-console/5c3f0d26-def2-4093-b2ee-61b4f0d0ed7f/scratchpad/pinyin_spike
rm -f test/widget_test.dart
flutter test test/surname_test.dart 2>&1 | tee surname_result.txt
```

Expected outputs: `zeng, shan, xie, ou, qiu, piao, zha, ge`, and `['ou', 'yang']` for 欧阳. If an enum or parameter name does not compile (`ToneType.none`, `PinyinReturnType.array`, `SurnameMode.head`), look up the real name with `grep -rn "enum " ~/.pub-cache/hosted/pub.dev/pinyin_pro_flutter-*/lib | head -40`, fix both files, record the real names in the Spike outcome, and use them in Task 3 variant A.

- [ ] **Step 4: Measure the release size delta**

```bash
cd /private/tmp/claude-501/-Users-fchy-Projects-hmm-console/5c3f0d26-def2-4093-b2ee-61b4f0d0ed7f/scratchpad/pinyin_spike
flutter build ios --release --no-codesign
du -sk build/ios/iphoneos/Runner.app | tee size_after.txt
echo "delta KB: $(( $(cut -f1 size_after.txt) - $(cut -f1 size_before.txt) ))"
```

- [ ] **Step 5: Apply the decision rule**

- **Adopt A (`pinyin_pro_flutter`)** only when all 8 surname tests pass, the 欧阳 test passes (synchronous, no init), and both builds succeeded under the app's Dart `^3.11` toolchain.
- **Otherwise adopt B** (`pinyin` 3.3.0 + the polyphonic-surname table in Task 3 variant B). A library that needs an async init or asset load counts as a failure, because the `PinyinTranscriber` interface is synchronous.
- Size does not veto either choice. Record it so the reviewer sees it.

- [ ] **Step 6: Record the outcome in this plan and in the execution ledger**

Fill in the `## Spike outcome` section at the end of this file: decision A/B, each surname's actual output, the sync/no-init result, the toolchain line, before/after KB and the delta, and any corrected API names. Copy the same one-line decision into the controller's execution ledger (the task list kept by superpowers:subagent-driven-development), so Task 3's subagent receives it. Nothing from the scratch project enters the repo.

```bash
cd /Users/fchy/Projects/hmm_console
git add docs/superpowers/plans/2026-10-06-contact-name-order.md
git commit -m "docs(contacts): record pinyin library spike outcome

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: `ContactName` (pure display rules) and the name fields on `Contact`

**Files:**
- Create: `lib/features/contacts/domain/contact_name.dart`
- Modify: `lib/features/contacts/domain/entities/contact.dart`: add `ContactNameOrder` after `enum ContactType` (line 6). Replace the whole `class Contact` (lines 80–237) with the version below.
- Test: `test/features/contacts/domain/contact_name_test.dart`

**Interfaces:**
- Consumes: `Contact`, `ContactType` (existing).
- Produces:
  ```dart
  enum ContactNameOrder { auto, givenFirst, familyFirst }   // in contact.dart, stored by name
  // Contact gains: final ContactNameOrder nameOrder; final String? phoneticFamily; final String? phoneticGiven;
  // Contact.copyWith gains: ContactNameOrder? nameOrder, Object? phoneticFamily = _kSentinel, Object? phoneticGiven = _kSentinel
  // String get Contact.displayName => ContactName.displayName(this);
  abstract final class ContactName {
    static bool isHanRune(int rune);
    static bool hasChinese(String? s);
    static List<(bool han, String text)> hanRuns(String s);
    static ContactNameOrder effectiveOrder(Contact c);   // never returns auto
    static String displayName(Contact c);
    static bool isValidPhonetic(String s);
  }
  ```
  `firstName` is the **given** name and `lastName` the **family** name. They keep their stored keys.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/contacts/domain/contact_name_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/contacts/domain/contact_name.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';

Contact _p(
  String? family,
  String? given, [
  ContactNameOrder order = ContactNameOrder.auto,
]) => Contact(
  id: 'c',
  contactType: ContactType.person,
  lastName: family,
  firstName: given,
  nameOrder: order,
);

void main() {
  group('display rules table (spec)', () {
    final rows = <(String?, String?, ContactNameOrder, String)>[
      ('张', '伟', ContactNameOrder.auto, '张伟'),
      ('欧阳', '娜娜', ContactNameOrder.auto, '欧阳娜娜'),
      ('张', 'David', ContactNameOrder.auto, '张 David'),
      ('Smith', 'John', ContactNameOrder.auto, 'John Smith'),
      ('Zhang', 'Wei', ContactNameOrder.auto, 'Wei Zhang'),
      ('Zhang', 'Wei', ContactNameOrder.familyFirst, 'Zhang Wei'),
      ('张', '伟', ContactNameOrder.givenFirst, '伟 张'),
      ('张', null, ContactNameOrder.auto, '张'),
      (null, 'John', ContactNameOrder.auto, 'John'),
    ];
    for (final (family, given, order, shown) in rows) {
      test('$family / $given / ${order.name} -> $shown', () {
        final c = _p(family, given, order);
        expect(ContactName.displayName(c), shown);
        expect(c.displayName, shown);
      });
    }

    test('an organization shows its organization name', () {
      const org = Contact(
        id: 'o',
        contactType: ContactType.organization,
        organizationName: '人民医院',
        firstName: 'ignored',
        lastName: 'ignored',
      );
      expect(org.displayName, '人民医院');
      expect(
        const Contact(id: 'o', contactType: ContactType.organization)
            .displayName,
        '',
      );
    });
  });

  test('display: Chinese only in the given part', () {
    expect(_p('Smith', '伟').displayName, 'Smith 伟');
    expect(
      ContactName.effectiveOrder(_p('Smith', '伟')),
      ContactNameOrder.familyFirst,
    );
  });

  test('display: surrounding ASCII and full-width spaces are trimmed', () {
    expect(_p(' 张 ', '伟　').displayName, '张伟');
    expect(_p('  ', '').displayName, '');
    expect(_p('', 'John').displayName, 'John');
  });

  test('display: a space typed inside a Chinese part is kept', () {
    expect(_p('欧阳', '娜 娜').displayName, '欧阳娜 娜');
  });

  test('display: other scripts', () {
    // Kana and hangul are not Han: given-first with a space under Auto.
    expect(_p('やまだ', 'たろう').displayName, 'たろう やまだ');
    expect(_p('김', '민준').displayName, '민준 김');
    // Kanji are Han, so family-first with no space (right for Japanese too).
    expect(_p('山田', '太郎').displayName, '山田太郎');
    expect(_p('😀', 'Ann').displayName, 'Ann 😀');
    // The per-contact override still applies.
    expect(
      _p('김', '민준', ContactNameOrder.familyFirst).displayName,
      '김 민준',
    );
  });

  test('hasChinese reads supplementary-plane Han by rune', () {
    expect(ContactName.hasChinese('𠮷'), isTrue); // U+20BB7
    expect(_p('𠮷', '田').displayName, '𠮷田');
    expect(ContactName.hasChinese('😀'), isFalse);
    expect(ContactName.hasChinese('　'), isFalse);
    expect(ContactName.hasChinese('㐀'), isTrue); // U+3400
    expect(ContactName.hasChinese('豈'), isTrue); // U+F900
    expect(ContactName.hasChinese(null), isFalse);
    expect(ContactName.hasChinese(''), isFalse);
  });

  test('hanRuns splits maximal Han and non-Han runs', () {
    expect(ContactName.hanRuns('张David 伟'), [
      (true, '张'),
      (false, 'David '),
      (true, '伟'),
    ]);
    expect(ContactName.hanRuns(''), isEmpty);
  });

  test('effectiveOrder never returns auto', () {
    expect(
      ContactName.effectiveOrder(_p('Zhang', 'Wei')),
      ContactNameOrder.givenFirst,
    );
    expect(
      ContactName.effectiveOrder(_p('张', '伟')),
      ContactNameOrder.familyFirst,
    );
    expect(
      ContactName.effectiveOrder(_p('张', '伟', ContactNameOrder.givenFirst)),
      ContactNameOrder.givenFirst,
    );
  });

  test('phonetic validation table', () {
    const valid = [
      '',
      'Zhang',
      'Zhāng',
      'lǚ',
      'Lǜ',
      "Xi'an",
      'Xi’an', // iOS smart punctuation types U+2019
      ' wei ',
      'ou yang',
      'ou　yang',
    ];
    const invalid = ['张', 'zh4ng', 'a-b', 'wei.', 'x|y', 'Иван'];
    for (final v in valid) {
      expect(ContactName.isValidPhonetic(v), isTrue, reason: v);
    }
    for (final v in invalid) {
      expect(ContactName.isValidPhonetic(v), isFalse, reason: v);
    }
  });

  test('copyWith sets and clears the name options', () {
    final c = _p('张', '伟').copyWith(
      nameOrder: ContactNameOrder.givenFirst,
      phoneticFamily: 'Zhang',
      phoneticGiven: 'Wei',
    );
    expect(c.nameOrder, ContactNameOrder.givenFirst);
    expect(c.phoneticFamily, 'Zhang');
    final cleared = c.copyWith(phoneticFamily: null);
    expect(cleared.phoneticFamily, isNull);
    expect(cleared.phoneticGiven, 'Wei');
    expect(c == _p('张', '伟'), isFalse);
    expect(
      _p('张', '伟').copyWith(phoneticFamily: 'Zhang'),
      _p('张', '伟').copyWith(phoneticFamily: 'Zhang'),
    );
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/contacts/domain/contact_name_test.dart`
Expected: compile failure, `Target of URI doesn't exist: 'package:hmm_console/features/contacts/domain/contact_name.dart'` and `The named parameter 'nameOrder' isn't defined`.

- [ ] **Step 3: Implement `contact_name.dart`**

```dart
// lib/features/contacts/domain/contact_name.dart
import 'entities/contact.dart';

/// Every rule about how a contact's name parts are ordered and joined.
/// Nothing outside this file re-implements ordering: `Contact.displayName`,
/// the list, the detail screen, the codec and cheatsheet cards all come here.
///
/// `Contact.firstName` is the GIVEN name and `Contact.lastName` the FAMILY
/// name; the stored keys keep their historical names.
abstract final class ContactName {
  /// Han ideographs: CJK Extension A, Unified, Compatibility, and the
  /// supplementary planes (Extensions B and later, Compatibility Supplement).
  static bool isHanRune(int r) =>
      (r >= 0x3400 && r <= 0x4DBF) ||
      (r >= 0x4E00 && r <= 0x9FFF) ||
      (r >= 0xF900 && r <= 0xFAFF) ||
      (r >= 0x20000 && r <= 0x2FA1F);

  /// Iterates runes, not UTF-16 units, so Extension B (`𠮷`) counts.
  static bool hasChinese(String? s) => s != null && s.runes.any(isHanRune);

  /// [s] split into maximal runs of Han and non-Han text, in order.
  static List<(bool han, String text)> hanRuns(String s) {
    final out = <(bool, String)>[];
    final buf = StringBuffer();
    bool? current;
    for (final r in s.runes) {
      final han = isHanRune(r);
      if (current != null && han != current) {
        out.add((current, buf.toString()));
        buf.clear();
      }
      current = han;
      buf.writeCharCode(r);
    }
    if (current != null) out.add((current, buf.toString()));
    return out;
  }

  /// The override if set; under Auto, family-first when either part contains
  /// a Han character. Never returns [ContactNameOrder.auto].
  static ContactNameOrder effectiveOrder(Contact c) => switch (c.nameOrder) {
    ContactNameOrder.givenFirst => ContactNameOrder.givenFirst,
    ContactNameOrder.familyFirst => ContactNameOrder.familyFirst,
    ContactNameOrder.auto =>
      hasChinese(c.lastName) || hasChinese(c.firstName)
          ? ContactNameOrder.familyFirst
          : ContactNameOrder.givenFirst,
  };

  /// Organizations show [Contact.organizationName]. People show their parts
  /// in [effectiveOrder]; family-first joins with no space only when BOTH
  /// parts contain Chinese. Each part is trimmed (Dart's trim includes
  /// U+3000); a space inside a part is kept as typed.
  static String displayName(Contact c) {
    if (c.contactType == ContactType.organization) {
      return c.organizationName ?? '';
    }
    final given = c.firstName?.trim() ?? '';
    final family = c.lastName?.trim() ?? '';
    if (given.isEmpty) return family;
    if (family.isEmpty) return given;
    return switch (effectiveOrder(c)) {
      ContactNameOrder.familyFirst =>
        hasChinese(family) && hasChinese(given)
            ? '$family$given'
            : '$family $given',
      _ => '$given $family',
    };
  }

  static final _phonetic = RegExp(
    "^[A-Za-zāáǎàēéěèīíǐìōóǒòūúǔùüǖǘǚǜĀÁǍÀĒÉĚÈĪÍǏÌŌÓǑÒŪÚǓÙÜǕǗǙǛ '’　]*\$",
  );

  /// Latin letters (tone marks and ü included), spaces and apostrophes
  /// (straight or iOS's curly U+2019). Checked after trimming; empty is valid.
  static bool isValidPhonetic(String s) => _phonetic.hasMatch(s.trim());
}
```

- [ ] **Step 4: Add `ContactNameOrder` and the fields on `Contact`**

In `lib/features/contacts/domain/entities/contact.dart`, add this import at the top, after `import 'contact_field.dart';`:

```dart
import '../contact_name.dart';
```

After `enum ContactType { person, organization }` add:

```dart

/// Per-contact display order override. Stored by `name` under `nameOrder`
/// only when not [auto]. NEVER localize; display copy is in
/// `contact_labels.dart`.
enum ContactNameOrder { auto, givenFirst, familyFirst }
```

Replace the whole `class Contact { ... }` (from `/// A person or organization in the address book.` to the end of the file) with:

```dart
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
    this.nameOrder = ContactNameOrder.auto,
    this.phoneticFamily,
    this.phoneticGiven,
    this.phones = const [],
    this.emails = const [],
    this.addresses = const [],
    this.relationship = const ContactRelationship(),
    this.isSelf = false,
    this.notes,
    this.isActivated = true,
    this.extraFields = const {},
    this.storedSchemaVersion = 1,
    this.rawKnownValues = const {},
    this.unreadableEntries = const {},
    String? rawContactType,
  }) : _rawContactType = rawContactType;

  /// The `schemaVersion` this contact was read with. A save writes the larger
  /// of this and the codec's current version, so an older client never
  /// downgrades a newer client's data.
  final int storedSchemaVersion;

  final String id;
  final ContactType contactType;

  /// The GIVEN name (stored key `firstName`).
  final String? firstName;

  /// The FAMILY name (stored key `lastName`).
  final String? lastName;
  final String? organizationName;

  /// Display-order override; see `ContactName.effectiveOrder`.
  final ContactNameOrder nameOrder;

  /// Optional romanization of [lastName] / [firstName]. When set it wins over
  /// automatic pinyin for sort and search; it never changes the display.
  final String? phoneticFamily;
  final String? phoneticGiven;

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

  /// Known top-level keys whose stored value had the wrong type, kept
  /// verbatim and written back while the typed field still holds what that
  /// value decoded to; see `ContactCodec`.
  final Map<String, dynamic> rawKnownValues;

  /// List entries (by list key: `phones`, `emails`, `addresses`) that could
  /// not be decoded. Never shown or edited; re-emitted after the readable
  /// entries on save so they are not lost.
  final Map<String, List<dynamic>> unreadableEntries;

  /// Raw enum string from storage (to preserve unknown values).
  final String? _rawContactType;

  /// Returns the contact type name to store: raw value if available and unchanged,
  /// otherwise the typed enum name.
  String get storedContactTypeName => _rawContactType ?? contactType.name;

  /// Derived, never read back: see `ContactName.displayName`.
  String get displayName => ContactName.displayName(this);

  Contact copyWith({
    String? id,
    ContactType? contactType,
    Object? firstName = _kSentinel,
    Object? lastName = _kSentinel,
    Object? organizationName = _kSentinel,
    ContactNameOrder? nameOrder,
    Object? phoneticFamily = _kSentinel,
    Object? phoneticGiven = _kSentinel,
    List<ContactPhone>? phones,
    List<ContactEmail>? emails,
    List<ContactAddress>? addresses,
    ContactRelationship? relationship,
    bool? isSelf,
    Object? notes = _kSentinel,
    bool? isActivated,
    Map<String, dynamic>? extraFields,
  }) =>
      Contact(
        id: id ?? this.id,
        contactType: contactType ?? this.contactType,
        firstName:
            identical(firstName, _kSentinel) ? this.firstName : firstName as String?,
        lastName: identical(lastName, _kSentinel) ? this.lastName : lastName as String?,
        organizationName: identical(organizationName, _kSentinel)
            ? this.organizationName
            : organizationName as String?,
        nameOrder: nameOrder ?? this.nameOrder,
        phoneticFamily: identical(phoneticFamily, _kSentinel)
            ? this.phoneticFamily
            : phoneticFamily as String?,
        phoneticGiven: identical(phoneticGiven, _kSentinel)
            ? this.phoneticGiven
            : phoneticGiven as String?,
        phones: phones ?? this.phones,
        emails: emails ?? this.emails,
        addresses: addresses ?? this.addresses,
        relationship: relationship ?? this.relationship,
        isSelf: isSelf ?? this.isSelf,
        notes: identical(notes, _kSentinel) ? this.notes : notes as String?,
        isActivated: isActivated ?? this.isActivated,
        extraFields: extraFields ?? this.extraFields,
        storedSchemaVersion: storedSchemaVersion,
        rawKnownValues: rawKnownValues,
        unreadableEntries: unreadableEntries,
        rawContactType: contactType != null ? null : _rawContactType,
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
          other.nameOrder == nameOrder &&
          other.phoneticFamily == phoneticFamily &&
          other.phoneticGiven == phoneticGiven &&
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
        nameOrder,
        phoneticFamily,
        phoneticGiven,
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

- [ ] **Step 5: Run the new test and the existing contact tests**

Run: `flutter test test/features/contacts/domain/contact_name_test.dart test/features/contacts/domain/contact_test.dart test/features/contacts/data/contact_codec_test.dart`
Expected: all pass. The existing `displayName` tests use Latin names, which stay given-first.

- [ ] **Step 6: Commit**

```bash
git add lib/features/contacts/domain/contact_name.dart lib/features/contacts/domain/entities/contact.dart test/features/contacts/domain/contact_name_test.dart
git commit -m "feat(contacts): name order rules and per-contact name options

ContactName owns display order: Chinese names family-first with no space,
mixed family-first with a space, Latin given-first, per-contact override.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: `PinyinTranscriber` interface, the real implementation, and its provider

**Files:**
- Create: `lib/features/contacts/domain/pinyin_transcriber.dart`
- Create, decision **A**: `lib/features/contacts/data/pinyin_pro_transcriber.dart`
- Create, decision **B** (instead of A): `lib/features/contacts/data/pinyin_table_transcriber.dart`
- Create: `lib/features/contacts/states/pinyin_transcriber_provider.dart`
- Modify: `pubspec.yaml` and `pubspec.lock` (via `flutter pub add`)
- Test: `test/features/contacts/data/pinyin_transcriber_integration_test.dart`

**Interfaces:**
- Consumes: `ContactName.hanRuns`, `ContactName.isHanRune` (Task 2). The spike decision (Task 1).
- Produces:
  ```dart
  abstract interface class PinyinTranscriber {
    List<String> family(String text);   // surname mode
    List<String> given(String text);
  }
  class DefaultPinyinTranscriber implements PinyinTranscriber { const DefaultPinyinTranscriber(); }
  final pinyinTranscriberProvider = Provider<PinyinTranscriber>(...);
  ```
  Output is toneless lowercase syllables for Han runs (ü kept as `ü`). Non-Han runs are split on whitespace and pass through unchanged, case included. Surname mode applies only to a Han run at the very start of the trimmed text.

Implement **only** the variant the spike chose and delete the other block from your working notes. Both variants define `class DefaultPinyinTranscriber`, so everything downstream is identical.

- [ ] **Step 1: Write the failing integration test**

```dart
// test/features/contacts/data/pinyin_transcriber_integration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/contacts/states/pinyin_transcriber_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pins the real dependency: a version bump that breaks a polyphonic surname
/// fails CI here instead of quietly mis-sorting the address book.
void main() {
  final t = ProviderContainer().read(pinyinTranscriberProvider);

  const surnames = {
    '曾': 'zeng',
    '单': 'shan',
    '解': 'xie',
    '区': 'ou',
    '仇': 'qiu',
    '朴': 'piao',
    '查': 'zha',
    '盖': 'ge',
  };
  for (final e in surnames.entries) {
    test('surname ${e.key} -> ${e.value}', () {
      expect(t.family(e.key), [e.value]);
    });
  }

  test('a compound surname and a given name', () {
    expect(t.family('欧阳'), ['ou', 'yang']);
    expect(t.given('伟'), ['wei']);
    expect(t.given('娜娜'), ['na', 'na']);
  });

  test('non-Han text passes through unchanged; empty is empty', () {
    expect(t.family('张 David'), ['zhang', 'David']);
    expect(t.given('Wei'), ['Wei']);
    expect(t.family(''), isEmpty);
    expect(t.given('   '), isEmpty);
  });

  test('output is toneless lowercase', () {
    for (final s in [...t.family('张'), ...t.given('伟明')]) {
      expect(s, s.toLowerCase());
      expect(s, isNot(matches(RegExp('[āáǎàēéěèīíǐìōóǒòūúǔù]'))));
    }
  });
}
```

Decision **B** also appends this test inside `main()`:

```dart
  test('fallback surname table', () {
    const table = {
      '尉迟': ['yu', 'chi'],
      '万俟': ['mo', 'qi'],
      '长孙': ['zhang', 'sun'],
      '乐': ['yue'],
      '缪': ['miao'],
      '覃': ['qin'],
      '翟': ['zhai'],
      '召': ['shao'],
      '隗': ['wei'],
      '句': ['gou'],
      '秘': ['bi'],
    };
    for (final e in table.entries) {
      expect(t.family(e.key), e.value, reason: e.key);
    }
    expect(t.given('吕'), ['lü']);
  });
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/contacts/data/pinyin_transcriber_integration_test.dart`
Expected: compile failure, `Target of URI doesn't exist: 'package:hmm_console/features/contacts/states/pinyin_transcriber_provider.dart'`.

- [ ] **Step 3: Add the dependency**

Decision **A**:
```bash
cd /Users/fchy/Projects/hmm_console && flutter pub add pinyin_pro_flutter:^1.0.3
```
Decision **B**:
```bash
cd /Users/fchy/Projects/hmm_console && flutter pub add pinyin:^3.3.0
```

Then add a one-line comment above the new `pubspec.yaml` entry: `# Contacts: pinyin for sort + search only (never persisted); see PinyinTranscriber.`

- [ ] **Step 4: Write the interface**

```dart
// lib/features/contacts/domain/pinyin_transcriber.dart

/// Romanizes Chinese name parts for sorting and search. Read-time only:
/// nothing it returns is ever persisted. Behind an interface so the library
/// can be swapped and tests can use a fake.
abstract interface class PinyinTranscriber {
  /// Surname mode: a polyphonic leading surname reads as a surname
  /// (曾 → zeng, 单 → shan). Toneless lowercase syllables for Han text;
  /// non-Han text is split on whitespace and passed through unchanged.
  List<String> family(String text);

  /// Same as [family] without surname handling.
  List<String> given(String text);
}
```

- [ ] **Step 5a (decision A): implement on `pinyin_pro_flutter`**

Use the API names recorded in the Spike outcome if they differ from these.

```dart
// lib/features/contacts/data/pinyin_pro_transcriber.dart
import 'package:pinyin_pro_flutter/pinyin_pro_flutter.dart' as pp;

import '../domain/contact_name.dart';
import '../domain/pinyin_transcriber.dart';

/// [PinyinTranscriber] on `pinyin_pro_flutter`, chosen by the 2026-10-06
/// spike. Han runs are transcribed one at a time so mixed text never depends
/// on the library's non-Chinese handling.
class DefaultPinyinTranscriber implements PinyinTranscriber {
  const DefaultPinyinTranscriber();

  static final _ws = RegExp(r'\s+');

  @override
  List<String> family(String text) => _transcribe(text, surname: true);

  @override
  List<String> given(String text) => _transcribe(text, surname: false);

  List<String> _transcribe(String text, {required bool surname}) {
    final out = <String>[];
    var first = true;
    for (final (han, run) in ContactName.hanRuns(text.trim())) {
      if (han) {
        out.addAll(_han(run, surname: surname && first));
      } else {
        out.addAll(run.split(_ws).where((s) => s.isNotEmpty));
      }
      first = false;
    }
    return out;
  }

  static List<String> _han(String run, {required bool surname}) {
    final result = pp.pinyin(
      run,
      options: pp.PinyinOptions(
        toneType: pp.ToneType.none,
        returnType: pp.PinyinReturnType.array,
        surname: surname ? pp.SurnameMode.head : pp.SurnameMode.off,
      ),
    );
    return [
      for (final s in result as List)
        if ((s as String).trim().isNotEmpty) s.trim().toLowerCase(),
    ];
  }
}
```

- [ ] **Step 5b (decision B): implement on `pinyin` 3.3.0 plus a surname table**

```dart
// lib/features/contacts/data/pinyin_table_transcriber.dart
import 'package:pinyin/pinyin.dart';

import '../domain/contact_name.dart';
import '../domain/pinyin_transcriber.dart';

/// [PinyinTranscriber] on `pinyin` 3.3.0. That library has no surname mode,
/// so a leading polyphonic surname is read from [_compoundSurnames] /
/// [_surnames] first; the rest goes through the dictionary.
class DefaultPinyinTranscriber implements PinyinTranscriber {
  const DefaultPinyinTranscriber();

  static final _ws = RegExp(r'\s+');

  static const _compoundSurnames = <String, List<String>>{
    '尉迟': ['yu', 'chi'],
    '万俟': ['mo', 'qi'],
    '长孙': ['zhang', 'sun'],
  };

  static const _surnames = <String, String>{
    '曾': 'zeng',
    '单': 'shan',
    '解': 'xie',
    '区': 'ou',
    '仇': 'qiu',
    '朴': 'piao',
    '查': 'zha',
    '盖': 'ge',
    '乐': 'yue',
    '缪': 'miao',
    '覃': 'qin',
    '翟': 'zhai',
    '召': 'shao',
    '隗': 'wei',
    '句': 'gou',
    '秘': 'bi',
  };

  @override
  List<String> family(String text) => _transcribe(text, surname: true);

  @override
  List<String> given(String text) => _transcribe(text, surname: false);

  List<String> _transcribe(String text, {required bool surname}) {
    final out = <String>[];
    var first = true;
    for (final (han, run) in ContactName.hanRuns(text.trim())) {
      if (!han) {
        out.addAll(run.split(_ws).where((s) => s.isNotEmpty));
      } else if (surname && first) {
        out.addAll(_surnameRun(run));
      } else {
        out.addAll(_dict(run));
      }
      first = false;
    }
    return out;
  }

  static List<String> _surnameRun(String run) {
    for (final e in _compoundSurnames.entries) {
      if (run.startsWith(e.key)) {
        return [...e.value, ..._dict(run.substring(e.key.length))];
      }
    }
    final head = String.fromCharCode(run.runes.first);
    final known = _surnames[head];
    if (known == null) return _dict(run);
    return [known, ..._dict(run.substring(head.length))];
  }

  /// WITHOUT_TONE writes ü as `v`; no pinyin syllable otherwise contains a
  /// `v`, so it maps back to `ü` (the sort key folds ü to u).
  static List<String> _dict(String run) {
    if (run.isEmpty) return const [];
    return PinyinHelper.getPinyinE(
      run,
      separator: ' ',
      defPinyin: '',
      format: PinyinFormat.WITHOUT_TONE,
    )
        .split(' ')
        .where((s) => s.isNotEmpty)
        .map((s) => s.toLowerCase().replaceAll('v', 'ü'))
        .toList();
  }
}
```

- [ ] **Step 6: Write the provider**

```dart
// lib/features/contacts/states/pinyin_transcriber_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Decision A:
import '../data/pinyin_pro_transcriber.dart';
// Decision B (instead of the line above):
// import '../data/pinyin_table_transcriber.dart';
import '../domain/pinyin_transcriber.dart';

/// Watched only by the contacts list and the contact edit form, so the
/// dictionary is first touched on those screens, never on the dashboard.
/// Tests override it with a fake.
final pinyinTranscriberProvider = Provider<PinyinTranscriber>(
  (ref) => const DefaultPinyinTranscriber(),
);
```

Keep exactly one import line, the one for the chosen variant, and delete the comment pair.

- [ ] **Step 7: Run it and watch it pass**

Run: `flutter test test/features/contacts/data/pinyin_transcriber_integration_test.dart`
Expected: all pass (11 tests for A; 12 for B).

- [ ] **Step 8: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/contacts/domain/pinyin_transcriber.dart lib/features/contacts/states/pinyin_transcriber_provider.dart test/features/contacts/data/pinyin_transcriber_integration_test.dart
# plus exactly one of:
git add lib/features/contacts/data/pinyin_pro_transcriber.dart     # A
git add lib/features/contacts/data/pinyin_table_transcriber.dart   # B
git commit -m "feat(contacts): pinyin transcriber behind an interface

Read-time only, never persisted. The integration test pins the eight
polyphonic surnames so a dependency bump that breaks them fails CI.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: `contact_sort.dart` (sort keys, search terms, matching)

**Files:**
- Create: `lib/features/contacts/domain/contact_sort_by.dart`
- Create: `lib/features/contacts/domain/contact_sort.dart`
- Create: `test/features/contacts/fake_pinyin_transcriber.dart` (shared test fake)
- Test: `test/features/contacts/domain/contact_sort_test.dart`

**Interfaces:**
- Consumes: `ContactName` (Task 2), `PinyinTranscriber` (Task 3).
- Produces:
  ```dart
  enum ContactSortBy { family, given; static ContactSortBy fromName(Object? name); }
  String normalizeForSearch(String s);
  String sortKey(Contact c, ContactSortBy by, PinyinTranscriber? t, {void Function(Object error)? onError});
  int compareContactKeys(Contact a, String keyA, Contact b, String keyB);
  class ContactSearchTerms { const ContactSearchTerms({required List<String> contains, required List<String> prefixes}); }
  ContactSearchTerms searchTerms(Contact c, PinyinTranscriber? t, {void Function(Object error)? onError});
  bool matchesSearch(Contact c, ContactSearchTerms terms, String query);
  ```
  A `null` transcriber means no pinyin (the repository uses this). `onError` gets each transcriber exception; the caller decides how to log it.

- [ ] **Step 1: Write the shared fake**

```dart
// test/features/contacts/fake_pinyin_transcriber.dart
import 'package:hmm_console/features/contacts/domain/contact_name.dart';
import 'package:hmm_console/features/contacts/domain/pinyin_transcriber.dart';

/// Deterministic table transcriber. An unmapped Han character throws, so a
/// test can never pass on pinyin it did not declare. [throwOn] inputs throw a
/// StateError to model a dictionary failure.
class FakePinyinTranscriber implements PinyinTranscriber {
  FakePinyinTranscriber({this.throwOn = const {}});

  final Set<String> throwOn;
  int calls = 0;

  static const _compound = {'欧阳': ['ou', 'yang']};
  static const _chars = {
    '张': ['zhang'],
    '伟': ['wei'],
    '李': ['li'],
    '丽': ['li'],
    '王': ['wang'],
    '娜': ['na'],
    '明': ['ming'],
    '曾': ['zeng'],
    '林': ['lin'],
    '人': ['ren'],
    '民': ['min'],
    '医': ['yi'],
    '院': ['yuan'],
  };

  @override
  List<String> family(String text) => _run(text, surname: true);

  @override
  List<String> given(String text) => _run(text, surname: false);

  List<String> _run(String text, {required bool surname}) {
    calls++;
    if (throwOn.contains(text)) throw StateError('dictionary unavailable');
    final out = <String>[];
    for (final (han, part) in ContactName.hanRuns(text.trim())) {
      if (!han) {
        out.addAll(part.split(RegExp(r'\s+')).where((s) => s.isNotEmpty));
        continue;
      }
      var rest = part;
      if (surname) {
        for (final e in _compound.entries) {
          if (rest.startsWith(e.key)) {
            out.addAll(e.value);
            rest = rest.substring(e.key.length);
            break;
          }
        }
      }
      for (final r in rest.runes) {
        final s = _chars[String.fromCharCode(r)];
        if (s == null) throw ArgumentError('unmapped Han character');
        out.addAll(s);
      }
    }
    return out;
  }
}
```

- [ ] **Step 2: Write the failing test**

```dart
// test/features/contacts/domain/contact_sort_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/contacts/domain/contact_sort.dart';
import 'package:hmm_console/features/contacts/domain/contact_sort_by.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact_field.dart';

import '../fake_pinyin_transcriber.dart';

Contact _p(
  String id,
  String? family,
  String? given, {
  String? phFamily,
  String? phGiven,
}) => Contact(
  id: id,
  contactType: ContactType.person,
  lastName: family,
  firstName: given,
  phoneticFamily: phFamily,
  phoneticGiven: phGiven,
);

Contact _org(String id, String name) => Contact(
  id: id,
  contactType: ContactType.organization,
  organizationName: name,
);

List<String> _sorted(
  List<Contact> cs,
  ContactSortBy by,
  FakePinyinTranscriber t,
) {
  final keys = {for (final c in cs) c.id: sortKey(c, by, t)};
  final out = [...cs]
    ..sort((a, b) => compareContactKeys(a, keys[a.id]!, b, keys[b.id]!));
  return [for (final c in out) c.id];
}

void main() {
  late FakePinyinTranscriber t;
  setUp(() => t = FakePinyinTranscriber());

  group('ContactSortBy.fromName', () {
    test('reads given; anything else is family', () {
      expect(ContactSortBy.fromName('given'), ContactSortBy.given);
      expect(ContactSortBy.fromName('family'), ContactSortBy.family);
      expect(ContactSortBy.fromName(null), ContactSortBy.family);
      expect(ContactSortBy.fromName('bogus'), ContactSortBy.family);
      expect(ContactSortBy.fromName(3), ContactSortBy.family);
    });
  });

  group('normalizeForSearch', () {
    test('lowercases, folds accents, collapses whitespace, drops |', () {
      expect(normalizeForSearch('  Émile   ZOLA '), 'emile zola');
      expect(normalizeForSearch('Müller'), 'muller');
      expect(normalizeForSearch('lǚ Zhāng'), 'lu zhang');
      expect(normalizeForSearch('a　b'), 'a b');
      expect(normalizeForSearch('A|B'), 'a b');
      expect(normalizeForSearch('张伟'), '张伟');
    });
  });

  group('sortKey', () {
    test('family and given modes for Chinese and Latin names', () {
      expect(sortKey(_p('1', '张', '伟'), ContactSortBy.family, t), 'zhang|wei');
      expect(sortKey(_p('1', '张', '伟'), ContactSortBy.given, t), 'wei|zhang');
      expect(
        sortKey(_p('2', 'Smith', 'John'), ContactSortBy.family, t),
        'smith|john',
      );
      expect(
        sortKey(_p('2', 'Smith', 'John'), ContactSortBy.given, t),
        'john|smith',
      );
      expect(
        sortKey(_p('3', '欧阳', '娜娜'), ContactSortBy.family, t),
        'ou yang|na na',
      );
    });

    test('accent folding', () {
      expect(
        sortKey(_p('1', 'Zola', 'Émile'), ContactSortBy.family, t),
        'zola|emile',
      );
      expect(
        sortKey(_p('2', 'Müller', 'Jürgen'), ContactSortBy.family, t),
        'muller|jurgen',
      );
    });

    test('a phonetic field overrides automatic pinyin', () {
      expect(
        sortKey(_p('1', '曾', '伟', phFamily: 'Tsang'), ContactSortBy.family, t),
        'tsang|wei',
      );
      expect(
        sortKey(_p('2', '曾', '伟', phFamily: 'Zēng'), ContactSortBy.family, t),
        'zeng|wei',
      );
      expect(
        sortKey(
          _p('3', 'Smith', 'John', phGiven: "Jo'n"),
          ContactSortBy.family,
          t,
        ),
        'smith|jo n',
      );
    });

    test('sort: an empty phonetic beside a filled one falls back to pinyin',
        () {
      for (final empty in [null, '', '   ']) {
        expect(
          sortKey(
            _p('1', '曾', '伟', phFamily: 'Tsang', phGiven: empty),
            ContactSortBy.family,
            t,
          ),
          'tsang|wei',
          reason: '$empty',
        );
      }
    });

    test('sort: Chinese only in the given part', () {
      expect(
        sortKey(_p('1', 'Smith', '伟'), ContactSortBy.family, t),
        'smith|wei',
      );
    });

    test('sort: full-width spaces collapse', () {
      expect(
        sortKey(_p('1', ' Zhang　', 'Wei  Li'), ContactSortBy.family, t),
        'zhang|wei li',
      );
    });

    test('a single name part leads the key in either mode', () {
      expect(sortKey(_p('1', '张', null), ContactSortBy.family, t), 'zhang|');
      expect(sortKey(_p('1', '张', null), ContactSortBy.given, t), 'zhang|');
      expect(sortKey(_p('2', null, 'John'), ContactSortBy.family, t), 'john|');
    });

    test('organizations key on their name, transcribed when Chinese', () {
      expect(
        sortKey(_org('o', 'Kaiser Clinic'), ContactSortBy.family, t),
        'kaiser clinic',
      );
      expect(
        sortKey(_org('o', '人民医院'), ContactSortBy.given, t),
        'ren min yi yuan',
      );
    });

    test('a nameless contact has an empty key', () {
      expect(sortKey(_p('1', null, '  '), ContactSortBy.family, t), '');
      expect(sortKey(_org('o', ''), ContactSortBy.family, t), '');
    });

    test('sort: a throwing transcriber falls back to raw text', () {
      final failing = FakePinyinTranscriber(throwOn: {'张'});
      final errors = <Object>[];
      expect(
        sortKey(
          _p('1', '张', '伟'),
          ContactSortBy.family,
          failing,
          onError: errors.add,
        ),
        '张|wei',
      );
      expect(errors.single, isA<StateError>());
    });

    test('a null transcriber sorts by raw text', () {
      expect(sortKey(_p('1', '张', '伟'), ContactSortBy.family, null), '张|伟');
    });

    test('sort: kana, hangul and emoji never reach the transcriber', () {
      expect(
        sortKey(_p('1', 'やまだ', 'たろう'), ContactSortBy.family, t),
        'やまだ|たろう',
      );
      expect(sortKey(_p('2', '김', '민준'), ContactSortBy.family, t), '김|민준');
      expect(sortKey(_p('3', '😀', 'Ann'), ContactSortBy.family, t), '😀|ann');
      expect(t.calls, 0);
    });
  });

  group('compareContactKeys', () {
    test('mixed scripts interleave; orgs sit among people; nameless last', () {
      final cs = [
        _p('nameless', null, null),
        _p('zw-zh', '张', '伟'),
        _p('zw-lat', 'Zhang', 'Wei'),
        _p('ll', '李', '丽'),
        _org('kaiser', 'Kaiser Clinic'),
        _p('al', 'Adams', 'Lee'),
        _p('lin', '林', '明'),
      ];
      expect(_sorted(cs, ContactSortBy.family, t), [
        'al', // adams|lee
        'kaiser', // kaiser clinic
        'll', // li|li
        'lin', // lin|ming (li before lin, part-wise)
        'zw-lat', // zhang|wei, display "Wei Zhang" < "张伟"
        'zw-zh',
        'nameless',
      ]);
    });

    test('given-name mode reorders', () {
      final cs = [_p('a', 'Adams', 'Zoe'), _p('b', 'Young', 'Amy')];
      expect(_sorted(cs, ContactSortBy.family, t), ['a', 'b']);
      expect(_sorted(cs, ContactSortBy.given, t), ['b', 'a']);
    });

    test('ties break by display name, then id', () {
      final cs = [_p('b', 'Lee', 'Ann'), _p('a', 'Lee', 'Ann')];
      expect(_sorted(cs, ContactSortBy.family, t), ['a', 'b']);
    });

    test('a | typed in a name cannot split the key', () {
      expect(
        sortKey(_p('1', 'A|B', 'C'), ContactSortBy.family, t),
        'a b|c',
      );
    });
  });

  group('searchTerms and matchesSearch', () {
    bool m(Contact c, String q, [FakePinyinTranscriber? tr]) =>
        matchesSearch(c, searchTerms(c, tr ?? t), q);

    test('张伟 matches by pinyin, initials, either order, and Chinese', () {
      final c = _p('1', '张', '伟');
      for (final q in [
        'zw',
        'ZW',
        'zhangwei',
        ' zhang  wei ',
        'weizhang',
        'wei zhang',
        'zhang',
        '张',
        '张伟',
      ]) {
        expect(m(c, q), isTrue, reason: q);
      }
      expect(m(c, 'li'), isFalse);
    });

    test('initials match as a prefix only', () {
      final c = _p('1', '张', '伟明');
      expect(m(c, 'zwm'), isTrue);
      expect(m(c, 'zw'), isTrue);
      expect(m(c, 'wm'), isFalse);
    });

    test('Latin names match in either order, with no initials term', () {
      final c = _p('1', 'Lovelace', 'Ada');
      expect(m(c, 'ada lovelace'), isTrue);
      expect(m(c, 'lovelace ada'), isTrue);
      expect(m(c, 'al'), isFalse);
    });

    test('accent folding applies to queries and terms', () {
      final c = _p('1', 'Zola', 'Émile');
      expect(m(c, 'emile'), isTrue);
      expect(m(c, 'ÉMILE'), isTrue);
    });

    test('search: Chinese only in the given part', () {
      final c = _p('1', 'Smith', '伟');
      expect(m(c, 'smithwei'), isTrue);
      expect(m(c, 'sw'), isTrue);
    });

    test('a phonetic field wins over automatic pinyin', () {
      final c = _p('1', '曾', '伟', phFamily: 'Tsang');
      expect(m(c, 'tsangwei'), isTrue);
      expect(m(c, 'tw'), isTrue);
      expect(m(c, 'zengwei'), isFalse);
    });

    test('a throwing transcriber omits pinyin terms only', () {
      final failing = FakePinyinTranscriber(throwOn: {'张', '伟'});
      final c = _p('1', '张', '伟');
      final errors = <Object>[];
      final terms = searchTerms(c, failing, onError: errors.add);
      expect(matchesSearch(c, terms, 'zhangwei'), isFalse);
      expect(matchesSearch(c, terms, '张伟'), isTrue);
      expect(errors, isNotEmpty);
    });

    test('Chinese organizations match by pinyin and initials', () {
      final c = _org('o', '人民医院');
      expect(m(c, 'renmin'), isTrue);
      expect(m(c, 'rmyy'), isTrue);
    });

    test('phones by digits and emails still match', () {
      const c = Contact(
        id: '1',
        contactType: ContactType.person,
        firstName: 'Ann',
        phones: [ContactPhone(label: 'mobile', number: '(604) 555-0100')],
        emails: [ContactEmail(label: 'work', address: 'Ann@Example.com')],
      );
      expect(m(c, '6045550100'), isTrue);
      expect(m(c, '555-01'), isTrue);
      expect(m(c, 'example.COM'), isTrue);
      expect(m(c, '777'), isFalse);
    });

    test('an empty query matches everything', () {
      expect(m(_p('1', null, null), '   '), isTrue);
    });
  });
}
```

- [ ] **Step 3: Run it and watch it fail**

Run: `flutter test test/features/contacts/domain/contact_sort_test.dart`
Expected: compile failure, `Target of URI doesn't exist: '.../contact_sort.dart'` and `'.../contact_sort_by.dart'`.

- [ ] **Step 4: Implement `contact_sort_by.dart`**

```dart
// lib/features/contacts/domain/contact_sort_by.dart

/// "Sort contacts by" (Settings). Stored by `name` in prefs and the synced
/// settings bundle. NEVER localize.
enum ContactSortBy {
  family,
  given;

  /// Absent, unknown or wrong-typed values read as [family] (the default).
  static ContactSortBy fromName(Object? name) =>
      name == ContactSortBy.given.name ? given : family;
}
```

- [ ] **Step 5: Implement `contact_sort.dart`**

```dart
// lib/features/contacts/domain/contact_sort.dart
import 'contact_name.dart';
import 'contact_sort_by.dart';
import 'entities/contact.dart';
import 'pinyin_transcriber.dart';

final _ws = RegExp(r'\s+');
final _apostrophes = RegExp("['’]");
final _phoneNoise = RegExp(r'[\s\-.()]');

const _fold = <String, String>{
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a', 'ǎ': 'a',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ě': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'ǐ': 'i',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ō': 'o', 'ǒ': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ǔ': 'u',
  'ǖ': 'u', 'ǘ': 'u', 'ǚ': 'u', 'ǜ': 'u',
  'ç': 'c', 'ñ': 'n', 'ý': 'y', 'ÿ': 'y',
  // The key separator; a typed `|` must not split a sort key.
  '|': ' ',
};

/// Lowercase, accent-folded, whitespace (U+3000 included) collapsed and
/// trimmed. Used for sort keys, search terms and queries alike.
String normalizeForSearch(String s) {
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final ch = String.fromCharCode(r);
    b.write(_fold[ch] ?? ch);
  }
  return b.toString().replaceAll(_ws, ' ').trim();
}

List<String> _words(String s) =>
    normalizeForSearch(s).split(' ').where((w) => w.isNotEmpty).toList();

/// The part's romanized syllables: the phonetic field when set, else the
/// transcriber's output when the part contains Chinese. Null when neither
/// applies or the transcriber threw (reported to [onError]).
List<String>? _syllables(
  String part,
  String? phonetic,
  bool family,
  PinyinTranscriber? t,
  void Function(Object error)? onError,
) {
  final ph = phonetic?.trim() ?? '';
  if (ph.isNotEmpty) return _words(ph.replaceAll(_apostrophes, ' '));
  if (t == null || !ContactName.hasChinese(part)) return null;
  try {
    return [
      for (final s in family ? t.family(part) : t.given(part)) ..._words(s),
    ];
  } catch (e) {
    onError?.call(e);
    return null;
  }
}

String _sortPart(
  String part,
  String? phonetic,
  bool family,
  PinyinTranscriber? t,
  void Function(Object error)? onError,
) =>
    _syllables(part, phonetic, family, t, onError)?.join(' ') ??
    normalizeForSearch(part);

/// `family|given` (or `given|family`) in sortable text; an organization's
/// normalized name; `''` for a contact with no name at all. A single
/// present part leads (`zhang|`), so a given-only contact does not sort
/// ahead of everyone under family-name sort.
String sortKey(
  Contact c,
  ContactSortBy by,
  PinyinTranscriber? t, {
  void Function(Object error)? onError,
}) {
  if (c.contactType == ContactType.organization) {
    final name = c.organizationName?.trim() ?? '';
    return name.isEmpty ? '' : _sortPart(name, null, false, t, onError);
  }
  final family = _sortPart(
    c.lastName?.trim() ?? '',
    c.phoneticFamily,
    true,
    t,
    onError,
  );
  final given = _sortPart(
    c.firstName?.trim() ?? '',
    c.phoneticGiven,
    false,
    t,
    onError,
  );
  final (primary, secondary) =
      by == ContactSortBy.family ? (family, given) : (given, family);
  if (primary.isEmpty) return secondary.isEmpty ? '' : '$secondary|';
  return '$primary|$secondary';
}

(String, String) _split(String key) {
  final i = key.indexOf('|');
  return i < 0 ? (key, '') : (key.substring(0, i), key.substring(i + 1));
}

/// Empty keys last; then primary part, secondary part (compared part-wise so
/// `li|` sorts before `lin|`), display name, id. Deterministic on every
/// device.
int compareContactKeys(Contact a, String keyA, Contact b, String keyB) {
  if (keyA.isEmpty != keyB.isEmpty) return keyA.isEmpty ? 1 : -1;
  final (pa, sa) = _split(keyA);
  final (pb, sb) = _split(keyB);
  var r = pa.compareTo(pb);
  if (r != 0) return r;
  r = sa.compareTo(sb);
  if (r != 0) return r;
  r = a.displayName.compareTo(b.displayName);
  if (r != 0) return r;
  return a.id.compareTo(b.id);
}

/// Normalized search terms for one contact. [contains] match anywhere;
/// [prefixes] (pinyin initials such as `zw`) match only from the start.
class ContactSearchTerms {
  const ContactSearchTerms({required this.contains, required this.prefixes});

  final List<String> contains;
  final List<String> prefixes;
}

ContactSearchTerms searchTerms(
  Contact c,
  PinyinTranscriber? t, {
  void Function(Object error)? onError,
}) {
  final contains = <String>{};
  final prefixes = <String>{};
  void add(String s) {
    final n = normalizeForSearch(s);
    if (n.isNotEmpty) contains.add(n);
  }

  void addRomanized(List<String> forward, List<String> backward) {
    if (forward.isEmpty) return;
    contains
      ..add(forward.join(' '))
      ..add(forward.join())
      ..add(backward.join(' '))
      ..add(backward.join());
    prefixes.add(forward.map((s) => s[0]).join());
  }

  add(c.displayName);
  if (c.contactType == ContactType.organization) {
    final org = c.organizationName?.trim() ?? '';
    final syl = _syllables(org, null, false, t, onError);
    if (syl != null) addRomanized(syl, syl);
  } else {
    final given = c.firstName?.trim() ?? '';
    final family = c.lastName?.trim() ?? '';
    add('$given $family');
    add('$family $given');
    final fs = _syllables(family, c.phoneticFamily, true, t, onError);
    final gs = _syllables(given, c.phoneticGiven, false, t, onError);
    if (fs != null || gs != null) {
      final f = fs ?? _words(family);
      final g = gs ?? _words(given);
      addRomanized([...f, ...g], [...g, ...f]);
    }
  }
  return ContactSearchTerms(
    contains: contains.toList(),
    prefixes: prefixes.toList(),
  );
}

/// True when [query] (normalized like the terms) is contained in a term, is
/// a prefix of the initials, or matches an email / phone (digits compared
/// with spaces, dashes, dots and parentheses ignored, as before).
bool matchesSearch(Contact c, ContactSearchTerms terms, String query) {
  final q = normalizeForSearch(query);
  if (q.isEmpty) return true;
  if (terms.contains.any((term) => term.contains(q))) return true;
  if (terms.prefixes.any((p) => p.startsWith(q))) return true;
  final lower = query.trim().toLowerCase();
  if (c.emails.any((e) => e.address.toLowerCase().contains(lower))) {
    return true;
  }
  final digits = lower.replaceAll(_phoneNoise, '');
  return c.phones.any(
    (p) =>
        p.number.toLowerCase().contains(lower) ||
        (digits.isNotEmpty &&
            p.number.replaceAll(_phoneNoise, '').contains(digits)),
  );
}
```

- [ ] **Step 6: Run it and watch it pass**

Run: `flutter test test/features/contacts/domain/contact_sort_test.dart`
Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add lib/features/contacts/domain/contact_sort_by.dart lib/features/contacts/domain/contact_sort.dart test/features/contacts/fake_pinyin_transcriber.dart test/features/contacts/domain/contact_sort_test.dart
git commit -m "feat(contacts): pinyin-aware sort keys and search terms

Family or given sort, accent folding, phonetic override, prefix-only
initials; a transcriber failure falls back to raw text.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Codec keys, raw preservation, and the stored `displayName`

**Files:**
- Modify: `lib/features/contacts/domain/entities/contact.dart`: add `storedDisplayName` to the constructor and fields, and replace `copyWith` with the equality-preserving version below.
- Modify: `lib/features/contacts/data/contact_codec.dart`: `_knownKeys` (lines 38–54), `toMap` (lines 86–99), `fromMap` (lines 228–299).
- Modify: `test/features/contacts/data/contact_codec_test.dart`: replace the test at lines 42–53 (`a stale stored displayName is ignored on read and rewritten`); add a new group.
- Test: `test/features/contacts/states/contact_edit_state_display_name_test.dart`

**Interfaces:**
- Consumes: `ContactNameOrder`, the `Contact` name fields (Task 2).
- Produces:
  ```dart
  // Contact gains:
  final Object? storedDisplayName;   // the stored JSON `displayName`, verbatim; kept by copyWith only while the copy == the original
  // ContactCodec known keys add: 'nameOrder', 'phoneticFamily', 'phoneticGiven'
  ```
  Codec write order: `…, organizationName, nameOrder, phoneticFamily, phoneticGiven, phones, …`. A contact without the new values writes exactly the old key set.

- [ ] **Step 1: Write the failing tests**

In `test/features/contacts/data/contact_codec_test.dart`, replace this test:

```dart
  test('a stale stored displayName is ignored on read and rewritten', () {
    final decoded = ContactCodec.fromMap({
      'id': 'c-8',
      'contactType': 'person',
      'firstName': 'New',
      'lastName': 'Name',
      'displayName': 'Old Name',
    });
    expect(decoded.firstName, 'New');
    expect(decoded.extraFields.containsKey('displayName'), isFalse);
    expect(ContactCodec.toMap(decoded)['displayName'], 'New Name');
  });
```

with:

```dart
  test('a stale stored displayName survives an untouched save only', () {
    final decoded = ContactCodec.fromMap({
      'id': 'c-8',
      'contactType': 'person',
      'firstName': 'New',
      'lastName': 'Name',
      'displayName': 'Old Name',
    });
    expect(decoded.firstName, 'New');
    expect(decoded.extraFields.containsKey('displayName'), isFalse);
    // Untouched: the stored bytes are kept (spec: no bulk rewrite).
    expect(ContactCodec.toMap(decoded)['displayName'], 'Old Name');
    // A no-op copy is still untouched.
    expect(
      ContactCodec.toMap(decoded.copyWith(firstName: 'New'))['displayName'],
      'Old Name',
    );
    // Any edit re-derives it.
    expect(
      ContactCodec.toMap(decoded.copyWith(notes: 'x'))['displayName'],
      'New Name',
    );
  });
```

At the end of `main()` in the same file, add:

```dart
  group('name order and phonetics', () {
    const legacyZh =
        '{"schemaVersion":1,"displayName":"伟 张","id":"c-zh",'
        '"contactType":"person","firstName":"伟","lastName":"张",'
        '"phones":[],"emails":[],"addresses":[],'
        '"relationship":{"category":"family"},"isSelf":false,'
        '"isActivated":true}';

    String roundTrip(String json) => jsonEncode(
      ContactCodec.toMap(
        ContactCodec.fromMap(jsonDecode(json) as Map<String, dynamic>),
      ),
    );

    test('an untouched legacy Chinese contact is byte-identical', () {
      expect(roundTrip(legacyZh), legacyZh);
    });

    test('an edited legacy contact gets the ordered displayName', () {
      final decoded = ContactCodec.fromMap(
        jsonDecode(legacyZh) as Map<String, dynamic>,
      );
      expect(decoded.displayName, '张伟');
      final edited = ContactCodec.toMap(decoded.copyWith(notes: 'n'));
      expect(edited['displayName'], '张伟');
      expect(edited.containsKey('nameOrder'), isFalse);
    });

    test('new keys are written only when non-default', () {
      const plain = Contact(
        id: 'p',
        contactType: ContactType.person,
        firstName: 'Wei',
        lastName: 'Zhang',
      );
      final m = ContactCodec.toMap(plain);
      expect(m.containsKey('nameOrder'), isFalse);
      expect(m.containsKey('phoneticFamily'), isFalse);
      expect(m.containsKey('phoneticGiven'), isFalse);

      final set = ContactCodec.toMap(
        plain.copyWith(
          nameOrder: ContactNameOrder.familyFirst,
          phoneticFamily: 'Zhāng',
          phoneticGiven: 'Wei',
        ),
      );
      expect(set['nameOrder'], 'familyFirst');
      expect(set['phoneticFamily'], 'Zhāng');
      expect(set['phoneticGiven'], 'Wei');
      expect(set['displayName'], 'Zhang Wei');
      final back = ContactCodec.fromMap(set);
      expect(back.nameOrder, ContactNameOrder.familyFirst);
      expect(back.phoneticFamily, 'Zhāng');
      expect(jsonEncode(ContactCodec.toMap(back)), jsonEncode(set));
    });

    test('an unknown nameOrder reads as auto and is preserved', () {
      for (final raw in <Object>['surnameLast', 'auto', 3]) {
        final decoded = ContactCodec.fromMap({
          'id': 'u',
          'contactType': 'person',
          'firstName': 'Wei',
          'lastName': 'Zhang',
          'nameOrder': raw,
        });
        expect(decoded.nameOrder, ContactNameOrder.auto, reason: '$raw');
        expect(decoded.rawKnownValues['nameOrder'], raw);
        expect(decoded.extraFields.containsKey('nameOrder'), isFalse);
        expect(ContactCodec.toMap(decoded)['nameOrder'], raw);
        // Still preserved after an unrelated edit...
        expect(
          ContactCodec.toMap(decoded.copyWith(notes: 'x'))['nameOrder'],
          raw,
        );
        // ...and replaced once the user picks an order.
        expect(
          ContactCodec.toMap(
            decoded.copyWith(nameOrder: ContactNameOrder.givenFirst),
          )['nameOrder'],
          'givenFirst',
        );
      }
    });

    test('a wrong-typed phonetic is kept verbatim until edited', () {
      final decoded = ContactCodec.fromMap({
        'id': 'w',
        'contactType': 'person',
        'firstName': '伟',
        'phoneticGiven': 7,
      });
      expect(decoded.phoneticGiven, isNull);
      expect(ContactCodec.toMap(decoded)['phoneticGiven'], 7);
      expect(
        ContactCodec.toMap(decoded.copyWith(phoneticGiven: 'Wei'))[
            'phoneticGiven'],
        'Wei',
      );
    });

    test('a stored nameOrder round-trips byte-identical', () {
      const stored =
          '{"schemaVersion":1,"displayName":"Zhang Wei","id":"k",'
          '"contactType":"person","firstName":"Wei","lastName":"Zhang",'
          '"nameOrder":"familyFirst","phoneticFamily":"Zhang",'
          '"phones":[],"emails":[],"addresses":[],'
          '"relationship":{"category":"other"},"isSelf":false,'
          '"isActivated":true}';
      expect(roundTrip(stored), stored);
    });
  });
```

Create the edit-state test:

```dart
// test/features/contacts/states/contact_edit_state_display_name_test.dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/contacts/data/contact_codec.dart';
import 'package:hmm_console/features/contacts/states/contact_edit_state.dart';

import '../data/contact_repository_fakes.dart';

const _legacyZh =
    '{"schemaVersion":1,"displayName":"伟 张","id":"c-zh",'
    '"contactType":"person","firstName":"伟","lastName":"张",'
    '"phones":[],"emails":[],"addresses":[],'
    '"relationship":{"category":"family"},"isSelf":false,'
    '"isActivated":true}';

void main() {
  test('opening and saving without edits keeps the stored bytes', () async {
    final initial = ContactCodec.fromMap(
      jsonDecode(_legacyZh) as Map<String, dynamic>,
    );
    final repo = InMemoryContactRepository()..seed(initial);
    final c = ProviderContainer(
      overrides: [contactRepositoryModeProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    final sub = c.listen(contactEditStateProvider(initial), (_, _) {});
    addTearDown(sub.close);

    expect(
      await c.read(contactEditStateProvider(initial).notifier).save(),
      isTrue,
    );
    final saved = (await repo.getContact('c-zh'))!;
    expect(jsonEncode(ContactCodec.toMap(saved)), _legacyZh);
  });

  test('saving after an edit writes the ordered displayName', () async {
    final initial = ContactCodec.fromMap(
      jsonDecode(_legacyZh) as Map<String, dynamic>,
    );
    final repo = InMemoryContactRepository()..seed(initial);
    final c = ProviderContainer(
      overrides: [contactRepositoryModeProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    final sub = c.listen(contactEditStateProvider(initial), (_, _) {});
    addTearDown(sub.close);

    final n = c.read(contactEditStateProvider(initial).notifier);
    n.setNotes('met at school');
    expect(await n.save(), isTrue);
    final saved = (await repo.getContact('c-zh'))!;
    expect(ContactCodec.toMap(saved)['displayName'], '张伟');
  });
}
```

- [ ] **Step 2: Run them and watch them fail**

Run: `flutter test test/features/contacts/data/contact_codec_test.dart test/features/contacts/states/contact_edit_state_display_name_test.dart`
Expected: failures. `a stale stored displayName survives an untouched save only` gets `'New Name'` where it expects `'Old Name'`. The byte-identical tests get `"displayName":"张伟"`. The `nameOrder` tests find the key missing, or find it in `extraFields`.

- [ ] **Step 3: Add `storedDisplayName` to `Contact`**

In `lib/features/contacts/domain/entities/contact.dart`, add to the constructor parameter list, right after `this.unreadableEntries = const {},`:

```dart
    this.storedDisplayName,
```

Add this field after `final Map<String, List<dynamic>> unreadableEntries;`:

```dart
  /// The `displayName` exactly as stored (any JSON type), or null for a
  /// contact never decoded. `ContactCodec.toMap` writes it back instead of
  /// the derived name while the contact is unchanged since decode, so an
  /// untouched save is byte-identical. [copyWith] drops it on any change.
  final Object? storedDisplayName;
```

Replace the whole `copyWith` method with:

```dart
  /// [storedDisplayName] survives only a copy equal to this one (a no-op
  /// edit, `copyWith(id: sameId)` in the repository, a normalized but
  /// unchanged form). Any real change re-derives the name on save.
  Contact copyWith({
    String? id,
    ContactType? contactType,
    Object? firstName = _kSentinel,
    Object? lastName = _kSentinel,
    Object? organizationName = _kSentinel,
    ContactNameOrder? nameOrder,
    Object? phoneticFamily = _kSentinel,
    Object? phoneticGiven = _kSentinel,
    List<ContactPhone>? phones,
    List<ContactEmail>? emails,
    List<ContactAddress>? addresses,
    ContactRelationship? relationship,
    bool? isSelf,
    Object? notes = _kSentinel,
    bool? isActivated,
    Map<String, dynamic>? extraFields,
  }) {
    final next = Contact(
      id: id ?? this.id,
      contactType: contactType ?? this.contactType,
      firstName:
          identical(firstName, _kSentinel) ? this.firstName : firstName as String?,
      lastName: identical(lastName, _kSentinel) ? this.lastName : lastName as String?,
      organizationName: identical(organizationName, _kSentinel)
          ? this.organizationName
          : organizationName as String?,
      nameOrder: nameOrder ?? this.nameOrder,
      phoneticFamily: identical(phoneticFamily, _kSentinel)
          ? this.phoneticFamily
          : phoneticFamily as String?,
      phoneticGiven: identical(phoneticGiven, _kSentinel)
          ? this.phoneticGiven
          : phoneticGiven as String?,
      phones: phones ?? this.phones,
      emails: emails ?? this.emails,
      addresses: addresses ?? this.addresses,
      relationship: relationship ?? this.relationship,
      isSelf: isSelf ?? this.isSelf,
      notes: identical(notes, _kSentinel) ? this.notes : notes as String?,
      isActivated: isActivated ?? this.isActivated,
      extraFields: extraFields ?? this.extraFields,
      storedSchemaVersion: storedSchemaVersion,
      rawKnownValues: rawKnownValues,
      unreadableEntries: unreadableEntries,
      rawContactType: contactType != null ? null : _rawContactType,
    );
    if (storedDisplayName == null || next != this) return next;
    return Contact(
      id: next.id,
      contactType: next.contactType,
      firstName: next.firstName,
      lastName: next.lastName,
      organizationName: next.organizationName,
      nameOrder: next.nameOrder,
      phoneticFamily: next.phoneticFamily,
      phoneticGiven: next.phoneticGiven,
      phones: next.phones,
      emails: next.emails,
      addresses: next.addresses,
      relationship: next.relationship,
      isSelf: next.isSelf,
      notes: next.notes,
      isActivated: next.isActivated,
      extraFields: next.extraFields,
      storedSchemaVersion: next.storedSchemaVersion,
      rawKnownValues: next.rawKnownValues,
      unreadableEntries: next.unreadableEntries,
      storedDisplayName: storedDisplayName,
      rawContactType: next._rawContactType,
    );
  }
```

(`==` and `hashCode` deliberately leave out `storedDisplayName`: it is a persistence detail, not contact data.)

- [ ] **Step 4: Update the codec**

In `lib/features/contacts/data/contact_codec.dart`, replace `_knownKeys` with:

```dart
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
```

In `toMap`, replace:

```dart
      // Derived so a cheatsheet can bind `Contact.displayName`; ignored on read.
      'displayName': c.displayName,
```

with:

```dart
      // Stored bytes while untouched (no bulk rewrite); else derived in the
      // contact's name order. A cheatsheet resolves the order at read time.
      'displayName': c.storedDisplayName ?? c.displayName,
```

and replace:

```dart
    _putOptional(out, raw, 'organizationName', c.organizationName);
```

with:

```dart
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
```

In `fromMap`, replace:

```dart
    final storedContactType = r.str('contactType');
    final id = r.str('id') ?? '';
    final rawCategory = rel.str('category');
```

with:

```dart
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
```

and in the `Contact(` constructor call, replace:

```dart
      organizationName: r.str('organizationName'),
```

with:

```dart
      organizationName: r.str('organizationName'),
      nameOrder: nameOrder,
      phoneticFamily: r.str('phoneticFamily'),
      phoneticGiven: r.str('phoneticGiven'),
```

and replace:

```dart
      rawContactType: storedContactType,
    );
```

with:

```dart
      storedDisplayName: m['displayName'],
      rawContactType: storedContactType,
    );
```

- [ ] **Step 5: Run the tests and watch them pass**

Run: `flutter test test/features/contacts/data/contact_codec_test.dart test/features/contacts/states/contact_edit_state_display_name_test.dart test/features/contacts/`
Expected: all pass, including the existing repository and binding tests.

- [ ] **Step 6: Commit**

```bash
git add lib/features/contacts/domain/entities/contact.dart lib/features/contacts/data/contact_codec.dart test/features/contacts/data/contact_codec_test.dart test/features/contacts/states/contact_edit_state_display_name_test.dart
git commit -m "feat(contacts): persist name order and phonetics losslessly

New keys only when non-default; unknown nameOrder preserved raw; an
untouched contact keeps its stored displayName byte-identical, an edited
one derives it in its name order.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: "Sort contacts by" setting (synced)

**Files:**
- Modify: `lib/features/settings/domain/syncable_settings.dart`: field, constructor, `toJson` (line 61), `fromJson` (line 72), `copyWith` (line 114).
- Modify: `lib/features/settings/data/syncable_settings_repository.dart`: key const (line 33), `read` (lines 82–88), `apply` (line 110).
- Create: `lib/features/settings/providers/contact_sort_provider.dart`
- Modify: `lib/features/settings/presentation/screens/settings_screen.dart`: imports (lines 28–32), plus a row after the language dropdown (after line 306).
- Modify: `lib/core/help/help_registry.dart`: the `HelpId.contacts` entries (after line 76).
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`, regenerated `lib/l10n/gen/*`.
- Test: `test/features/settings/data/contact_sort_setting_test.dart`, `test/features/settings/contact_sort_settings_row_test.dart`, `test/core/help/help_registry_test.dart` (append).

**Interfaces:**
- Consumes: `ContactSortBy` (Task 4).
- Produces:
  ```dart
  // SyncableSettings gains: final ContactSortBy contactSortBy;  (default family; JSON key 'contactSortBy', written only when given)
  // SyncableSettingsRepository: static const contactSortKey = 'contacts.sort_by';
  class ContactSortByNotifier extends Notifier<ContactSortBy> { Future<void> set(ContactSortBy v); }
  final contactSortByProvider = NotifierProvider<ContactSortByNotifier, ContactSortBy>(ContactSortByNotifier.new);
  ```

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/settings/data/contact_sort_setting_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/contacts/domain/contact_sort_by.dart';
import 'package:hmm_console/features/settings/data/syncable_settings_repository.dart';
import 'package:hmm_console/features/settings/domain/syncable_settings.dart';
import 'package:hmm_console/features/settings/providers/contact_sort_provider.dart';
import 'package:hmm_console/features/settings/providers/settings_bus_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SyncableSettings.contactSortBy', () {
    test('an old bundle without the key reads as family', () {
      final s = SyncableSettings.fromJson({'_v': 1});
      expect(s.contactSortBy, ContactSortBy.family);
    });

    test('given round-trips; family is not written', () {
      final given = SyncableSettings.defaults().copyWith(
        contactSortBy: ContactSortBy.given,
      );
      expect(given.toJson()['contactSortBy'], 'given');
      expect(
        SyncableSettings.fromJsonString(given.toJsonString()).contactSortBy,
        ContactSortBy.given,
      );
      expect(
        SyncableSettings.defaults().toJson().containsKey('contactSortBy'),
        isFalse,
      );
    });

    test('an unknown value reads as family', () {
      expect(
        SyncableSettings.fromJson({'contactSortBy': 'middle'}).contactSortBy,
        ContactSortBy.family,
      );
    });
  });

  group('SyncableSettingsRepository', () {
    test('reads and applies contacts.sort_by', () async {
      final repo = SyncableSettingsRepository();
      expect((await repo.read()).contactSortBy, ContactSortBy.family);
      await repo.apply(
        (await repo.read()).copyWith(contactSortBy: ContactSortBy.given),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('contacts.sort_by'), 'given');
      expect((await repo.read()).contactSortBy, ContactSortBy.given);
    });
  });

  group('contactSortByProvider', () {
    test('defaults to family, loads, sets and bumps the stamp', () async {
      SharedPreferences.setMockInitialValues({'contacts.sort_by': 'given'});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final sub = c.listen(contactSortByProvider, (_, _) {});
      addTearDown(sub.close);
      expect(c.read(contactSortByProvider), ContactSortBy.family);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(contactSortByProvider), ContactSortBy.given);

      await c.read(contactSortByProvider.notifier).set(ContactSortBy.family);
      expect(c.read(contactSortByProvider), ContactSortBy.family);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('contacts.sort_by'), 'family');
      expect(prefs.getString('settings.last_modified'), isNotNull);
    });

    test('a remote pull (settings bus) re-reads the value', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final sub = c.listen(contactSortByProvider, (_, _) {});
      addTearDown(sub.close);
      await Future<void>.delayed(Duration.zero);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('contacts.sort_by', 'given');
      c.read(settingsBusProvider.notifier).bump();
      c.read(contactSortByProvider);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(contactSortByProvider), ContactSortBy.given);
    });
  });
}
```

```dart
// test/features/settings/contact_sort_settings_row_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/features/contacts/domain/contact_sort_by.dart';
import 'package:hmm_console/features/settings/presentation/screens/settings_screen.dart';
import 'package:hmm_console/features/settings/providers/contact_sort_provider.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Same harness as quick_panel_settings_row_test.dart: databasePathProvider
/// is overridden because path_provider hangs in a widget test.
Future<ProviderContainer> _pump(WidgetTester t) async {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(overrides: [
    databasePathProvider.overrideWith((ref) async => '/tmp/hmm-test.db'),
  ]);
  addTearDown(container.dispose);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SettingsScreen(),
      ),
    ),
  );
  await t.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('Sort contacts by defaults to Family name and switches',
      (t) async {
    final container = await _pump(t);
    final row = find.byKey(const Key('settings-contact-sort'));
    expect(row, findsOneWidget);
    expect(find.text('Sort contacts by'), findsOneWidget);
    expect(find.text('Family name'), findsOneWidget);

    await t.ensureVisible(row);
    await t.tap(row);
    await t.pumpAndSettle();
    await t.tap(find.text('Given name').last);
    await t.pumpAndSettle();

    expect(container.read(contactSortByProvider), ContactSortBy.given);
  });
}
```

Append inside `main()` of `test/core/help/help_registry_test.dart`:

```dart
  test('contacts help explains the sort setting with its icon', () {
    final l = lookupAppLocalizations(const Locale('en'));
    final entry = helpFor(HelpId.contacts, l)
        .entries
        .singleWhere((e) => e.icon == Icons.sort_by_alpha);
    expect(entry.title, l.helpContactsSortTitle);
    expect(entry.body, contains('Settings'));
  });
```

- [ ] **Step 2: Run them and watch them fail**

Run: `flutter test test/features/settings/data/contact_sort_setting_test.dart test/features/settings/contact_sort_settings_row_test.dart test/core/help/help_registry_test.dart`
Expected: compile failures: `contact_sort_provider.dart` doesn't exist, `The named parameter 'contactSortBy' isn't defined`, and `The getter 'helpContactsSortTitle' isn't defined`.

- [ ] **Step 3: Extend `SyncableSettings`**

In `lib/features/settings/domain/syncable_settings.dart`, add the import `import '../../contacts/domain/contact_sort_by.dart';` after the launcher import. Then:

Constructor: add `this.contactSortBy = ContactSortBy.family,` after `this.launcher = LauncherPrefs.empty,`.

Field, after `final LauncherPrefs launcher;`:

```dart
  /// Contacts list order (Settings → Sort contacts by). Absent in older
  /// bundles, which read as [ContactSortBy.family].
  final ContactSortBy contactSortBy;
```

In `toJson`, after `'launcher': launcher.toJson(),` add:

```dart
        if (contactSortBy != ContactSortBy.family)
          'contactSortBy': contactSortBy.name,
```

In `fromJson`, after the `launcher: () { ... }(),` argument add:

```dart
      contactSortBy: ContactSortBy.fromName(json['contactSortBy']),
```

In `copyWith`, add the parameter `ContactSortBy? contactSortBy,` after `LauncherPrefs? launcher,`, and the argument `contactSortBy: contactSortBy ?? this.contactSortBy,` after `launcher: launcher ?? this.launcher,`.

- [ ] **Step 4: Extend `SyncableSettingsRepository`**

Add the import `import '../../contacts/domain/contact_sort_by.dart';`. Add to the doc list: `///   - \`contacts.sort_by\`     → \`ContactSortBy\` enum name`. After `static const _launcherKey = 'launcher_prefs';` add:

```dart
  /// Public: `ContactSortByNotifier` owns the same key.
  static const contactSortKey = 'contacts.sort_by';
```

In `read()`, change the `return SyncableSettings(` call to end with:

```dart
      launcher: launcher,
      contactSortBy: ContactSortBy.fromName(prefs.getString(contactSortKey)),
    );
```

In `apply()`, after `await prefs.setString(_launcherKey, settings.launcher.toJsonString());` add:

```dart
    await prefs.setString(contactSortKey, settings.contactSortBy.name);
```

- [ ] **Step 5: Create the provider**

```dart
// lib/features/settings/providers/contact_sort_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../contacts/domain/contact_sort_by.dart';
import '../data/syncable_settings_repository.dart';
import 'settings_bus_provider.dart';

/// "Sort contacts by". Same shape as `SyncSettingsNotifier`: a synchronous
/// default, then hydrated from prefs; re-read when a pulled settings bundle
/// bumps the bus.
class ContactSortByNotifier extends Notifier<ContactSortBy> {
  @override
  ContactSortBy build() {
    ref.watch(settingsBusProvider);
    _load();
    return ContactSortBy.family;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!ref.mounted) return;
      state = ContactSortBy.fromName(
        prefs.getString(SyncableSettingsRepository.contactSortKey),
      );
    } catch (e) {
      // Type only. The list keeps sorting by family name.
      debugPrint('ContactSortBy: setting unreadable (${e.runtimeType})');
    }
  }

  Future<void> set(ContactSortBy value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SyncableSettingsRepository.contactSortKey, value.name);
    await ref.read(syncableSettingsRepositoryProvider).bumpLastModified();
  }
}

final contactSortByProvider =
    NotifierProvider<ContactSortByNotifier, ContactSortBy>(
  ContactSortByNotifier.new,
);
```

- [ ] **Step 6: Add the ARB strings**

In `lib/l10n/app_en.arb`, replace:

```
  "contactSaveFailed": "Could not save the contact"
}
```

with:

```
  "contactSaveFailed": "Could not save the contact",
  "settingsContactSortBy": "Sort contacts by",
  "settingsContactSortFamily": "Family name",
  "settingsContactSortGiven": "Given name",
  "helpContactsSortTitle": "Sort order",
  "helpContactsSortBody": "Contacts are sorted by family name. To sort by given name instead, change Sort contacts by in Settings. Chinese names sort by their pinyin, next to Latin names."
}
```

In `lib/l10n/app_zh.arb`, replace:

```
  "contactSaveFailed": "无法保存联系人"
}
```

with:

```
  "contactSaveFailed": "无法保存联系人",
  "settingsContactSortBy": "联系人排序方式",
  "settingsContactSortFamily": "姓氏",
  "settingsContactSortGiven": "名字",
  "helpContactsSortTitle": "排序",
  "helpContactsSortBody": "联系人默认按姓氏排序。如需按名字排序，请在“设置”中更改“联系人排序方式”。中文姓名按拼音排序，与拉丁字母姓名排在一起。"
}
```

Run: `flutter gen-l10n`

- [ ] **Step 7: Add the Settings row**

In `settings_screen.dart`, add these imports after `import '../../providers/sync_settings_provider.dart';`:

```dart
import '../../../contacts/domain/contact_sort_by.dart';
import '../../providers/contact_sort_provider.dart';
```

Replace:

```dart
              onChanged: (code) {
                ref.read(localeProvider.notifier).setLocale(
                      code == null ? null : Locale(code),
                    );
              },
            ),
```

with:

```dart
              onChanged: (code) {
                ref.read(localeProvider.notifier).setLocale(
                      code == null ? null : Locale(code),
                    );
              },
            ),
            GapWidgets.h16,
            // Same picker as the rest of this screen (Material dropdown on
            // both platforms). Synced via SyncableSettings.contactSortBy.
            DropdownButtonFormField<ContactSortBy>(
              key: const Key('settings-contact-sort'),
              initialValue: ref.watch(contactSortByProvider),
              decoration: InputDecoration(
                labelText: l.settingsContactSortBy,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.sort_by_alpha),
              ),
              items: [
                DropdownMenuItem(
                  value: ContactSortBy.family,
                  child: Text(l.settingsContactSortFamily),
                ),
                DropdownMenuItem(
                  value: ContactSortBy.given,
                  child: Text(l.settingsContactSortGiven),
                ),
              ],
              onChanged: (v) {
                if (v != null) ref.read(contactSortByProvider.notifier).set(v);
              },
            ),
```

- [ ] **Step 8: Add the help entry**

In `lib/core/help/help_registry.dart`, inside `HelpId.contacts => ScreenHelp(... entries: [`, after the `Icons.search` entry, add:

```dart
            HelpEntry(
                icon: Icons.sort_by_alpha,
                title: l.helpContactsSortTitle,
                body: l.helpContactsSortBody),
```

- [ ] **Step 9: Run them and watch them pass**

Run: `flutter test test/features/settings/ test/core/help/`
Expected: all pass, including the existing `syncable_settings_repository_test.dart` and `quick_panel_settings_row_test.dart`.

- [ ] **Step 10: Commit**

```bash
git add lib/features/settings/domain/syncable_settings.dart lib/features/settings/data/syncable_settings_repository.dart lib/features/settings/providers/contact_sort_provider.dart lib/features/settings/presentation/screens/settings_screen.dart lib/core/help/help_registry.dart lib/l10n/app_en.arb lib/l10n/app_zh.arb lib/l10n/gen/ test/features/settings/data/contact_sort_setting_test.dart test/features/settings/contact_sort_settings_row_test.dart test/core/help/help_registry_test.dart
git commit -m "feat(settings): sort contacts by family or given name

Synced in the settings bundle; old bundles read as family name.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: List provider with precomputed keys; list screen and repository sort and search through it

**Files:**
- Create: `lib/features/contacts/states/contact_list_entries.dart`
- Modify: `lib/features/contacts/presentation/screens/contacts_list_screen.dart`: delete `_phoneNoise` and `_matches` (lines 15–29); `build` (line 61, line 96); `_body` (lines 128–177).
- Modify: `lib/core/data/local/local_contact_repository.dart`: `getContacts` sort (lines 139–140), plus imports.
- Modify: `lib/l10n/app_en.arb` / `app_zh.arb`: `helpContactsSearchBody` text; regenerate `lib/l10n/gen/`.
- Test: `test/features/contacts/states/contact_list_entries_test.dart`. Modify `test/features/contacts/presentation/contacts_list_screen_test.dart` (setUp + new tests) and `test/features/contacts/data/local_contact_repository_test.dart` (one new test).

**Interfaces:**
- Consumes: `sortKey`, `searchTerms`, `matchesSearch`, `compareContactKeys` (Task 4); `pinyinTranscriberProvider` (Task 3); `contactSortByProvider` (Task 6); `contactsStateProvider` (existing).
- Produces:
  ```dart
  class ContactListEntry { final Contact contact; final String sortKey; final ContactSearchTerms terms; }
  List<ContactListEntry> buildContactListEntries(List<Contact> contacts, ContactSortBy by, PinyinTranscriber? t);
  final contactListEntriesProvider = Provider<AsyncValue<List<ContactListEntry>>>(...);
  ```

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/contacts/states/contact_list_entries_test.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/contacts/domain/contact_sort_by.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';
import 'package:hmm_console/features/contacts/states/contact_list_entries.dart';
import 'package:hmm_console/features/contacts/states/pinyin_transcriber_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/contact_repository_fakes.dart';
import '../fake_pinyin_transcriber.dart';

Contact _p(String id, String? family, String? given, {bool self = false}) =>
    Contact(
      id: id,
      contactType: ContactType.person,
      lastName: family,
      firstName: given,
      isSelf: self,
    );

List<String> _ids(List<ContactListEntry> es) =>
    [for (final e in es) e.contact.id];

void main() {
  test('Me first, then sort key; organizations interleave', () {
    final entries = buildContactListEntries(
      [
        _p('zw', '张', '伟'),
        _p('me', 'Young', 'Zed', self: true),
        const Contact(
          id: 'org',
          contactType: ContactType.organization,
          organizationName: 'Kaiser Clinic',
        ),
        _p('al', 'Adams', 'Lee'),
        _p('nameless', null, null),
      ],
      ContactSortBy.family,
      FakePinyinTranscriber(),
    );
    expect(_ids(entries), ['me', 'al', 'org', 'zw', 'nameless']);
  });

  test('given-name sort reorders', () {
    final entries = buildContactListEntries(
      [_p('a', 'Adams', 'Zoe'), _p('b', 'Young', 'Amy')],
      ContactSortBy.given,
      FakePinyinTranscriber(),
    );
    expect(_ids(entries), ['b', 'a']);
  });

  test('one transcriber failure leaves the rest sorted and logs the type once',
      () {
    final logs = <String>[];
    final old = debugPrint;
    debugPrint = (m, {wrapWidth}) => logs.add(m ?? '');
    addTearDown(() => debugPrint = old);

    final entries = buildContactListEntries(
      [
        _p('zw', '张', '伟'),
        _p('lin', '林', '明'),
        _p('broken', '王', '娜'),
        _p('ll', '李', '丽'),
      ],
      ContactSortBy.family,
      FakePinyinTranscriber(throwOn: {'王', '娜'}),
    );
    // Pinyin order for the healthy three; the broken one sorts by raw
    // text (U+738B), after every Latin key.
    expect(_ids(entries), ['ll', 'lin', 'zw', 'broken']);
    final pinyinLogs = logs.where((l) => l.contains('pinyin')).toList();
    expect(pinyinLogs, hasLength(1));
    expect(pinyinLogs.single, contains('StateError'));
    expect(pinyinLogs.single, isNot(contains('王')));
    expect(pinyinLogs.single, isNot(contains('dictionary unavailable')));
  });

  test('a null transcriber still builds a sorted list', () {
    final entries = buildContactListEntries(
      [_p('b', 'B', 'x'), _p('a', 'A', 'x')],
      ContactSortBy.family,
      null,
    );
    expect(_ids(entries), ['a', 'b']);
  });

  test('the provider combines contacts, the setting and the transcriber',
      () async {
    SharedPreferences.setMockInitialValues({});
    final repo = InMemoryContactRepository()
      ..seed(_p('zw', '张', '伟'))
      ..seed(_p('al', 'Adams', 'Lee'));
    final c = ProviderContainer(
      overrides: [
        contactRepositoryModeProvider.overrideWithValue(repo),
        pinyinTranscriberProvider.overrideWithValue(FakePinyinTranscriber()),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(contactListEntriesProvider, (_, _) {});
    addTearDown(sub.close);
    await c.read(contactsStateProvider.future);
    final value = c.read(contactListEntriesProvider).value!;
    expect(_ids(value), ['al', 'zw']);
    expect(value.last.sortKey, 'zhang|wei');
  });
}
```

Add this import at the top of `contact_list_entries_test.dart` (for `contactsStateProvider`):

```dart
import 'package:hmm_console/features/contacts/states/contacts_state.dart';
```

In `test/features/contacts/presentation/contacts_list_screen_test.dart`, add these imports:

```dart
import 'package:hmm_console/features/contacts/domain/contact_sort_by.dart';
import 'package:hmm_console/features/contacts/states/pinyin_transcriber_provider.dart';
import 'package:hmm_console/features/settings/providers/contact_sort_provider.dart';

import '../fake_pinyin_transcriber.dart';
```

Add this helper after `_repo`:

```dart
List<String> _titles(WidgetTester tester) => [
  for (final t in tester.widgetList<ListTile>(find.byType(ListTile)))
    (t.title! as Text).data!,
];
```

As the first statement inside `void main() {`, add:

```dart
  setUp(() => SharedPreferences.setMockInitialValues({}));
```

Append inside `main()`:

```dart
  testWidgets('search finds 张伟 by zw and zhangwei', (tester) async {
    const zw = Contact(
      id: 'zw',
      contactType: ContactType.person,
      lastName: '张',
      firstName: '伟',
    );
    await _mount(tester, [
      ..._repo(InMemoryContactRepository()..seed(zw)..seed(_ada)),
      pinyinTranscriberProvider.overrideWithValue(FakePinyinTranscriber()),
    ]);
    expect(find.text('张伟'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zw');
    await tester.pump();
    expect(find.text('张伟'), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zhangwei');
    await tester.pump();
    expect(find.text('张伟'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'wz');
    await tester.pump();
    expect(find.text('张伟'), findsNothing);
  });

  testWidgets('Chinese and Latin names interleave by family name; the '
      'sort setting reorders', (tester) async {
    await _mount(tester, [
      ..._repo(
        InMemoryContactRepository()
          ..seed(const Contact(
            id: 'zw',
            contactType: ContactType.person,
            lastName: '张',
            firstName: '伟',
          ))
          ..seed(const Contact(
            id: 'kc',
            contactType: ContactType.organization,
            organizationName: 'Kaiser Clinic',
          ))
          ..seed(_ada) // Lovelace, Ada
          ..seed(_bob), // Stone, Bob
      ),
      pinyinTranscriberProvider.overrideWithValue(FakePinyinTranscriber()),
    ]);
    expect(_titles(tester),
        ['Kaiser Clinic', 'Ada Lovelace', 'Bob Stone', '张伟']);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ContactsListScreen)),
    );
    await container
        .read(contactSortByProvider.notifier)
        .set(ContactSortBy.given);
    await tester.pumpAndSettle();
    // given|family: ada, bob, kaiser clinic, wei|zhang
    expect(_titles(tester),
        ['Ada Lovelace', 'Bob Stone', 'Kaiser Clinic', '张伟']);
  });

  testWidgets('Me stays first in its group whatever its name', (tester) async {
    await _mount(tester, [
      ..._repo(
        InMemoryContactRepository()
          // Both default to the Other group; "Zulu" would sort last.
          ..seed(_ada.copyWith(isSelf: true, lastName: 'Zulu'))
          ..seed(_bob),
      ),
    ]);
    expect(_titles(tester), ['Ada Zulu', 'Bob Stone']);
  });
```

In `test/features/contacts/data/local_contact_repository_test.dart`, append inside `main()`:

```dart
  test('getContacts orders by family name, part-wise', () async {
    await repo.saveContact(const Contact(
      id: 'lin',
      contactType: ContactType.person,
      firstName: 'Amy',
      lastName: 'Lin',
    ));
    await repo.saveContact(const Contact(
      id: 'li',
      contactType: ContactType.person,
      firstName: 'Zoe',
      lastName: 'Li',
    ));
    await repo.saveContact(const Contact(
      id: 'adams',
      contactType: ContactType.person,
      firstName: 'Zed',
      lastName: 'Adams',
    ));
    expect(
      [for (final c in await repo.getContacts()) c.id],
      ['adams', 'li', 'lin'],
    );
  });
```

- [ ] **Step 2: Run them and watch them fail**

Run: `flutter test test/features/contacts/states/contact_list_entries_test.dart test/features/contacts/presentation/contacts_list_screen_test.dart test/features/contacts/data/local_contact_repository_test.dart`
Expected: compile failure for `contact_list_entries.dart`. Once that exists, the screen tests fail on order (`['Ada Lovelace', 'Bob Stone', 'Kaiser Clinic', '张伟']` vs family order) and on the `zw` search, and the repository test gets `['li', 'lin', 'adams']`-style display-name order.

- [ ] **Step 3: Implement the list provider**

```dart
// lib/features/contacts/states/contact_list_entries.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/providers/contact_sort_provider.dart';
import '../domain/contact_sort.dart';
import '../domain/contact_sort_by.dart';
import '../domain/entities/contact.dart';
import '../domain/pinyin_transcriber.dart';
import 'contacts_state.dart';
import 'pinyin_transcriber_provider.dart';

/// One contact with its sort key and search terms, computed once per list
/// load (and per sort-setting change), never per frame or keystroke.
class ContactListEntry {
  const ContactListEntry({
    required this.contact,
    required this.sortKey,
    required this.terms,
  });

  final Contact contact;
  final String sortKey;
  final ContactSearchTerms terms;
}

/// "Me" first, then [compareContactKeys]. A transcriber failure degrades the
/// affected contacts to raw-text keys and no pinyin terms; it is logged once,
/// by error type only (names never reach the log).
List<ContactListEntry> buildContactListEntries(
  List<Contact> contacts,
  ContactSortBy by,
  PinyinTranscriber? t,
) {
  Object? firstError;
  void onError(Object e) => firstError ??= e;
  final entries = [
    for (final c in contacts)
      ContactListEntry(
        contact: c,
        sortKey: sortKey(c, by, t, onError: onError),
        terms: searchTerms(c, t, onError: onError),
      ),
  ];
  final error = firstError;
  if (error != null) {
    debugPrint(
      'Contacts: pinyin unavailable (${error.runtimeType}); '
      'affected contacts sort by raw text.',
    );
  }
  entries.sort((a, b) {
    if (a.contact.isSelf != b.contact.isSelf) return a.contact.isSelf ? -1 : 1;
    return compareContactKeys(a.contact, a.sortKey, b.contact, b.sortKey);
  });
  return entries;
}

final contactListEntriesProvider =
    Provider<AsyncValue<List<ContactListEntry>>>((ref) {
  final by = ref.watch(contactSortByProvider);
  PinyinTranscriber? t;
  try {
    t = ref.watch(pinyinTranscriberProvider);
  } catch (e) {
    // Dictionary failed to load: the list still renders without pinyin.
    debugPrint('Contacts: pinyin unavailable (${e.runtimeType})');
  }
  return ref
      .watch(contactsStateProvider)
      .whenData((all) => buildContactListEntries(all, by, t));
});
```

- [ ] **Step 4: Switch the list screen**

In `contacts_list_screen.dart`, replace the imports `import '../../domain/entities/contact.dart';` and `import '../../states/contacts_state.dart';` with:

```dart
import '../../domain/contact_sort.dart';
import '../../domain/entities/contact.dart';
import '../../states/contact_list_entries.dart';
```

Delete these lines entirely:

```dart
final _phoneNoise = RegExp(r'[\s\-.()]');

/// Case-insensitive match on name or any email; phone numbers also match with
/// spaces, dashes, dots and parentheses ignored on both sides.
bool _matches(Contact c, String q) {
  if (c.displayName.toLowerCase().contains(q)) return true;
  if (c.emails.any((e) => e.address.toLowerCase().contains(q))) return true;
  final digits = q.replaceAll(_phoneNoise, '');
  return c.phones.any(
    (p) =>
        p.number.toLowerCase().contains(q) ||
        (digits.isNotEmpty &&
            p.number.replaceAll(_phoneNoise, '').contains(digits)),
  );
}
```

In `build`, replace `final async = ref.watch(contactsStateProvider);` with `final async = ref.watch(contactListEntriesProvider);`, and replace `onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),` with:

```dart
              // Raw: matchesSearch normalizes (case, accents, whitespace).
              onChanged: (v) => setState(() => _query = v),
```

Replace the whole `_body` method with:

```dart
  /// [all] arrives sorted ("Me" first, then the sort key), so filtering and
  /// grouping below keep that order.
  Widget _body(AppLocalizations l, List<ContactListEntry> all) {
    final shown = [
      for (final e in all)
        if (_query.trim().isEmpty || matchesSearch(e.contact, e.terms, _query))
          e.contact,
    ];
    if (shown.isEmpty) {
      return Center(child: Text(l.contactsEmpty));
    }
    final headers = {
      _Group.family: l.contactGroupFamily,
      _Group.providers: l.contactGroupProviders,
      _Group.other: l.contactGroupOther,
    };
    final theme = Theme.of(context);
    return ListView(
      children: [
        for (final g in _Group.values)
          ...() {
            final members = shown.where(
              (c) => _groupOf(c.relationship.category) == g,
            );
            if (members.isEmpty) return <Widget>[];
            return <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(
                  headers[g]!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final c in members)
                ContactTile(
                  contact: c,
                  onTap: () => context.pushNamed(
                    RouterNames.contactDetail.name,
                    pathParameters: {'id': c.id},
                  ),
                ),
            ];
          }(),
      ],
    );
  }
```

- [ ] **Step 5: Switch the repository sort**

In `local_contact_repository.dart`, add these imports after `import '../../../features/contacts/data/i_contact_repository.dart';`:

```dart
import '../../../features/contacts/domain/contact_sort.dart';
import '../../../features/contacts/domain/contact_sort_by.dart';
```

Replace:

```dart
    visible.sort((a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return visible;
```

with:

```dart
    // A stable default order without pinyin (the repository holds no
    // transcriber); the contacts list re-sorts with pinyin and the user's
    // setting in contactListEntriesProvider.
    final keys = Map<Contact, String>.identity();
    for (final c in visible) {
      keys[c] = sortKey(c, ContactSortBy.family, null);
    }
    visible.sort((a, b) => compareContactKeys(a, keys[a]!, b, keys[b]!));
    return visible;
```

- [ ] **Step 6: Update the search help text** (the control's behaviour changed)

In `app_en.arb`, replace:

```
  "helpContactsSearchBody": "Type to filter contacts by name, phone or email.",
```

with:

```
  "helpContactsSearchBody": "Type to filter contacts by name, phone or email. Chinese names also match their pinyin, written out (zhangwei) or as initials (zw).",
```

In `app_zh.arb`, replace:

```
  "helpContactsSearchBody": "输入文字，按姓名、电话或邮箱筛选联系人。",
```

with:

```
  "helpContactsSearchBody": "输入文字，按姓名、电话或邮箱筛选联系人。中文姓名也可用拼音全拼（zhangwei）或首字母（zw）搜索。",
```

Run: `flutter gen-l10n`

- [ ] **Step 7: Run them and watch them pass**

Run: `flutter test test/features/contacts/`
Expected: all pass, including the existing list tests (`ADA`, `example.COM` and `5550100` searches keep working).

- [ ] **Step 8: Commit**

```bash
git add lib/features/contacts/states/contact_list_entries.dart lib/features/contacts/presentation/screens/contacts_list_screen.dart lib/core/data/local/local_contact_repository.dart lib/l10n/app_en.arb lib/l10n/app_zh.arb lib/l10n/gen/ test/features/contacts/states/contact_list_entries_test.dart test/features/contacts/presentation/contacts_list_screen_test.dart test/features/contacts/data/local_contact_repository_test.dart
git commit -m "feat(contacts): sort and search the list through pinyin

Keys and terms are precomputed per load; Me first, organizations among
people, Chinese names beside their pinyin; zw / zhangwei find 张伟.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Edit form: field order, preview, "More name options"

**Files:**
- Modify: `lib/features/contacts/states/contact_edit_state.dart`: setters after `setOrganizationName` (line 50), a `phoneticInvalid` getter after `addressesInvalid` (line 33), `_normalized` (lines 133–174), `save` guard (line 180).
- Modify: `lib/features/contacts/presentation/contact_labels.dart`: add `nameOrderLabel`.
- Modify: `lib/features/contacts/presentation/screens/contact_edit_screen.dart`: imports, state fields and lifecycle (lines 70–97), `_save` (lines 99–124), the person name block (lines 180–200), and a new `_NameOrderToggle` class at the end of the file.
- Modify: `lib/core/help/help_registry.dart`: the `HelpId.contactEdit` entries (after the `helpContactEditTypeTitle` entry, line 108).
- Modify: `lib/l10n/app_en.arb`, `app_zh.arb`, regenerated `lib/l10n/gen/`.
- Test: `test/features/contacts/states/contact_edit_state_name_options_test.dart`, `test/features/contacts/presentation/contact_edit_name_options_test.dart`, `test/core/help/help_registry_test.dart` (append).

**Interfaces:**
- Consumes: `ContactName` (Task 2), `pinyinTranscriberProvider` (Task 3), `ContactNameOrder` / `Contact` fields (Task 2).
- Produces:
  ```dart
  // ContactEditState gains:
  bool get phoneticInvalid;
  void setNameOrder(ContactNameOrder o);
  void setPhoneticFamily(String v);
  void setPhoneticGiven(String v);
  String nameOrderLabel(ContactNameOrder o, AppLocalizations l);   // contact_labels.dart
  ```
  Widget keys: `contact-name-preview`, `contact-name-options`, `contact-name-order`, `contact-phonetic-family`, `contact-phonetic-given`. The existing `contact-first-name` / `contact-last-name` keys are unchanged.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/contacts/states/contact_edit_state_name_options_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';
import 'package:hmm_console/features/contacts/states/contact_edit_state.dart';

import '../data/contact_repository_fakes.dart';

const _zh = Contact(
  id: '',
  contactType: ContactType.person,
  lastName: '张',
  firstName: '伟',
);

(ProviderContainer, InMemoryContactRepository) _setup(Contact initial) {
  final repo = InMemoryContactRepository();
  final c = ProviderContainer(
    overrides: [contactRepositoryModeProvider.overrideWithValue(repo)],
  );
  addTearDown(c.dispose);
  final sub = c.listen(contactEditStateProvider(initial), (_, _) {});
  addTearDown(sub.close);
  return (c, repo);
}

void main() {
  test('an invalid phonetic refuses save without sending', () async {
    final (c, repo) = _setup(_zh);
    final n = c.read(contactEditStateProvider(_zh).notifier);
    n.setPhoneticFamily('zh4ng');
    expect(n.phoneticInvalid, isTrue);
    expect(await n.save(), isFalse);
    expect(repo.saveCalls, 0);
    n.setPhoneticFamily('Zhāng');
    expect(n.phoneticInvalid, isFalse);
  });

  test('phonetics are trimmed; blank phonetics are not stored', () async {
    final (c, repo) = _setup(_zh);
    final n = c.read(contactEditStateProvider(_zh).notifier);
    n.setPhoneticFamily('  Tsang ');
    n.setPhoneticGiven('   ');
    n.setNameOrder(ContactNameOrder.givenFirst);
    expect(await n.save(), isTrue);
    final saved = (await repo.getContacts()).single;
    expect(saved.phoneticFamily, 'Tsang');
    expect(saved.phoneticGiven, isNull);
    expect(saved.nameOrder, ContactNameOrder.givenFirst);
  });

  test('saving an organization drops the hidden name options', () async {
    final (c, repo) = _setup(_zh);
    final n = c.read(contactEditStateProvider(_zh).notifier);
    n.setPhoneticFamily('Zhang');
    n.setNameOrder(ContactNameOrder.familyFirst);
    n.setType(ContactType.organization);
    n.setOrganizationName('人民医院');
    expect(await n.save(), isTrue);
    final saved = (await repo.getContacts()).single;
    expect(saved.phoneticFamily, isNull);
    expect(saved.nameOrder, ContactNameOrder.auto);
  });
}
```

```dart
// test/features/contacts/presentation/contact_edit_name_options_test.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';
import 'package:hmm_console/features/contacts/presentation/screens/contact_edit_screen.dart';
import 'package:hmm_console/features/contacts/states/pinyin_transcriber_provider.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

import '../data/contact_repository_fakes.dart';
import '../fake_pinyin_transcriber.dart';

AppLocalizations get _l => lookupAppLocalizations(const Locale('en'));

const _zh = Contact(
  id: 'zh',
  contactType: ContactType.person,
  lastName: '张',
  firstName: '伟',
);
const _latin = Contact(
  id: 'lt',
  contactType: ContactType.person,
  lastName: 'Zhang',
  firstName: 'Wei',
);

Future<InMemoryContactRepository> _mount(
  WidgetTester tester, {
  Contact? seed,
  TargetPlatform platform = TargetPlatform.android,
}) async {
  final repo = InMemoryContactRepository();
  if (seed != null) repo.seed(seed);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        contactRepositoryModeProvider.overrideWithValue(repo),
        pinyinTranscriberProvider.overrideWithValue(FakePinyinTranscriber()),
      ],
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Navigator(
          pages: [
            const MaterialPage(child: Scaffold(body: Text('previous'))),
            MaterialPage(child: ContactEditScreen(contactId: seed?.id)),
          ],
          onDidRemovePage: (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

double _top(WidgetTester tester, String key) =>
    tester.getTopLeft(find.byKey(Key(key))).dy;

void main() {
  testWidgets('a Chinese name opens the options, flips the fields and shows '
      'pinyin hints', (tester) async {
    await _mount(tester, seed: _zh);
    expect(_top(tester, 'contact-last-name'),
        lessThan(_top(tester, 'contact-first-name')));
    expect(find.text(_l.contactShownAs('张伟')), findsOneWidget);
    expect(find.byKey(const Key('contact-phonetic-family')), findsOneWidget);
    expect(find.text('zhang'), findsOneWidget); // hint
    expect(find.text('wei'), findsOneWidget); // hint
  });

  testWidgets('a Latin name keeps given above family; options collapsed',
      (tester) async {
    await _mount(tester, seed: _latin);
    expect(_top(tester, 'contact-first-name'),
        lessThan(_top(tester, 'contact-last-name')));
    expect(find.byKey(const Key('contact-phonetic-family')), findsNothing);
    expect(find.text(_l.contactShownAs('Wei Zhang')), findsOneWidget);
  });

  testWidgets('typing Chinese opens the options and the debounced hint '
      'follows; focus survives the field flip', (tester) async {
    await _mount(tester);
    await tester.enterText(find.byKey(const Key('contact-first-name')), '伟');
    await tester.pump();
    expect(find.byKey(const Key('contact-phonetic-given')), findsOneWidget);
    final given = tester.widget<EditableText>(find.descendant(
      of: find.byKey(const Key('contact-first-name')),
      matching: find.byType(EditableText),
    ));
    expect(given.focusNode.hasFocus, isTrue);
    expect(find.text('wei'), findsNothing); // not yet: debounced
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('wei'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('contact-last-name')), '曾');
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('zeng'), findsOneWidget);
    expect(find.text(_l.contactShownAs('曾伟')), findsOneWidget);
  });

  testWidgets('Android: the order control is a SegmentedButton and changes '
      'the preview and the saved order', (tester) async {
    final repo = await _mount(tester, seed: _latin);
    await tester.tap(find.byKey(const Key('contact-name-options')));
    await tester.pumpAndSettle();
    expect(find.byType(SegmentedButton<ContactNameOrder>), findsOneWidget);
    await tester.ensureVisible(find.text(_l.contactNameOrderFamilyFirst));
    await tester.tap(find.text(_l.contactNameOrderFamilyFirst));
    await tester.pumpAndSettle();
    expect(find.text(_l.contactShownAs('Zhang Wei')), findsOneWidget);
    await tester.tap(find.byKey(const Key('contact-save')));
    await tester.pumpAndSettle();
    expect(
      (await repo.getContact('lt'))!.nameOrder,
      ContactNameOrder.familyFirst,
    );
  });

  testWidgets('iOS: the order control is a CupertinoSlidingSegmentedControl',
      (tester) async {
    await _mount(tester, seed: _zh, platform: TargetPlatform.iOS);
    expect(
      find.byType(CupertinoSlidingSegmentedControl<ContactNameOrder>),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text(_l.contactNameOrderGivenFirst));
    await tester.tap(find.text(_l.contactNameOrderGivenFirst));
    await tester.pumpAndSettle();
    expect(find.text(_l.contactShownAs('伟 张')), findsOneWidget);
  });

  testWidgets('an invalid phonetic shows inline, refuses save with a '
      'SnackBar', (tester) async {
    final repo = await _mount(tester, seed: _zh);
    await tester.enterText(
      find.byKey(const Key('contact-phonetic-family')),
      'zh4ng',
    );
    await tester.pump();
    expect(find.text(_l.contactPhoneticInvalid), findsOneWidget);
    await tester.tap(find.byKey(const Key('contact-save')));
    await tester.pump();
    expect(find.text(_l.contactPhoneticFixToSave), findsOneWidget);
    expect(repo.saveCalls, 0);
    expect(find.text('previous'), findsNothing);
  });

  testWidgets('a valid phonetic is saved trimmed', (tester) async {
    final repo = await _mount(tester, seed: _zh);
    await tester.enterText(
      find.byKey(const Key('contact-phonetic-family')),
      ' Zhāng ',
    );
    await tester.tap(find.byKey(const Key('contact-save')));
    await tester.pumpAndSettle();
    expect((await repo.getContact('zh'))!.phoneticFamily, 'Zhāng');
  });
}
```

Append inside `main()` of `test/core/help/help_registry_test.dart`:

```dart
  test('contact edit help covers More name options with its icon', () {
    final l = lookupAppLocalizations(const Locale('en'));
    final entry = helpFor(HelpId.contactEdit, l)
        .entries
        .singleWhere((e) => e.icon == Icons.translate);
    expect(entry.title, l.helpContactEditNameOptionsTitle);
    expect(entry.body, contains('pinyin'));
  });
```

- [ ] **Step 2: Run them and watch them fail**

Run: `flutter test test/features/contacts/states/contact_edit_state_name_options_test.dart test/features/contacts/presentation/contact_edit_name_options_test.dart test/core/help/help_registry_test.dart`
Expected: compile failures: `setPhoneticFamily`, `contactShownAs`, `contactNameOrderFamilyFirst` and `helpContactEditNameOptionsTitle` aren't defined.

- [ ] **Step 3: Extend `ContactEditState`**

Add `import '../domain/contact_name.dart';` to the imports.

After `bool get addressesInvalid => _addressesInvalid;` add:

```dart
  /// A phonetic field holds something other than Latin letters, spaces and
  /// apostrophes, so [save] will refuse.
  bool get phoneticInvalid =>
      !ContactName.isValidPhonetic(state.contact.phoneticFamily ?? '') ||
      !ContactName.isValidPhonetic(state.contact.phoneticGiven ?? '');
```

After `setOrganizationName` add:

```dart
  void setNameOrder(ContactNameOrder o) =>
      _set(state.contact.copyWith(nameOrder: o));
  void setPhoneticFamily(String v) =>
      _set(state.contact.copyWith(phoneticFamily: v));
  void setPhoneticGiven(String v) =>
      _set(state.contact.copyWith(phoneticGiven: v));
```

In `_normalized`, inside `return c.copyWith(`, after the `organizationName: ...` argument, add:

```dart
      // Person-only options, dropped with the person names.
      nameOrder: knownType && isOrg ? ContactNameOrder.auto : c.nameOrder,
      phoneticFamily: knownType && isOrg ? null : _blankToNull(c.phoneticFamily),
      phoneticGiven: knownType && isOrg ? null : _blankToNull(c.phoneticGiven),
```

In `save`, replace `if (_inFlight || _addressesInvalid) return false;` with:

```dart
    if (_inFlight || _addressesInvalid || phoneticInvalid) return false;
```

- [ ] **Step 4: Add `nameOrderLabel`**

Append to `lib/features/contacts/presentation/contact_labels.dart`:

```dart

String nameOrderLabel(ContactNameOrder o, AppLocalizations l) => switch (o) {
  ContactNameOrder.auto => l.contactNameOrderAuto,
  ContactNameOrder.givenFirst => l.contactNameOrderGivenFirst,
  ContactNameOrder.familyFirst => l.contactNameOrderFamilyFirst,
};
```

- [ ] **Step 5: Add the ARB strings**

In `app_en.arb`, replace:

```
  "helpContactsSortBody": "Contacts are sorted by family name. To sort by given name instead, change Sort contacts by in Settings. Chinese names sort by their pinyin, next to Latin names."
}
```

with:

```
  "helpContactsSortBody": "Contacts are sorted by family name. To sort by given name instead, change Sort contacts by in Settings. Chinese names sort by their pinyin, next to Latin names.",
  "contactNameOptions": "More name options",
  "contactNameOrder": "Name order",
  "contactNameOrderAuto": "Auto",
  "contactNameOrderGivenFirst": "Given name first",
  "contactNameOrderFamilyFirst": "Family name first",
  "contactPhoneticFamily": "Family name phonetic",
  "contactPhoneticGiven": "Given name phonetic",
  "contactPhoneticInvalid": "Use Latin letters, spaces and apostrophes only",
  "contactPhoneticFixToSave": "Fix the highlighted phonetic name to save",
  "contactShownAs": "Shown as: {name}",
  "@contactShownAs": {
    "placeholders": {
      "name": {
        "type": "String"
      }
    }
  },
  "helpContactEditNameOptionsTitle": "More name options",
  "helpContactEditNameOptionsBody": "Chinese names are shown family name first (张伟), other names given name first (John Smith). Name order changes this for one contact. The phonetic fields set how the name is sorted and searched; left empty, the pinyin shown in grey is used. This section opens by itself for Chinese names."
}
```

In `app_zh.arb`, replace:

```
  "helpContactsSortBody": "联系人默认按姓氏排序。如需按名字排序，请在“设置”中更改“联系人排序方式”。中文姓名按拼音排序，与拉丁字母姓名排在一起。"
}
```

with:

```
  "helpContactsSortBody": "联系人默认按姓氏排序。如需按名字排序，请在“设置”中更改“联系人排序方式”。中文姓名按拼音排序，与拉丁字母姓名排在一起。",
  "contactNameOptions": "更多姓名选项",
  "contactNameOrder": "姓名顺序",
  "contactNameOrderAuto": "自动",
  "contactNameOrderGivenFirst": "名在前",
  "contactNameOrderFamilyFirst": "姓在前",
  "contactPhoneticFamily": "姓氏拼音",
  "contactPhoneticGiven": "名字拼音",
  "contactPhoneticInvalid": "只能使用拉丁字母、空格和撇号",
  "contactPhoneticFixToSave": "请修正标出的拼音后再保存",
  "contactShownAs": "显示为：{name}",
  "helpContactEditNameOptionsTitle": "更多姓名选项",
  "helpContactEditNameOptionsBody": "中文姓名按姓在前显示（张伟），其他姓名按名在前显示（John Smith）。“姓名顺序”可为单个联系人更改此规则。拼音字段决定姓名的排序和搜索方式；留空时使用灰色显示的自动拼音。输入中文姓名时，此部分会自动展开。"
}
```

Run: `flutter gen-l10n`

- [ ] **Step 6: Build the form changes**

In `contact_edit_screen.dart`, add at the top:

```dart
import 'dart:async';
```

and after `import '../../../../l10n/gen/app_localizations.dart';`:

```dart
import '../../domain/contact_name.dart';
import '../../domain/pinyin_transcriber.dart';
import '../../states/pinyin_transcriber_provider.dart';
```

Replace the `_ContactFormState` fields, `initState` and `dispose` (from `class _ContactFormState extends ConsumerState<_ContactForm> {` through the end of `dispose`) with:

```dart
class _ContactFormState extends ConsumerState<_ContactForm> {
  late final TextEditingController _first;
  late final TextEditingController _last;
  late final TextEditingController _org;
  late final TextEditingController _custom;
  late final TextEditingController _notes;
  late final TextEditingController _phoneticFamily;
  late final TextEditingController _phoneticGiven;
  final _addresses = GlobalKey<AddressEditorState>();

  /// "More name options": open for Chinese names or any option set; opens by
  /// itself when Chinese is typed, until the user toggles it.
  bool _nameOptionsOpen = false;
  bool _nameOptionsToggled = false;

  /// Automatic pinyin shown as grey hint text in empty phonetic fields.
  String _hintFamily = '';
  String _hintGiven = '';
  Timer? _hintDebounce;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _first = TextEditingController(text: c.firstName ?? '');
    _last = TextEditingController(text: c.lastName ?? '');
    _org = TextEditingController(text: c.organizationName ?? '');
    _custom = TextEditingController(text: c.relationship.customLabel ?? '');
    _notes = TextEditingController(text: c.notes ?? '');
    _phoneticFamily = TextEditingController(text: c.phoneticFamily ?? '');
    _phoneticGiven = TextEditingController(text: c.phoneticGiven ?? '');
    _nameOptionsOpen =
        ContactName.hasChinese(c.firstName) ||
        ContactName.hasChinese(c.lastName) ||
        c.nameOrder != ContactNameOrder.auto ||
        (c.phoneticFamily ?? '').isNotEmpty ||
        (c.phoneticGiven ?? '').isNotEmpty;
    _recomputeHints();
  }

  @override
  void dispose() {
    _hintDebounce?.cancel();
    _first.dispose();
    _last.dispose();
    _org.dispose();
    _custom.dispose();
    _notes.dispose();
    _phoneticFamily.dispose();
    _phoneticGiven.dispose();
    super.dispose();
  }

  PinyinTranscriber? _transcriber() {
    try {
      return ref.read(pinyinTranscriberProvider);
    } catch (e) {
      debugPrint('ContactEdit: pinyin unavailable (${e.runtimeType})');
      return null;
    }
  }

  /// Hints come from the same transcriber the list sorts with. A failure
  /// leaves the hint empty; type only in the log.
  void _recomputeHints() {
    final t = _transcriber();
    String hint(String part, {required bool family}) {
      if (t == null || !ContactName.hasChinese(part)) return '';
      try {
        return (family ? t.family(part) : t.given(part)).join(' ');
      } catch (e) {
        debugPrint('ContactEdit: pinyin hint failed (${e.runtimeType})');
        return '';
      }
    }

    _hintFamily = hint(_last.text, family: true);
    _hintGiven = hint(_first.text, family: false);
  }

  void _onNameChanged() {
    if (!_nameOptionsToggled &&
        !_nameOptionsOpen &&
        (ContactName.hasChinese(_first.text) ||
            ContactName.hasChinese(_last.text))) {
      setState(() => _nameOptionsOpen = true);
    }
    _hintDebounce?.cancel();
    _hintDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(_recomputeHints);
    });
  }
```

In `_save`, replace:

```dart
    // Checked before any await, so the reveal and snackbar use live state.
    if (notifier.addressesInvalid) {
```

with:

```dart
    // Checked before any await, so the reveal and snackbar use live state.
    if (notifier.phoneticInvalid) {
      setState(() => _nameOptionsOpen = true);
      messenger.showSnackBar(
        SnackBar(content: Text(l.contactPhoneticFixToSave)),
      );
      return;
    }
    if (notifier.addressesInvalid) {
```

In `build`, after `final isOrg = c.contactType == ContactType.organization;` add:

```dart
    final theme = Theme.of(context);
    final chinese =
        ContactName.hasChinese(c.firstName) ||
        ContactName.hasChinese(c.lastName);
    // Keyed slots: the two fields swap places as Chinese is typed, and the
    // keys move the elements (focus, cursor) with them.
    final givenSlot = KeyedSubtree(
      key: const ValueKey('contact-given-slot'),
      child: _pad(
        TextField(
          key: const Key('contact-first-name'),
          controller: _first,
          decoration: InputDecoration(
            labelText: l.contactFirstName,
            errorText: nameError,
          ),
          onChanged: (v) {
            notifier.setFirstName(v);
            _onNameChanged();
          },
        ),
      ),
    );
    final familySlot = KeyedSubtree(
      key: const ValueKey('contact-family-slot'),
      child: _pad(
        TextField(
          key: const Key('contact-last-name'),
          controller: _last,
          decoration: InputDecoration(labelText: l.contactLastName),
          onChanged: (v) {
            notifier.setLastName(v);
            _onNameChanged();
          },
        ),
      ),
    );
```

Replace the person block:

```dart
              else ...[
                _pad(
                  TextField(
                    key: const Key('contact-first-name'),
                    controller: _first,
                    decoration: InputDecoration(
                      labelText: l.contactFirstName,
                      errorText: nameError,
                    ),
                    onChanged: notifier.setFirstName,
                  ),
                ),
                _pad(
                  TextField(
                    key: const Key('contact-last-name'),
                    controller: _last,
                    decoration: InputDecoration(labelText: l.contactLastName),
                    onChanged: notifier.setLastName,
                  ),
                ),
              ],
```

with:

```dart
              else ...[
                // Same stored data either way; Chinese names read 姓 then 名.
                ...(chinese ? [familySlot, givenSlot] : [givenSlot, familySlot]),
                if (c.displayName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                    child: Text(
                      l.contactShownAs(c.displayName),
                      key: const Key('contact-name-preview'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ListTile(
                  key: const Key('contact-name-options'),
                  leading: const Icon(Icons.translate),
                  title: Text(l.contactNameOptions),
                  trailing: Icon(
                    _nameOptionsOpen ? Icons.expand_less : Icons.expand_more,
                  ),
                  onTap: () => setState(() {
                    _nameOptionsToggled = true;
                    _nameOptionsOpen = !_nameOptionsOpen;
                  }),
                ),
                if (_nameOptionsOpen) ...[
                  _pad(
                    Text(l.contactNameOrder, style: theme.textTheme.labelMedium),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: _NameOrderToggle(
                      isIos: isIos,
                      value: c.nameOrder,
                      onChanged: notifier.setNameOrder,
                    ),
                  ),
                  _pad(
                    TextField(
                      key: const Key('contact-phonetic-family'),
                      controller: _phoneticFamily,
                      decoration: InputDecoration(
                        labelText: l.contactPhoneticFamily,
                        hintText: _hintFamily.isEmpty ? null : _hintFamily,
                        floatingLabelBehavior: _hintFamily.isEmpty
                            ? null
                            : FloatingLabelBehavior.always,
                        errorText: ContactName.isValidPhonetic(
                          c.phoneticFamily ?? '',
                        )
                            ? null
                            : l.contactPhoneticInvalid,
                      ),
                      onChanged: notifier.setPhoneticFamily,
                    ),
                  ),
                  _pad(
                    TextField(
                      key: const Key('contact-phonetic-given'),
                      controller: _phoneticGiven,
                      decoration: InputDecoration(
                        labelText: l.contactPhoneticGiven,
                        hintText: _hintGiven.isEmpty ? null : _hintGiven,
                        floatingLabelBehavior: _hintGiven.isEmpty
                            ? null
                            : FloatingLabelBehavior.always,
                        errorText: ContactName.isValidPhonetic(
                          c.phoneticGiven ?? '',
                        )
                            ? null
                            : l.contactPhoneticInvalid,
                      ),
                      onChanged: notifier.setPhoneticGiven,
                    ),
                  ),
                ],
              ],
```

Append at the end of the file:

```dart

/// Auto / Given name first / Family name first: Cupertino sliding control on
/// iOS, Material segmented button elsewhere (same pattern as [_TypeToggle]).
class _NameOrderToggle extends StatelessWidget {
  const _NameOrderToggle({
    required this.isIos,
    required this.value,
    required this.onChanged,
  });

  final bool isIos;
  final ContactNameOrder value;
  final ValueChanged<ContactNameOrder> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (isIos) {
      return CupertinoSlidingSegmentedControl<ContactNameOrder>(
        key: const Key('contact-name-order'),
        groupValue: value,
        children: {
          for (final o in ContactNameOrder.values)
            o: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(nameOrderLabel(o, l), textAlign: TextAlign.center),
            ),
        },
        onValueChanged: (o) {
          if (o != null) onChanged(o);
        },
      );
    }
    return SegmentedButton<ContactNameOrder>(
      key: const Key('contact-name-order'),
      showSelectedIcon: false,
      segments: [
        for (final o in ContactNameOrder.values)
          ButtonSegment(value: o, label: Text(nameOrderLabel(o, l))),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}
```

- [ ] **Step 7: Add the help entry**

In `help_registry.dart`, inside `HelpId.contactEdit`'s `entries`, after the `Icons.person_outline` / `helpContactEditTypeTitle` entry, add:

```dart
            HelpEntry(
                icon: Icons.translate,
                title: l.helpContactEditNameOptionsTitle,
                body: l.helpContactEditNameOptionsBody),
```

- [ ] **Step 8: Run them and watch them pass**

Run: `flutter test test/features/contacts/ test/core/help/`
Expected: all pass, including the existing `contact_edit_screen_test.dart` (Latin names leave the options collapsed and keep the field order) and `icon_button_guard_test.dart` (no raw `IconButton`; the expander is a `ListTile`).

- [ ] **Step 9: Commit**

```bash
git add lib/features/contacts/states/contact_edit_state.dart lib/features/contacts/presentation/contact_labels.dart lib/features/contacts/presentation/screens/contact_edit_screen.dart lib/core/help/help_registry.dart lib/l10n/app_en.arb lib/l10n/app_zh.arb lib/l10n/gen/ test/features/contacts/states/contact_edit_state_name_options_test.dart test/features/contacts/presentation/contact_edit_name_options_test.dart test/core/help/help_registry_test.dart
git commit -m "feat(contacts): name order, phonetics and preview in the edit form

Chinese names read 姓 then 名; More name options opens for them, with
the automatic pinyin as hint text; invalid phonetics refuse save.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Detail, tile and Me use the ordered name; cheatsheet `DerivedFieldRegistry`

**Files:**
- Verify (no edit expected): `lib/features/contacts/presentation/widgets/contact_tile.dart:30`, `lib/features/contacts/presentation/screens/contact_detail_screen.dart:109`. Both read `contact.displayName`, which now delegates to `ContactName` (Task 2).
- Create: `lib/features/cheatsheet/domain/derived_field_registry.dart`
- Modify: `lib/features/cheatsheet/domain/note_piece_extractor.dart`: add `entity()` after `_entityMap` (line 30); add `nameOrder`, `phoneticFamily`, `phoneticGiven` to `_internalKeys` (lines 49–59) so the field picker's offered paths are unchanged.
- Modify: `lib/features/cheatsheet/data/cheatsheet_resolver.dart`: constructor (line 29) and the `field` branch (line 54).
- Create: `lib/features/contacts/data/contact_derived_fields.dart`
- Create: `lib/features/cheatsheet/states/derived_field_registry_provider.dart`
- Modify: `lib/features/cheatsheet/presentation/screens/cheatsheet_detail_screen.dart`: `cheatsheetResolverProvider` (lines 22–24).
- Test: `test/features/cheatsheet/domain/derived_field_registry_test.dart`; append to `test/features/cheatsheet/domain/note_piece_extractor_test.dart`, `test/features/contacts/cheatsheet_binding_test.dart`, `test/features/contacts/presentation/contact_detail_screen_test.dart` and `test/features/contacts/presentation/contacts_list_screen_test.dart`.

**Interfaces:**
- Consumes: `ContactCodec.fromMap`, `ContactName.displayName`.
- Produces:
  ```dart
  typedef DerivedFieldResolver = String? Function(Map<String, dynamic> entity);
  class DerivedFieldRegistry {
    const DerivedFieldRegistry([Map<String, Map<String, DerivedFieldResolver>> resolvers = const {}]);
    String? resolve(String rootKey, String path, Map<String, dynamic> entityMap);
  }
  static Map<String, dynamic>? NotePieceExtractor.entity(String? content, String rootKey);
  // NotePieceExtractor._internalKeys gains 'nameOrder', 'phoneticFamily', 'phoneticGiven' (offer filter only; field() unchanged)
  CheatsheetResolver(IHmmNoteRepository notes, [DerivedFieldRegistry derived = const DerivedFieldRegistry()]);
  String? contactDisplayNameField(Map<String, dynamic> entity);
  const Map<String, Map<String, DerivedFieldResolver>> contactDerivedFields;
  final derivedFieldRegistryProvider = Provider<DerivedFieldRegistry>(...);
  ```

- [ ] **Step 1: Verify the call sites**

Run: `grep -rn "displayName" lib/features/contacts lib/core/data/local/local_contact_repository.dart`
Expected: the only reads are `contact_tile.dart:30`, `contact_detail_screen.dart:109`, `contact_edit_state.dart` (empty-name check), the edit-screen preview, `contact_codec.dart` (write), `contact_sort.dart` (search and tie-break) and the `Contact` getter. None re-implements ordering. If any other `firstName`/`lastName` join appears, replace it with `contact.displayName`.

- [ ] **Step 2: Write the failing tests**

```dart
// test/features/cheatsheet/domain/derived_field_registry_test.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/cheatsheet/domain/derived_field_registry.dart';

String? _upper(Map<String, dynamic> e) => (e['name'] as String?)?.toUpperCase();
String? _boom(Map<String, dynamic> e) => throw StateError('bad ${e['name']}');

void main() {
  test('resolves a registered root + path, null otherwise', () {
    const r = DerivedFieldRegistry({
      'Thing': {'name': _upper},
    });
    expect(r.resolve('Thing', 'name', {'name': 'abc'}), 'ABC');
    expect(r.resolve('Thing', 'other', {'name': 'abc'}), isNull);
    expect(r.resolve('Other', 'name', {'name': 'abc'}), isNull);
    expect(const DerivedFieldRegistry().resolve('Thing', 'name', {}), isNull);
  });

  test('a throwing resolver yields null and logs the type only', () {
    final logs = <String>[];
    final old = debugPrint;
    debugPrint = (m, {wrapWidth}) => logs.add(m ?? '');
    addTearDown(() => debugPrint = old);
    const r = DerivedFieldRegistry({
      'Thing': {'name': _boom},
    });
    expect(r.resolve('Thing', 'name', {'name': 'secret'}), isNull);
    expect(logs.join(), contains('StateError'));
    expect(logs.join(), isNot(contains('secret')));
  });
}
```

Append to `test/features/contacts/cheatsheet_binding_test.dart` (add the imports `import 'package:hmm_console/features/cheatsheet/domain/derived_field_registry.dart';` and `import 'package:hmm_console/features/contacts/data/contact_derived_fields.dart';` at the top), inside `main()`:

```dart
  group('derived Contact.displayName', () {
    const nameRow = CheatsheetRow(
      label: 'Name',
      source: CheatsheetSource(
        noteUuid: 'doc-uuid',
        kind: SourceGranularity.field,
        locator: 'Contact.displayName',
      ),
    );

    /// A note saved by the pre-order client: displayName "伟 张".
    HmmNote legacy(Map<String, dynamic> contact) => HmmNote(
      id: 1,
      uuid: 'doc-uuid',
      subject: 'Contact:c-zh',
      authorId: 1,
      createDate: DateTime(2026),
      content: jsonEncode({
        'note': {
          'content': {'Contact': contact},
        },
      }),
    );

    const legacyZh = {
      'schemaVersion': 1,
      'displayName': '伟 张',
      'id': 'c-zh',
      'contactType': 'person',
      'firstName': '伟',
      'lastName': '张',
    };

    test('an unsaved legacy contact shows 张伟 through the registry',
        () async {
      final r = CheatsheetResolver(
        _FakeNotes({'doc-uuid': legacy(legacyZh)}),
        const DerivedFieldRegistry(contactDerivedFields),
      );
      expect((await r.resolve(nameRow)).text, '张伟');
    });

    test('without the registry the stored value is used', () async {
      final r = CheatsheetResolver(_FakeNotes({'doc-uuid': legacy(legacyZh)}));
      expect((await r.resolve(nameRow)).text, '伟 张');
    });

    test('a nameless contact falls back to the stored value', () async {
      final r = CheatsheetResolver(
        _FakeNotes({
          'doc-uuid': legacy({
            'id': 'c-x',
            'contactType': 'person',
            'displayName': 'Kept',
          }),
        }),
        const DerivedFieldRegistry(contactDerivedFields),
      );
      expect((await r.resolve(nameRow)).text, 'Kept');
    });

    test('other Contact paths are untouched', () async {
      final r = CheatsheetResolver(
        _FakeNotes({'doc-uuid': contactNote(doctor)}),
        const DerivedFieldRegistry(contactDerivedFields),
      );
      expect((await r.resolve(_row)).text, '555-0100');
    });
  });
```

Append inside `main()` of `test/features/contacts/presentation/contact_detail_screen_test.dart`:

```dart
  testWidgets('a Chinese name is shown family-first in the title',
      (tester) async {
    await _mount(
      tester,
      id: 'zh',
      seed: const Contact(
        id: 'zh',
        contactType: ContactType.person,
        firstName: '伟',
        lastName: '张',
      ),
    );
    expect(find.text('张伟'), findsOneWidget);
    expect(find.text('伟 张'), findsNothing);
  });
```

Append inside `main()` of `test/features/contacts/presentation/contacts_list_screen_test.dart`:

```dart
  testWidgets('the Me tile shows the ordered name', (tester) async {
    await _mount(tester, [
      ..._repo(
        InMemoryContactRepository()
          ..seed(const Contact(
            id: 'me',
            contactType: ContactType.person,
            firstName: '伟',
            lastName: '张',
            isSelf: true,
          )),
      ),
      pinyinTranscriberProvider.overrideWithValue(FakePinyinTranscriber()),
    ]);
    expect(find.text('张伟'), findsOneWidget);
    expect(find.byKey(const Key('contact-self-badge')), findsOneWidget);
  });
```

- [ ] **Step 3: Run them and watch them fail**

Run: `flutter test test/features/cheatsheet/domain/derived_field_registry_test.dart test/features/contacts/cheatsheet_binding_test.dart test/features/contacts/presentation/contact_detail_screen_test.dart test/features/contacts/presentation/contacts_list_screen_test.dart`
Expected: compile failures for `derived_field_registry.dart` and `contact_derived_fields.dart`, and `Too many positional arguments` on `CheatsheetResolver`. The detail and Me tests already pass, because Task 2 changed the getter. They are regression pins.

- [ ] **Step 4: Implement the registry**

```dart
// lib/features/cheatsheet/domain/derived_field_registry.dart
import 'package:flutter/foundation.dart';

/// Computes a field from the stored entity map instead of reading it.
typedef DerivedFieldResolver = String? Function(Map<String, dynamic> entity);

/// Read-time values for `field` rows, keyed by entity root (`Contact`) and
/// dotted path (`displayName`). The resolver consults this before reading
/// the stored JSON; null (unregistered, empty, or failed) falls back to the
/// stored value. The field picker's offered paths are unaffected.
class DerivedFieldRegistry {
  const DerivedFieldRegistry([this._resolvers = const {}]);

  final Map<String, Map<String, DerivedFieldResolver>> _resolvers;

  String? resolve(String rootKey, String path, Map<String, dynamic> entityMap) {
    final f = _resolvers[rootKey]?[path];
    if (f == null) return null;
    try {
      return f(entityMap);
    } catch (e) {
      // Type only: the message can quote stored data.
      debugPrint('DerivedFieldRegistry: $rootKey.$path failed '
          '(${e.runtimeType}); using the stored value.');
      return null;
    }
  }
}
```

- [ ] **Step 5: Expose the entity map**

In `note_piece_extractor.dart`, after the `_entityMap` method add:

```dart
  /// The map under `note.content.<rootKey>`, or null. Never throws.
  static Map<String, dynamic>? entity(String? content, String rootKey) {
    final v = _entityMap(content)?[rootKey];
    return v is Map ? v.cast<String, dynamic>() : null;
  }
```

- [ ] **Step 6: Consult the registry in the resolver**

In `cheatsheet_resolver.dart`, add the import `import '../domain/derived_field_registry.dart';`. Replace:

```dart
  CheatsheetResolver(this._notes);

  final IHmmNoteRepository _notes;
```

with:

```dart
  CheatsheetResolver(
    this._notes, [
    this._derived = const DerivedFieldRegistry(),
  ]);

  final IHmmNoteRepository _notes;
  final DerivedFieldRegistry _derived;

  /// A derived value (e.g. `Contact.displayName` in the contact's name
  /// order) wins; otherwise the stored scalar at [locator].
  String? _field(String? content, String locator) {
    final dot = locator.indexOf('.');
    if (dot > 0) {
      final root = locator.substring(0, dot);
      final entity = NotePieceExtractor.entity(content, root);
      if (entity != null) {
        final derived =
            _derived.resolve(root, locator.substring(dot + 1), entity);
        if (derived != null && derived.isNotEmpty) return derived;
      }
    }
    return NotePieceExtractor.field(content, locator);
  }
```

and replace:

```dart
      SourceGranularity.field =>
        NotePieceExtractor.field(note.content, s.locator ?? ''),
```

with:

```dart
      SourceGranularity.field => _field(note.content, s.locator ?? ''),
```

- [ ] **Step 7: Register the Contacts resolver**

```dart
// lib/features/contacts/data/contact_derived_fields.dart
import '../../cheatsheet/domain/derived_field_registry.dart';
import 'contact_codec.dart';

/// `Contact.displayName` in the contact's name order, so a card bound to it
/// shows 张伟 even while the stored value is still the legacy "伟 张"
/// (no bulk rewrite). Null on an empty name or any decode failure, so the
/// row falls back to the stored value.
String? contactDisplayNameField(Map<String, dynamic> entity) {
  try {
    final name = ContactCodec.fromMap(entity).displayName;
    return name.isEmpty ? null : name;
  } catch (_) {
    return null;
  }
}

const contactDerivedFields = <String, Map<String, DerivedFieldResolver>>{
  'Contact': {'displayName': contactDisplayNameField},
};
```

```dart
// lib/features/cheatsheet/states/derived_field_registry_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contacts/data/contact_derived_fields.dart';
import '../domain/derived_field_registry.dart';

/// Every feature's derived cheatsheet fields. Riverpod is the app's only DI,
/// so features register here rather than into a global at startup.
final derivedFieldRegistryProvider = Provider<DerivedFieldRegistry>(
  (ref) => const DerivedFieldRegistry({...contactDerivedFields}),
);
```

In `cheatsheet_detail_screen.dart`, add the import `import '../../states/derived_field_registry_provider.dart';` after `import '../../states/cheatsheets_state.dart';`, and replace:

```dart
final cheatsheetResolverProvider = Provider<CheatsheetResolver>(
  (ref) => CheatsheetResolver(ref.watch(hmmNoteRepositoryProvider)),
);
```

with:

```dart
final cheatsheetResolverProvider = Provider<CheatsheetResolver>(
  (ref) => CheatsheetResolver(
    ref.watch(hmmNoteRepositoryProvider),
    ref.watch(derivedFieldRegistryProvider),
  ),
);
```

- [ ] **Step 7a: Write the failing offer-filter test** (spec: the field picker's offered paths are unchanged)

Append inside `main()` of `test/features/cheatsheet/domain/note_piece_extractor_test.dart`:

```dart
  test('contact name options are never offered, but still resolve', () {
    const content = '{"note":{"content":{"Contact":{"displayName":"Zhang Wei",'
        '"firstName":"Wei","lastName":"Zhang","nameOrder":"familyFirst",'
        '"phoneticFamily":"Zhang","phoneticGiven":"Wei"}}}}';
    final paths = NotePieceExtractor.fieldPaths(content);
    expect(paths, [
      'Contact.displayName',
      'Contact.firstName',
      'Contact.lastName',
    ]);
    // Offer policy only: an explicit binding still resolves.
    expect(NotePieceExtractor.field(content, 'Contact.nameOrder'),
        'familyFirst');
    expect(NotePieceExtractor.field(content, 'Contact.phoneticFamily'),
        'Zhang');
  });
```

Run: `flutter test test/features/cheatsheet/domain/note_piece_extractor_test.dart`
Expected: FAIL. `paths` also contains `Contact.nameOrder`, `Contact.phoneticFamily` and `Contact.phoneticGiven`.

- [ ] **Step 7b: Hide the name options from the offer filter**

In `note_piece_extractor.dart`, replace:

```dart
  static const _internalKeys = {
    '_v',
    'id',
    'uuid',
    'authorId',
    'parentNoteId',
    'version',
    'schemaVersion',
    'isSelf',
    'isActivated',
  };
```

with:

```dart
  static const _internalKeys = {
    '_v',
    'id',
    'uuid',
    'authorId',
    'parentNoteId',
    'version',
    'schemaVersion',
    'isSelf',
    'isActivated',
    // Contact name options: sort/display plumbing, not card content. Hidden
    // so a contact with them set offers the same paths as before.
    'nameOrder',
    'phoneticFamily',
    'phoneticGiven',
  };
```

Run: `flutter test test/features/cheatsheet/domain/note_piece_extractor_test.dart`
Expected: all pass.

- [ ] **Step 8: Run them and watch them pass**

Run: `flutter test test/features/cheatsheet/ test/features/contacts/ test/features/dashboard/`
Expected: all pass. The existing resolver tests construct `CheatsheetResolver(notes)` and still compile.

- [ ] **Step 9: Commit**

```bash
git add lib/features/cheatsheet/domain/derived_field_registry.dart lib/features/cheatsheet/domain/note_piece_extractor.dart lib/features/cheatsheet/data/cheatsheet_resolver.dart lib/features/contacts/data/contact_derived_fields.dart lib/features/cheatsheet/states/derived_field_registry_provider.dart lib/features/cheatsheet/presentation/screens/cheatsheet_detail_screen.dart test/features/cheatsheet/domain/derived_field_registry_test.dart test/features/cheatsheet/domain/note_piece_extractor_test.dart test/features/contacts/cheatsheet_binding_test.dart test/features/contacts/presentation/contact_detail_screen_test.dart test/features/contacts/presentation/contacts_list_screen_test.dart
git commit -m "feat(cheatsheet): derived fields; contact names resolve in order

Cards bound to Contact.displayName show 张伟 for contacts never re-saved;
any failure falls back to the stored value.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Full verification

**Files:**
- No code changes. Fix anything found here in the task that owns it, then re-run this task.

**Interfaces:**
- Consumes: everything above.
- Produces: a green branch ready for review, plus the manual check results noted in the ledger.

- [ ] **Step 1: Analyze**

Run: `flutter analyze`
Expected: exactly 2 issues, the pre-existing infos in `onboarding_screen.dart` and `main.dart`. Anything else gets fixed.

- [ ] **Step 2: Full test suite**

Run: `flutter test 2>&1 | tail -3`
Expected: `All tests passed!` with a count above 1925, that is, 1925 plus every test added in Tasks 2–9.

- [ ] **Step 3: ARB parity**

```bash
cd /Users/fchy/Projects/hmm_console && python3 - <<'EOF'
import json
en = {k for k in json.load(open('lib/l10n/app_en.arb')) if not k.startswith('@')}
zh = {k for k in json.load(open('lib/l10n/app_zh.arb')) if not k.startswith('@')}
print('missing in zh:', sorted(en - zh))
print('missing in en:', sorted(zh - en))
EOF
flutter gen-l10n && git status --short lib/l10n/gen
```

Expected: both lists empty, and no uncommitted changes in `lib/l10n/gen`.

- [ ] **Step 4: Guard checks**

```bash
cd /Users/fchy/Projects/hmm_console
grep -rn "IconButton(" lib/features/contacts lib/features/settings lib/features/cheatsheet | grep -v HmmIconButton   # expect: nothing new
grep -rn "debugPrint" lib/features/contacts lib/features/cheatsheet/domain/derived_field_registry.dart lib/features/settings/providers/contact_sort_provider.dart   # every new line prints ids / runtimeType only
grep -rn "pinyin" lib/features/contacts/data/contact_codec.dart   # expect: nothing (pinyin never persisted)
git status --short   # expect: clean
```

- [ ] **Step 5: Manual checks (record each result in the ledger)**

Run on the iOS simulator (macOS dev host, per CLAUDE.md) with `flutter run`, then on an Android emulator:

1. Create `张` / `伟`: the fields flip to 姓 above 名 while typing, the preview reads `Shown as: 张伟`, More name options opens by itself, and the phonetic hints show `zhang` / `wei` in grey.
2. Set Name order to Given name first: the preview reads `伟 张`. Save. The list and detail show `伟 张`.
3. iOS shows the Cupertino sliding control, Android the Material segmented button. All three labels fit at 320 pt width (iPhone SE) in both en and zh, with no overflow stripe.
4. Type `zh4ng` in a phonetic field: an inline error appears, Save shows the SnackBar, and the form stays open.
5. Search `zw`, `zhangwei` and `张`: each finds 张伟. Search `wz`: it does not.
6. Settings → Sort contacts by → Given name: the list reorders. The value survives an app restart.
7. A cheatsheet card bound to that contact's `Contact.displayName` shows the ordered name.
8. Open an existing pre-feature contact and save without changes: the list is unchanged. In cloudStorage mode, check that no sync push is triggered by content change, if the sync status card makes that visible.
9. The dashboard cold start feels no slower. The pinyin dictionary loads only on first opening Contacts.

- [ ] **Step 6: Stop**

Do not push, merge or open a PR. Report the commit range (`git log --oneline main..HEAD`) and the manual results to the user.

---

## Spike outcome

_Filled in by Task 1 Step 6; Task 3 reads it._

- Decision: (A `pinyin_pro_flutter` / B `pinyin` 3.3.0 + surname table)
- Surnames (曾 单 解 区 仇 朴 查 盖 → actual): 
- Synchronous, no init (欧阳 → ou yang): 
- Toolchain (`flutter --version` line, pubspec `sdk:`): 
- Release `Runner.app` KB before / after / delta: 
- API names, if different from the plan's `ToneType.none`, `PinyinReturnType.array`, `SurnameMode.head/off`: 
