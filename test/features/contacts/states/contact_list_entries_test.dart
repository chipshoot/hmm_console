// test/features/contacts/states/contact_list_entries_test.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/contacts/domain/contact_sort_by.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';
import 'package:hmm_console/features/contacts/states/contact_list_entries.dart';
import 'package:hmm_console/features/contacts/states/contacts_state.dart';
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

List<String> _ids(List<ContactListEntry> es) => [
  for (final e in es) e.contact.id,
];

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

  test(
    'one transcriber failure leaves the rest sorted and logs the type once',
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
    },
  );

  test('a null transcriber still builds a sorted list', () {
    final entries = buildContactListEntries(
      [_p('b', 'B', 'x'), _p('a', 'A', 'x')],
      ContactSortBy.family,
      null,
    );
    expect(_ids(entries), ['a', 'b']);
  });

  test(
    'the provider combines contacts, the setting and the transcriber',
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
    },
  );
}
