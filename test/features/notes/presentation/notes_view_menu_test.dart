import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/settings/app_settings.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/notes_list_screen.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_row.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _List extends NotesListState {
  @override
  Future<NotesListData> build() async => NotesListData(
    all: [
      HmmNote(
        id: 1,
        uuid: 'u1',
        subject: 'Zebra facts',
        authorId: 1,
        createDate: DateTime(2026, 1, 2),
      ),
      HmmNote(
        id: 2,
        uuid: 'u2',
        subject: 'Apple pie',
        authorId: 1,
        createDate: DateTime(2026, 1, 1),
      ),
    ],
    catalogsById: const {},
  );
}

Future<ProviderContainer> _pump(WidgetTester t, TargetPlatform platform) async {
  final container = ProviderContainer(
    overrides: [notesListStateProvider.overrideWith(_List.new)],
  );
  addTearDown(container.dispose);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          platform: platform,
          extensions: const [AppColors.light],
        ),
        home: const NotesListScreen(),
      ),
    ),
  );
  await t.pumpAndSettle();
  return container;
}

Future<void> _openMenu(WidgetTester t) async {
  await t.tap(find.byTooltip('View'));
  await t.pumpAndSettle();
}

double _top(WidgetTester t, String text) => t.getTopLeft(find.text(text)).dy;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      'View menu changes density and sort; density persists (${platform.name})',
      (t) async {
        final container = await _pump(t, platform);
        expect(
          t.widget<NoteRow>(find.byType(NoteRow).first).density,
          NoteRowDensity.standard,
        );

        await _openMenu(t);
        if (platform == TargetPlatform.iOS) {
          expect(find.byType(CupertinoActionSheet), findsOneWidget);
        } else {
          expect(find.byType(BottomSheet), findsOneWidget);
          expect(find.byType(RadioListTile<NoteRowDensity>), findsNWidgets(3));
        }
        expect(find.text('Rows'), findsOneWidget);
        expect(find.text('Sort'), findsOneWidget);
        for (final label in [
          'Compact',
          'Standard',
          'Rich',
          'Date — newest first',
          'Date — oldest first',
          'Last modified',
          'Title — A → Z',
          'Flag colour',
        ]) {
          expect(find.text(label), findsOneWidget, reason: label);
        }

        await t.tap(find.text('Compact'));
        await t.pumpAndSettle();
        expect(find.text('Rows'), findsNothing, reason: 'the menu closed');
        expect(
          t.widget<NoteRow>(find.byType(NoteRow).first).density,
          NoteRowDensity.compact,
        );
        final prefs = await SharedPreferences.getInstance();
        final blob =
            jsonDecode(prefs.getString('app_settings')!)
                as Map<String, dynamic>;
        expect(blob['notesRowDensity'], 'compact');

        // Date order first: Zebra is newer.
        expect(_top(t, 'Zebra facts'), lessThan(_top(t, 'Apple pie')));
        await _openMenu(t);
        await t.tap(find.text('Title — A → Z'));
        await t.pumpAndSettle();
        expect(
          container.read(notesListStateProvider).value!.query.sort,
          NoteSort.subjectAZ,
        );
        expect(_top(t, 'Apple pie'), lessThan(_top(t, 'Zebra facts')));
      },
    );
  }

  testWidgets('iOS menu marks the current density and sort', (t) async {
    await _pump(t, TargetPlatform.iOS);
    await _openMenu(t);
    final checks = find.descendant(
      of: find.byType(CupertinoActionSheet),
      matching: find.byIcon(CupertinoIcons.check_mark),
    );
    expect(checks, findsNWidgets(2));
    // Each check sits in the row of a current value.
    Finder rowWith(String label) =>
        find.ancestor(of: find.text(label), matching: find.byType(Row));
    for (final label in ['Standard', 'Date — newest first']) {
      expect(
        find.descendant(
          of: rowWith(label).first,
          matching: find.byIcon(CupertinoIcons.check_mark),
        ),
        findsOneWidget,
        reason: label,
      );
    }
    expect(
      find.descendant(
        of: rowWith('Compact').first,
        matching: find.byIcon(CupertinoIcons.check_mark),
      ),
      findsNothing,
    );
  });
}
