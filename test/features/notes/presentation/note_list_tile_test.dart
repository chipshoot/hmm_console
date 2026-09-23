// The subject line is what people scan and what travels to search results,
// so an attached note names its parent there. The parenthetical must never
// be the part that gets ellipsized — a long subject truncates instead.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_list_tile.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

const _general = NoteCatalog(
    id: 1, name: 'General', schema: '{}', formatType: 0, isDefault: false);

HmmNote _note(String subject) => HmmNote(
      id: 1,
      uuid: 'u1',
      subject: subject,
      authorId: 1,
      catalogId: 1,
      createDate: DateTime(2026, 9, 12),
    );

Future<void> _pump(WidgetTester tester, Widget tile) async {
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(extensions: const [AppColors.light]),
    home: Scaffold(body: ListView(children: [tile])),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an attached note names its parent in the title',
      (tester) async {
    await _pump(
      tester,
      NoteListTile(
        note: _note('Oil change receipt'),
        catalog: _general,
        titleContext: '2019 Honda Civic',
        contextLabel: 'Automobile',
        contextColor: Colors.blue,
      ),
    );

    expect(find.text('Oil change receipt'), findsOneWidget);
    expect(find.text(' (2019 Honda Civic)'), findsOneWidget);
    // The secondary line names the domain it now filters under, not the
    // catalog it is stored in.
    expect(find.textContaining('Automobile · '), findsOneWidget);
    expect(find.textContaining('General · '), findsNothing);
  });

  testWidgets('a long subject ellipsizes, the parent stays whole',
      (tester) async {
    await _pump(
      tester,
      NoteListTile(
        note: _note('Replaced the cabin air filter and both wiper blades '
            'plus the pollen filter behind the glovebox'),
        catalog: _general,
        titleContext: '2019 Honda Civic',
        contextLabel: 'Automobile',
        contextColor: Colors.blue,
      ),
    );

    expect(find.text(' (2019 Honda Civic)'), findsOneWidget);
    final subject = tester.widget<Text>(find.textContaining('Replaced the'));
    expect(subject.overflow, TextOverflow.ellipsis);
  });

  testWidgets('an unattached note renders as before', (tester) async {
    await _pump(
      tester,
      NoteListTile(note: _note('Buy milk'), catalog: _general),
    );

    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.textContaining(' ('), findsNothing);
    expect(find.textContaining('General · '), findsOneWidget);
  });
}
