import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/core/navigation/contact_routes.dart';
import 'package:hmm_console/core/navigation/route_names.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';
import 'package:hmm_console/features/contacts/presentation/screens/contact_detail_screen.dart';
import 'package:hmm_console/features/contacts/presentation/screens/contact_edit_screen.dart';
import 'package:hmm_console/features/contacts/presentation/screens/contacts_list_screen.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

import '../data/contact_repository_fakes.dart';

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

Future<GoRouter> _mount(WidgetTester tester) async {
  final repo = InMemoryContactRepository()
    ..seed(_ada)
    ..seed(_bob);
  final router = GoRouter(initialLocation: '/contacts', routes: contactRoutes);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [contactRepositoryModeProvider.overrideWithValue(repo)],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _go(WidgetTester tester, GoRouter r, String loc) async {
  r.go(loc);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('contacts lands on the list', (tester) async {
    await _mount(tester);
    expect(find.byType(ContactsListScreen), findsOneWidget);
  });

  testWidgets('contactCreate is create mode, not an id "new"', (tester) async {
    final r = await _mount(tester);
    r.pushNamed(RouterNames.contactCreate.name);
    await tester.pumpAndSettle();
    final edit = tester.widget<ContactEditScreen>(
      find.byType(ContactEditScreen),
    );
    expect(edit.contactId, isNull);
    expect(find.byType(ContactDetailScreen), findsNothing);
  });

  testWidgets('contactDetail and contactEdit carry the id', (tester) async {
    final r = await _mount(tester);
    r.pushNamed(RouterNames.contactDetail.name, pathParameters: {'id': 'a'});
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ContactDetailScreen>(find.byType(ContactDetailScreen))
          .contactId,
      'a',
    );
    r.pushNamed(RouterNames.contactEdit.name, pathParameters: {'id': 'a'});
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ContactEditScreen>(find.byType(ContactEditScreen))
          .contactId,
      'a',
    );
  });

  testWidgets('tapping a list row opens that contact', (tester) async {
    await _mount(tester);
    await tester.tap(find.text('Bob Stone'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ContactDetailScreen>(find.byType(ContactDetailScreen))
          .contactId,
      'b',
    );
  });

  testWidgets('detail page is keyed per contact id', (tester) async {
    final r = await _mount(tester);
    await _go(tester, r, '/contacts/a');
    expect(find.text('Ada Lovelace'), findsWidgets);
    final first = tester.state(find.byType(ContactDetailScreen));
    await _go(tester, r, '/contacts/b');
    expect(find.text('Bob Stone'), findsWidgets);
    expect(find.text('Ada Lovelace'), findsNothing);
    expect(
      identical(first, tester.state(find.byType(ContactDetailScreen))),
      isFalse,
    );
  });

  testWidgets('edit page gets a fresh State per contact id', (tester) async {
    final r = await _mount(tester);
    await _go(tester, r, '/contacts/a/edit');
    expect(find.text('Ada'), findsOneWidget);
    await _go(tester, r, '/contacts/b/edit');
    // A reused State would keep editing Ada.
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Ada'), findsNothing);
  });
}
