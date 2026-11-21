import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/cheatsheet/data/cheatsheet_launcher.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_source.dart';
import 'package:hmm_console/features/contacts/data/contact_codec.dart';
import 'package:hmm_console/features/contacts/data/i_contact_repository.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact_birthday.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact_field.dart';
import 'package:hmm_console/features/contacts/presentation/screens/contact_detail_screen.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

import '../data/contact_repository_fakes.dart';

const _doc = Contact(
  id: 'd1',
  contactType: ContactType.person,
  firstName: 'Dana',
  lastName: 'Reyes',
  relationship: ContactRelationship(category: RelationshipCategory.doctor),
  phones: [ContactPhone(label: 'mobile', number: '(604) 555-0100')],
  emails: [ContactEmail(label: 'work', address: 'dana@clinic.example')],
  addresses: [ContactAddress(label: 'work', value: '1 Main St, Vancouver')],
  notes: 'Family doctor',
);

Future<InMemoryContactRepository> _mount(
  WidgetTester tester, {
  required String id,
  Contact? seed,
  List<(ValueAction, String)>? launched,
  List<String>? edits,
  InMemoryContactRepository? repository,
  Object? launchError,
}) async {
  final repo = repository ?? InMemoryContactRepository();
  if (seed != null) repo.seed(seed);
  final List<Override> overrides = [
    contactRepositoryModeProvider.overrideWithValue(repo),
    launchActionProvider.overrideWithValue((a, v) async {
      if (launchError != null) throw launchError;
      launched?.add((a, v));
    }),
    contactEditProvider.overrideWithValue((ctx, cid) => edits?.add(cid)),
  ];
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Navigator(
          pages: [
            const MaterialPage(child: Scaffold(body: Text('list'))),
            MaterialPage(child: ContactDetailScreen(contactId: id)),
          ],
          onDidRemovePage: (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  birthdayTests();
  testWidgets('shows the English name when set', (tester) async {
    await _mount(
      tester,
      id: 'z1',
      seed: const Contact(
        id: 'z1',
        contactType: ContactType.person,
        lastName: '王',
        firstName: '小明',
        englishName: 'Michael Wang',
      ),
    );
    expect(find.text('Michael Wang'), findsOneWidget);
    expect(find.text('English name'), findsOneWidget);
  });

  testWidgets('shows no English name row when there is none', (tester) async {
    await _mount(tester, id: 'd1', seed: _doc);
    expect(find.text('English name'), findsNothing);
  });

  testWidgets('renders name, relationship and labelled fields', (tester) async {
    await _mount(tester, id: 'd1', seed: _doc);
    expect(find.text('Dana Reyes'), findsOneWidget);
    expect(find.text('Doctor'), findsOneWidget);
    expect(find.text('Mobile'), findsOneWidget);
    expect(find.text('mobile'), findsNothing);
    expect(find.text('(604) 555-0100'), findsOneWidget);
    expect(find.text('Work'), findsNWidgets(2));
    expect(find.text('dana@clinic.example'), findsOneWidget);
    expect(find.text('1 Main St, Vancouver'), findsOneWidget);
    expect(find.text('Family doctor'), findsOneWidget);
  });

  testWidgets('empty sections are skipped', (tester) async {
    await _mount(
      tester,
      id: 'x',
      seed: const Contact(
        id: 'x',
        contactType: ContactType.person,
        firstName: 'Solo',
      ),
    );
    expect(find.text('Phones'), findsNothing);
    expect(find.text('Emails'), findsNothing);
    expect(find.text('Addresses'), findsNothing);
    expect(find.text('Notes'), findsNothing);
  });

  testWidgets('phone tap launches a call', (tester) async {
    final launched = <(ValueAction, String)>[];
    await _mount(tester, id: 'd1', seed: _doc, launched: launched);
    await tester.tap(find.text('(604) 555-0100'));
    await tester.pumpAndSettle();
    expect(launched, [(ValueAction.call, '(604) 555-0100')]);
  });

  testWidgets('address tap opens maps', (tester) async {
    final launched = <(ValueAction, String)>[];
    await _mount(tester, id: 'd1', seed: _doc, launched: launched);
    await tester.tap(find.text('1 Main St, Vancouver'));
    await tester.pumpAndSettle();
    expect(launched, [(ValueAction.map, '1 Main St, Vancouver')]);
  });

  testWidgets('a structured address shows its lines; tap maps the value', (
    tester,
  ) async {
    const value = '1 Main St, Springfield, IL 62701, United States';
    final launched = <(ValueAction, String)>[];
    await _mount(
      tester,
      id: 's1',
      launched: launched,
      seed: const Contact(
        id: 's1',
        contactType: ContactType.person,
        firstName: 'Sam',
        addresses: [
          ContactAddress(
            label: 'home',
            value: value,
            country: 'US',
            street1: '1 Main St',
            city: 'Springfield',
            region: 'IL',
            postalCode: '62701',
          ),
          ContactAddress(label: 'work', value: '10 Downing St\nLondon'),
        ],
      ),
    );
    const lines = '1 Main St\nSpringfield, IL 62701\nUnited States';
    expect(find.text(lines), findsOneWidget);
    expect(find.text(value), findsNothing);
    expect(find.text('10 Downing St\nLondon'), findsOneWidget);
    await tester.tap(find.text(lines));
    await tester.pumpAndSettle();
    expect(launched, [(ValueAction.map, value)]);
  });

  testWidgets('a country with no modelled parts shows the stored value', (
    tester,
  ) async {
    final launched = <(ValueAction, String)>[];
    await _mount(
      tester,
      id: 's2',
      launched: launched,
      seed: ContactCodec.fromMap({
        'id': 's2',
        'contactType': 'person',
        'firstName': 'Sam',
        'addresses': [
          {'label': 'home', 'value': '1 Main St, Springfield', 'country': 'US'},
          {
            'label': 'work',
            'value': '10 Downing St, London',
            'country': 'GB',
            'line1': '10 Downing St',
          },
        ],
      }),
    );
    expect(find.text('1 Main St, Springfield'), findsOneWidget);
    expect(find.text('10 Downing St, London'), findsOneWidget);
    await tester.tap(find.text('10 Downing St, London'));
    await tester.pumpAndSettle();
    expect(launched, [(ValueAction.map, '10 Downing St, London')]);
  });

  testWidgets('unknown id shows not-found', (tester) async {
    await _mount(tester, id: 'nope');
    expect(find.text('This contact no longer exists'), findsOneWidget);
  });

  testWidgets('deactivated contact still renders', (tester) async {
    await _mount(tester, id: 'd1', seed: _doc.copyWith(isActivated: false));
    expect(find.text('Dana Reyes'), findsOneWidget);
    expect(find.text('This contact no longer exists'), findsNothing);
  });

  testWidgets('edit uses the edit navigator with the id', (tester) async {
    final edits = <String>[];
    await _mount(tester, id: 'd1', seed: _doc, edits: edits);
    await tester.tap(find.byTooltip('Edit contact'));
    expect(edits, ['d1']);
  });

  testWidgets('remove deactivates, pops, and Undo restores', (tester) async {
    final repo = await _mount(tester, id: 'd1', seed: _doc);
    await tester.tap(find.byTooltip('Remove contact'));
    await tester.pumpAndSettle();
    expect((await repo.getContact('d1'))!.isActivated, isFalse);
    expect(find.text('Contact removed'), findsOneWidget);
    expect(find.text('list'), findsOneWidget);
    expect(find.text('Dana Reyes'), findsNothing);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect((await repo.getContact('d1'))!.isActivated, isTrue);
    expect(find.text('Contact restored'), findsOneWidget);
  });

  testWidgets('a failed remove says so and stays on the screen', (
    tester,
  ) async {
    final repo = InMemoryContactRepository()
      ..throwOnDeactivate = const ContactNotFound('d1');
    await _mount(tester, id: 'd1', seed: _doc, repository: repo);
    await tester.tap(find.byTooltip('Remove contact'));
    await tester.pumpAndSettle();

    expect(find.text('Could not remove the contact'), findsOneWidget);
    expect(find.text('Contact removed'), findsNothing);
    expect(find.text('Dana Reyes'), findsOneWidget);
  });

  testWidgets('a failed Undo says restore failed', (tester) async {
    final repo = await _mount(tester, id: 'd1', seed: _doc);
    await tester.tap(find.byTooltip('Remove contact'));
    await tester.pumpAndSettle();
    expect(find.text('Contact removed'), findsOneWidget);

    repo.throwOnSave = const ContactNotFound('d1');
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Could not restore the contact'), findsOneWidget);
    expect(find.text('Contact restored'), findsNothing);
  });

  testWidgets('an unreadable contact shows load-failed, not not-found', (
    tester,
  ) async {
    final repo = InMemoryContactRepository()
      ..throwOnGet = const ContactUnreadable('d1');
    await _mount(tester, id: 'd1', repository: repo);
    expect(find.text('Could not load contacts'), findsOneWidget);
    expect(find.text('This contact no longer exists'), findsNothing);
  });

  testWidgets('a launch that throws an Error still shows the failure', (
    tester,
  ) async {
    await _mount(
      tester,
      id: 'd1',
      seed: _doc,
      launchError: StateError('(604) 555-0100'),
    );

    // Restored inside the body: the widget binding checks debugPrint is
    // unchanged before tear-downs run.
    final logs = <String>[];
    final saved = debugPrint;
    debugPrint = (String? m, {int? wrapWidth}) => logs.add(m ?? '');
    try {
      await tester.tap(find.text('(604) 555-0100'));
      await tester.pumpAndSettle();
    } finally {
      debugPrint = saved;
    }

    expect(find.text("Could not open that."), findsOneWidget);
    expect(logs.join('\n'), isNot(contains('555-0100')));
  });

  testWidgets('a Chinese name is shown family-first in the title', (
    tester,
  ) async {
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
}

void birthdayTests() {
  const base = Contact(
    id: 'b1',
    contactType: ContactType.person,
    firstName: 'Bea',
  );

  testWidgets('detail: no birthday → no Remind me switch', (tester) async {
    await _mount(tester, id: 'b1', seed: base);
    expect(find.byKey(const Key('contact-remind')), findsNothing);
  });

  testWidgets('detail: Remind me on saves remindBirthday true; Undo restores '
      'false', (tester) async {
    final repo = await _mount(
      tester,
      id: 'b1',
      seed: base.copyWith(
        birthday: const ContactBirthday(
          calendar: BirthdayCalendar.gregorian,
          month: 3,
          day: 4,
        ),
      ),
    );
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect((await repo.getContact('b1'))!.remindBirthday, isTrue);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect((await repo.getContact('b1'))!.remindBirthday, isFalse);
  });

  testWidgets('detail: lunar birthday shows 闰四月初五 and the next date', (
    tester,
  ) async {
    await _mount(
      tester,
      id: 'b1',
      seed: base.copyWith(
        birthday: const ContactBirthday(
          calendar: BirthdayCalendar.lunar,
          month: 4,
          day: 5,
          leap: true,
        ),
      ),
    );
    expect(find.textContaining('闰四月初五'), findsOneWidget);
    expect(find.textContaining('next '), findsOneWidget);
  });
}
