import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/local/local_contact_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/contacts/domain/contact_sort_by.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact_field.dart';
import 'package:hmm_console/features/contacts/presentation/screens/contacts_list_screen.dart';
import 'package:hmm_console/features/contacts/states/pinyin_transcriber_provider.dart';
import 'package:hmm_console/features/settings/providers/contact_sort_provider.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/contact_repository_fakes.dart';
import '../fake_pinyin_transcriber.dart';

class _StubMode extends DataModeNotifier {
  _StubMode(this._m);
  final DataMode _m;
  @override
  DataMode build() => _m;
}

/// A data mode the test can switch while the screen stays mounted.
class _SwitchableMode extends DataModeNotifier {
  _SwitchableMode(this._m);
  final DataMode _m;
  @override
  DataMode build() => _m;
  void switchTo(DataMode m) => state = m;
}

const _ada = Contact(
  id: 'a',
  contactType: ContactType.person,
  firstName: 'Ada',
  lastName: 'Lovelace',
);
const _bob = Contact(
  id: 'b',
  contactType: ContactType.person,
  firstName: 'Bob',
  lastName: 'Stone',
);

Future<void> _mount(WidgetTester tester, List<Override> overrides) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ContactsListScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<Override> _repo(InMemoryContactRepository r) => [
  contactRepositoryModeProvider.overrideWithValue(r),
];


List<String> _titles(WidgetTester tester) => [
  for (final t in tester.widgetList<ListTile>(find.byType(ListTile)))
    (t.title! as Text).data!,
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('the self contact carries a Me marker, others do not', (
    tester,
  ) async {
    await _mount(
      tester,
      _repo(
        InMemoryContactRepository()
          ..seed(_ada.copyWith(isSelf: true))
          ..seed(_bob),
      ),
    );
    expect(find.byKey(const Key('contact-self-badge')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('contact-self-badge')),
        matching: find.text('Me'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('empty repository shows the empty copy', (tester) async {
    await _mount(tester, _repo(InMemoryContactRepository()));
    expect(find.text('No contacts yet'), findsOneWidget);
  });

  testWidgets('seeded contacts render and search filters case-insensitively', (
    tester,
  ) async {
    await _mount(
      tester,
      _repo(
        InMemoryContactRepository()
          ..seed(_ada)
          ..seed(_bob),
      ),
    );
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('Bob Stone'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ADA');
    await tester.pumpAndSettle();
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('Bob Stone'), findsNothing);
  });

  testWidgets('search matches an email and a formatted phone by digits', (
    tester,
  ) async {
    const withEmail = Contact(
      id: 'e',
      contactType: ContactType.person,
      firstName: 'Eve',
      emails: [ContactEmail(label: 'work', address: 'Eve@Example.com')],
    );
    const withPhone = Contact(
      id: 'p',
      contactType: ContactType.person,
      firstName: 'Pat',
      phones: [ContactPhone(label: 'mobile', number: '(555) 010-0')],
    );
    await _mount(
      tester,
      _repo(
        InMemoryContactRepository()
          ..seed(withEmail)
          ..seed(withPhone),
      ),
    );

    await tester.enterText(find.byType(TextField), 'example.COM');
    await tester.pumpAndSettle();
    expect(find.text('Eve'), findsOneWidget);
    expect(find.text('Pat'), findsNothing);

    await tester.enterText(find.byType(TextField), '5550100');
    await tester.pumpAndSettle();
    expect(find.text('Pat'), findsOneWidget);
    expect(find.text('Eve'), findsNothing);
  });

  testWidgets('a non-cloudApi load failure shows a localized message', (
    tester,
  ) async {
    final repo = _ThrowingRepo();
    await _mount(tester, _repo(repo));
    expect(find.text('Could not load contacts'), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing);
  });

  testWidgets('an insurer is listed under Providers, family under Family', (
    tester,
  ) async {
    const insurer = Contact(
      id: 'i',
      contactType: ContactType.organization,
      organizationName: 'Acme Insurance',
      relationship: ContactRelationship(category: RelationshipCategory.insurer),
    );
    const mum = Contact(
      id: 'm',
      contactType: ContactType.person,
      firstName: 'Mum',
      relationship: ContactRelationship(category: RelationshipCategory.parent),
    );
    await _mount(
      tester,
      _repo(
        InMemoryContactRepository()
          ..seed(insurer)
          ..seed(mum),
      ),
    );

    expect(find.text('Providers'), findsOneWidget);
    expect(find.text('Family'), findsOneWidget);
    expect(find.text('Other'), findsNothing);
    final providersY = tester.getTopLeft(find.text('Providers')).dy;
    final insurerY = tester.getTopLeft(find.text('Acme Insurance')).dy;
    final familyY = tester.getTopLeft(find.text('Family')).dy;
    expect(insurerY, greaterThan(providersY));
    expect(providersY, greaterThan(familyY));
    expect(find.text('Insurer'), findsOneWidget);
  });

  testWidgets('cloudApi mode shows the friendly unavailable message', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _mount(tester, [
      dataModeProvider.overrideWith(() => _StubMode(DataMode.cloudApi)),
    ]);
    expect(
      find.textContaining(
        'Contacts are available in Local and Cloud storage modes',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Unimplemented'), findsNothing);
  });

  testWidgets('switching data mode while mounted swaps list and message', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _mount(tester, [
      dataModeProvider.overrideWith(() => _SwitchableMode(DataMode.local)),
      localContactRepositoryProvider.overrideWithValue(
        InMemoryContactRepository()..seed(_ada),
      ),
    ]);
    expect(find.text('Ada Lovelace'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ContactsListScreen)),
    );
    final mode = container.read(dataModeProvider.notifier) as _SwitchableMode;

    mode.switchTo(DataMode.cloudApi);
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'Contacts are available in Local and Cloud storage modes',
      ),
      findsOneWidget,
    );
    expect(find.text('Ada Lovelace'), findsNothing);

    mode.switchTo(DataMode.local);
    await tester.pumpAndSettle();
    expect(find.text('Ada Lovelace'), findsOneWidget);
  });

  testWidgets('has a help button and an add control', (tester) async {
    await _mount(tester, _repo(InMemoryContactRepository()));
    expect(find.byTooltip('Add contact'), findsOneWidget);
    expect(find.byIcon(Icons.help_outline), findsOneWidget);
  });

  testWidgets('a load failure logs the error type, never its text', (
    tester,
  ) async {
    final logs = await _captureLogs(
        () => _mount(tester, _repo(_ThrowingRepo())));
    expect(logs.join('\n'), contains('StateError'));
    expect(logs.join('\n'), isNot(contains('boom')));
  });

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
}

class _ThrowingRepo extends InMemoryContactRepository {
  @override
  Future<List<Contact>> getContacts({bool includeDeactivated = false}) async =>
      throw StateError('boom');
}

/// Captures debugPrint output for [body], restoring it before returning (the
/// widget binding checks debugPrint is unchanged before tear-downs run).
Future<List<String>> _captureLogs(Future<void> Function() body) async {
  final logs = <String>[];
  final saved = debugPrint;
  debugPrint = (String? m, {int? wrapWidth}) => logs.add(m ?? '');
  try {
    await body();
  } finally {
    debugPrint = saved;
  }
  return logs;
}
