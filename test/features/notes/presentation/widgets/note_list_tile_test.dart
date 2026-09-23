import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/core/widgets/app_list_row.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_list_tile.dart';

const _general = NoteCatalog(
  id: 1,
  name: 'General',
  schema: '{}',
  formatType: 0,
  isDefault: false,
);

HmmNote _note({String? subject, String? content}) => HmmNote(
  id: 1,
  uuid: 'u1',
  subject: subject ?? 'Grocery list',
  authorId: 1,
  createDate: DateTime(2026, 6, 1),
  content: content,
);

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,

  theme: ThemeData(extensions: const [AppColors.light]),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('renders subject as title and content preview as primary', (
    t,
  ) async {
    await t.pumpWidget(
      _host(NoteListTile(note: _note(content: 'Milk, eggs, coffee'))),
    );
    expect(find.byType(AppListRow), findsOneWidget);
    expect(find.text('Grocery list'), findsOneWidget);
    expect(find.text('Milk, eggs, coffee'), findsOneWidget);
  });

  testWidgets('JSON content shows no primary preview line', (t) async {
    await t.pumpWidget(
      _host(NoteListTile(note: _note(content: '{"make":"Toyota"}'))),
    );
    expect(find.text('{"make":"Toyota"}'), findsNothing);
    expect(find.text('Grocery list'), findsOneWidget);
  });

  testWidgets('tap fires onTap', (t) async {
    var tapped = false;
    await t.pumpWidget(
      _host(
        NoteListTile(
          note: _note(content: 'hi'),
          onTap: () => tapped = true,
        ),
      ),
    );
    await t.tap(find.byType(AppListRow));
    expect(tapped, isTrue);
  });

  // The subject line is what people scan and what travels to search results,
  // so an attached note names its parent there. The parenthetical must never
  // be the part that gets ellipsized — a long subject truncates instead.

  testWidgets('an attached note names its parent in the title', (t) async {
    await t.pumpWidget(
      _host(
        NoteListTile(
          note: _note(subject: 'Oil change receipt'),
          catalog: _general,
          titleContext: '2019 Honda Civic',
          contextLabel: 'Automobile',
          contextColor: Colors.blue,
        ),
      ),
    );

    expect(find.text('Oil change receipt'), findsOneWidget);
    expect(find.text(' (2019 Honda Civic)'), findsOneWidget);
    // The secondary line names the domain it now filters under, not the
    // catalog it is stored in.
    expect(find.textContaining('Automobile · '), findsOneWidget);
    expect(find.textContaining('General · '), findsNothing);
  });

  testWidgets('a long subject ellipsizes, the parent stays whole', (t) async {
    await t.pumpWidget(
      _host(
        NoteListTile(
          note: _note(
            subject:
                'Replaced the cabin air filter and both wiper blades '
                'plus the pollen filter behind the glovebox',
          ),
          catalog: _general,
          titleContext: '2019 Honda Civic',
          contextLabel: 'Automobile',
          contextColor: Colors.blue,
        ),
      ),
    );

    expect(find.text(' (2019 Honda Civic)'), findsOneWidget);
    final subject = t.widget<Text>(find.textContaining('Replaced the'));
    expect(subject.overflow, TextOverflow.ellipsis);
  });

  testWidgets(
    'a long subject and context do not overflow at large Dynamic Type',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(extensions: const [AppColors.light]),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SizedBox(
                width: 320,
                child: NoteListTile(
                  note: _note(
                    subject:
                        'Replaced the cabin air filter and both wiper '
                        'blades plus the pollen filter behind the glovebox',
                  ),
                  catalog: _general,
                  titleContext:
                      'A very long parent subject that keeps going and going',
                  contextLabel: 'Automobile',
                  contextColor: Colors.blue,
                ),
              ),
            ),
          ),
        ),
      );

      expect(t.takeException(), isNull);
    },
  );

  testWidgets('an unattached note renders as before', (t) async {
    await t.pumpWidget(
      _host(
        NoteListTile(
          note: _note(subject: 'Buy milk'),
          catalog: _general,
        ),
      ),
    );

    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.textContaining(' ('), findsNothing);
    expect(find.textContaining('General · '), findsOneWidget);
  });
}
