import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/cheatsheet/data/cheatsheet_launcher.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_source.dart';
import 'package:hmm_console/features/contacts/data/i_contact_repository.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';
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
}) async {
  final repo = repository ?? InMemoryContactRepository();
  if (seed != null) repo.seed(seed);
  final List<Override> overrides = [
    contactRepositoryModeProvider.overrideWithValue(repo),
    launchActionProvider.overrideWithValue((a, v) async {
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

  testWidgets('a failed remove says so and stays on the screen',
      (tester) async {
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

  testWidgets('an unreadable contact shows load-failed, not not-found',
      (tester) async {
    final repo = InMemoryContactRepository()
      ..throwOnGet = const ContactUnreadable('d1');
    await _mount(tester, id: 'd1', repository: repo);
    expect(find.text('Could not load contacts'), findsOneWidget);
    expect(find.text('This contact no longer exists'), findsNothing);
  });
}
