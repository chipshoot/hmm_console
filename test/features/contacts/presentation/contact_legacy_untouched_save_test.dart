import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/local_contact_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/contacts/data/i_contact_repository.dart';
import 'package:hmm_console/features/contacts/presentation/screens/contact_edit_screen.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

import '../data/contact_repository_fakes.dart';

/// A contact as an older client stored it: display name in the legacy
/// "given family" order, no name-order or phonetic keys.
final _legacy = jsonEncode({
  'note': {
    'content': {
      'Contact': {
        'schemaVersion': 1,
        'displayName': '伟 张',
        'id': 'leg1',
        'contactType': 'person',
        'firstName': '伟',
        'lastName': '张',
        'phones': [
          {'label': 'mobile', 'number': '604-555-0100'},
        ],
        'emails': [
          {'label': 'work', 'address': 'wei@example.com'},
        ],
        'addresses': [
          {
            'label': 'home',
            'value': '1 Main St, Springfield, IL 62701',
            'country': 'US',
            'city': 'Springfield',
            'region': 'IL',
            'postalCode': '62701',
          },
        ],
        'relationship': {'category': 'other', 'customLabel': 'Neighbour'},
        'isSelf': false,
        'isActivated': true,
      },
    },
  },
});

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('legacy contact, open and Save untouched: note content is '
        'byte-identical ($platform)', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final notes = FakeNoteRepository();
      notes.stored.add(
        HmmNote(
          id: 5,
          uuid: 'raw5',
          subject: contactSubjectFor('leg1'),
          authorId: 1,
          createDate: DateTime(2026),
          catalogId: 7,
          content: _legacy,
        ),
      );
      final repo = LocalContactRepository(notes, FakeCatalogRepository());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [contactRepositoryModeProvider.overrideWithValue(repo)],
          child: MaterialApp(
            theme: ThemeData(platform: platform),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Navigator(
              pages: const [
                MaterialPage(child: Scaffold(body: Text('previous'))),
                MaterialPage(child: ContactEditScreen(contactId: 'leg1')),
              ],
              onDidRemovePage: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // The form really loaded the stored contact.
      expect(find.text('伟'), findsWidgets);
      await tester.tap(find.byKey(const Key('contact-save')));
      await tester.pumpAndSettle();

      // A successful save pops the screen.
      expect(find.byType(ContactEditScreen), findsNothing);
      expect(notes.stored, hasLength(1));
      expect(notes.stored.single.content, _legacy);
    });
  }
}
