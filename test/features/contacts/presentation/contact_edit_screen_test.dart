import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact_field.dart';
import 'package:hmm_console/features/contacts/states/contacts_state.dart';
import 'package:hmm_console/features/contacts/presentation/screens/contact_edit_screen.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

import '../data/contact_repository_fakes.dart';

const _doc = Contact(
  id: 'd1',
  contactType: ContactType.person,
  firstName: 'Dana',
  lastName: 'Reyes',
  relationship: ContactRelationship(
    category: RelationshipCategory.other,
    customLabel: 'Neighbour',
  ),
  phones: [ContactPhone(label: 'mobile', number: '604-555-0100')],
  notes: 'Family doctor',
);

AppLocalizations get _l => lookupAppLocalizations(const Locale('en'));

Future<InMemoryContactRepository> _mount(
  WidgetTester tester, {
  String? contactId,
  Contact? seed,
  TargetPlatform platform = TargetPlatform.android,
}) async {
  final repo = InMemoryContactRepository();
  if (seed != null) repo.seed(seed);
  await _mountWith(tester, repo, contactId: contactId, platform: platform);
  return repo;
}

Future<void> _mountWith(
  WidgetTester tester,
  InMemoryContactRepository repo, {
  String? contactId,
  TargetPlatform platform = TargetPlatform.android,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [contactRepositoryModeProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Navigator(
          pages: [
            const MaterialPage(child: Scaffold(body: Text('previous'))),
            MaterialPage(child: ContactEditScreen(contactId: contactId)),
          ],
          onDidRemovePage: (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('contact-save')));
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(
    f,
    200,
    scrollable: find.byType(Scrollable).first,
  );
}

void main() {
  testWidgets('create: saves the typed name with a blank id and pops', (
    tester,
  ) async {
    final repo = await _mount(tester);
    await tester.enterText(find.byKey(const Key('contact-first-name')), 'Sam');
    await _save(tester);
    expect(repo.saveCalls, 1);
    final saved = (await repo.getContacts()).single;
    expect(saved.firstName, 'Sam');
    expect(saved.id, startsWith('gen-'), reason: 'blank id sent; repo mints');
    expect(find.byType(ContactEditScreen), findsNothing);
    expect(find.text('previous'), findsOneWidget);
  });

  testWidgets('edit: pre-populates and keeps the id', (tester) async {
    final repo = await _mount(tester, contactId: 'd1', seed: _doc);
    expect(find.text('Dana'), findsOneWidget);
    expect(find.text('Reyes'), findsOneWidget);
    expect(find.text('604-555-0100'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('contact-first-name')), 'Dan');
    await _save(tester);
    final saved = await repo.getContact('d1');
    expect(saved!.firstName, 'Dan');
    expect(saved.lastName, 'Reyes');
    expect(saved.phones.single.number, '604-555-0100');
    expect((await repo.getContacts()).length, 1);
  });

  testWidgets('type toggle swaps person and organization name fields', (
    tester,
  ) async {
    await _mount(tester);
    expect(find.byKey(const Key('contact-first-name')), findsOneWidget);
    expect(find.byKey(const Key('contact-org-name')), findsNothing);
    await tester.tap(find.text(_l.contactTypeOrganization));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('contact-first-name')), findsNothing);
    expect(find.byKey(const Key('contact-last-name')), findsNothing);
    expect(find.byKey(const Key('contact-org-name')), findsOneWidget);
  });

  testWidgets('type toggle works with the Cupertino control on iOS', (
    tester,
  ) async {
    final repo = await _mount(tester, platform: TargetPlatform.iOS);
    await tester.tap(find.text(_l.contactTypeOrganization));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('contact-org-name')), 'Clinic');
    await _save(tester);
    final saved = (await repo.getContacts()).single;
    expect(saved.contactType, ContactType.organization);
    expect(saved.organizationName, 'Clinic');
  });

  testWidgets('add phone appends an empty row; remove drops it', (
    tester,
  ) async {
    await _mount(tester, contactId: 'd1', seed: _doc);
    expect(find.byKey(const Key('phones-value-0')), findsOneWidget);
    expect(find.byKey(const Key('phones-value-1')), findsNothing);
    await _scrollTo(tester, find.text(_l.contactAddPhone));
    await tester.tap(find.text(_l.contactAddPhone));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('phones-value-1')), findsOneWidget);
    await tester.tap(find.byTooltip(_l.contactRemoveFieldTooltip).last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('phones-value-1')), findsNothing);
    expect(find.byKey(const Key('phones-value-0')), findsOneWidget);
  });

  testWidgets('a picked label is stored as the literal, not the display text', (
    tester,
  ) async {
    final repo = await _mount(tester, contactId: 'd1', seed: _doc);
    await _scrollTo(tester, find.byKey(const Key('phones-label-0')));
    await tester.tap(find.byKey(const Key('phones-label-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_l.fieldLabelWork).last);
    await tester.pumpAndSettle();
    await _save(tester);
    expect((await repo.getContact('d1'))!.phones.single.label, 'work');
  });

  testWidgets('blank rows are dropped on save and added rows are kept', (
    tester,
  ) async {
    final repo = await _mount(tester, contactId: 'd1', seed: _doc);
    await _scrollTo(tester, find.text(_l.contactAddEmail));
    await tester.tap(find.text(_l.contactAddEmail));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text(_l.contactAddAddress));
    await tester.tap(find.text(_l.contactAddAddress));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('addresses-value-0')),
      '1 Main St',
    );
    await _save(tester);
    final saved = (await repo.getContact('d1'))!;
    expect(saved.emails, isEmpty);
    expect(saved.addresses.single.value, '1 Main St');
  });

  testWidgets('saving with no name is refused and not sent', (tester) async {
    final repo = await _mount(tester);
    await _save(tester);
    expect(repo.saveCalls, 0);
    expect(find.text(_l.contactNameRequired), findsOneWidget);
    expect(find.byType(ContactEditScreen), findsOneWidget);
  });

  testWidgets('a whitespace-only name is refused', (tester) async {
    final repo = await _mount(tester);
    await tester.enterText(find.byKey(const Key('contact-first-name')), '   ');
    await _save(tester);
    expect(repo.saveCalls, 0);
  });

  testWidgets('toggling isSelf passes isSelf true through', (tester) async {
    final repo = await _mount(tester);
    await tester.enterText(find.byKey(const Key('contact-first-name')), 'Me');
    await _scrollTo(tester, find.byKey(const Key('contact-is-self')));
    expect(find.text(_l.contactIsSelfHint), findsOneWidget);
    await tester.tap(find.byKey(const Key('contact-is-self')));
    await tester.pumpAndSettle();
    await _save(tester);
    expect((await repo.getContacts()).single.isSelf, isTrue);
  });

  testWidgets('switching relationship away from other clears customLabel', (
    tester,
  ) async {
    final repo = await _mount(tester, contactId: 'd1', seed: _doc);
    await _scrollTo(tester, find.byKey(const Key('contact-relationship')));
    expect(find.text('Neighbour'), findsOneWidget);
    await tester.tap(find.byKey(const Key('contact-relationship')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_l.relationshipDoctor).last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('contact-custom-label')), findsNothing);
    await _save(tester);
    final rel = (await repo.getContact('d1'))!.relationship;
    expect(rel.category, RelationshipCategory.doctor);
    expect(rel.customLabel, isNull);
  });

  testWidgets('clearing the notes field clears notes', (tester) async {
    final repo = await _mount(tester, contactId: 'd1', seed: _doc);
    await _scrollTo(tester, find.byKey(const Key('contact-notes')));
    await tester.enterText(find.byKey(const Key('contact-notes')), '');
    await _save(tester);
    expect((await repo.getContact('d1'))!.notes, isNull);
  });

  testWidgets('saving an organization drops the hidden person names',
      (tester) async {
    final repo = await _mount(tester, contactId: 'd1', seed: _doc);
    await tester.tap(find.text(_l.contactTypeOrganization));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('contact-org-name')), 'Clinic');
    await _save(tester);
    final saved = (await repo.getContact('d1'))!;
    expect(saved.organizationName, 'Clinic');
    expect(saved.firstName, isNull);
    expect(saved.lastName, isNull);
  });

  testWidgets('saving a person drops the hidden organization name',
      (tester) async {
    final repo = await _mount(tester);
    await tester.tap(find.text(_l.contactTypeOrganization));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('contact-org-name')), 'Clinic');
    await tester.tap(find.text(_l.contactTypePerson));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('contact-first-name')), 'Sam');
    await _save(tester);
    final saved = (await repo.getContacts()).single;
    expect(saved.firstName, 'Sam');
    expect(saved.organizationName, isNull);
  });

  testWidgets('editing keeps unknown relationship, label and extra fields',
      (tester) async {
    const odd = Contact(
      id: 'o1',
      contactType: ContactType.person,
      firstName: 'Ola',
      relationship: ContactRelationship(rawCategory: 'astronaut'),
      phones: [
        ContactPhone(
          label: 'carrier-pigeon',
          number: '1',
          extraFields: {'ext': '12'},
        ),
      ],
    );
    final repo = await _mount(tester, contactId: 'o1', seed: odd);
    await _scrollTo(tester, find.byKey(const Key('contact-notes')));
    await tester.enterText(find.byKey(const Key('contact-notes')), 'hi');
    await _save(tester);
    final saved = (await repo.getContact('o1'))!;
    expect(saved.notes, 'hi');
    expect(saved.relationship.storedCategoryName, 'astronaut');
    expect(saved.phones.single.label, 'carrier-pigeon');
    expect(saved.phones.single.extraFields, {'ext': '12'});
  });

  testWidgets(
      'the edit session is pinned: a stored change mid-edit does not reset '
      'it, and a tap after a successful save is ignored', (tester) async {
    final repo = await _mount(tester, contactId: 'd1', seed: _doc);
    await tester.enterText(find.byKey(const Key('contact-first-name')), 'Dan');
    // The stored contact changes under the open form.
    repo.seed(_doc.copyWith(lastName: 'Changed'));
    ProviderScope.containerOf(tester.element(find.byType(ContactEditScreen)))
        .invalidate(contactsStateProvider);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('contact-first-name')), findsOneWidget);

    final save = find.byKey(const Key('contact-save'));
    await tester.tap(save);
    await tester.pump();
    await tester.pump();
    await tester.tap(save, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(repo.saveCalls, 1);
    final saved = (await repo.getContact('d1'))!;
    expect(saved.firstName, 'Dan', reason: 'what is on screen is saved');
  });

  testWidgets(
    'a save is not re-entrant: taps while one is in flight are ignored',
    (tester) async {
      final gate = Completer<void>();
      final repo = _GatedRepository(gate);
      await _mountWith(tester, repo);
      await tester.enterText(
        find.byKey(const Key('contact-first-name')),
        'Sam',
      );
      final save = find.byKey(const Key('contact-save'));
      await tester.tap(save);
      await tester.pump();
      await tester.tap(save);
      await tester.pump();
      expect(repo.saveCalls, 1, reason: 'second tap while first is pending');
      gate.complete();
      await tester.pumpAndSettle();
      expect(repo.saveCalls, 1);
      expect((await repo.getContacts()).length, 1);
    },
  );
}

/// Holds saveContact open until [gate] completes, so a second tap lands while
/// the first save is genuinely in flight.
class _GatedRepository extends InMemoryContactRepository {
  _GatedRepository(this.gate);
  final Completer<void> gate;

  @override
  Future<Contact> saveContact(Contact contact) async {
    final result = super.saveContact(contact);
    await gate.future;
    return result;
  }
}
