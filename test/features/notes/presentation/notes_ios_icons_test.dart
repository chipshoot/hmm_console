import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/notes/note_state.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/notes_shell_screen.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _at = DateTime(2026, 1, 1);

class _S extends NotesListState {
  @override
  Future<NotesListData> build() async => NotesListData(
    all: [
      HmmNote(
        id: 1,
        uuid: 'u1',
        subject: 'Pinned one',
        authorId: 1,
        catalogId: 10,
        createDate: _at,
      ),
      HmmNote(
        id: 2,
        uuid: 'u2',
        subject: 'Flagged one',
        authorId: 1,
        catalogId: 10,
        createDate: _at,
      ),
    ],
    catalogsById: const {},
    statesByUuid: {
      'u1': NoteState(noteUuid: 'u1', isPinned: true, lastModifiedDate: _at),
      'u2': NoteState(noteUuid: 'u2', flagColor: 0, lastModifiedDate: _at),
    },
    tagsByNoteId: const {
      1: [(id: 1, name: 'outdoors')],
    },
  );
}

Future<void> _pump(
  WidgetTester t,
  TargetPlatform platform,
  double width,
) async {
  SharedPreferences.setMockInitialValues({});
  t.view.physicalSize = Size(width, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ProviderScope(
      overrides: [notesListStateProvider.overrideWith(_S.new)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          platform: platform,
          extensions: const [AppColors.light],
        ),
        home: const NotesShellScreen(),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets('iPad: the Notes screen uses Apple glyphs', (t) async {
    await _pump(t, TargetPlatform.iOS, 1100);
    for (final icon in [
      CupertinoIcons.line_horizontal_3_decrease_circle, // view & sort
      CupertinoIcons.square_grid_2x2, // note types
      CupertinoIcons.question_circle, // help
      CupertinoIcons.search, // search box
      CupertinoIcons.pin, // side panel: Pinned
      CupertinoIcons.flag, // side panel: Flagged
      CupertinoIcons.trash, // side panel: Recently Deleted
      CupertinoIcons.pin_fill, // row: pinned
      CupertinoIcons.flag_fill, // row: flagged
      CupertinoIcons.tag, // row tags and side panel tags
    ]) {
      expect(find.byIcon(icon), findsWidgets, reason: '$icon');
    }
    for (final icon in [
      Icons.tune,
      Icons.widgets_outlined,
      Icons.help_outline,
      Icons.push_pin_outlined,
      Icons.push_pin,
      Icons.delete_outline,
    ]) {
      expect(find.byIcon(icon), findsNothing, reason: '$icon');
    }
  });

  testWidgets('iPhone: the side-panel button is three thin lines', (t) async {
    await _pump(t, TargetPlatform.iOS, 400);
    expect(find.byIcon(CupertinoIcons.line_horizontal_3), findsOneWidget);
    expect(find.byIcon(Icons.menu), findsNothing);
  });

  testWidgets('Android keeps the Material icons', (t) async {
    await _pump(t, TargetPlatform.android, 1100);
    expect(find.byIcon(Icons.tune), findsOneWidget);
    expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.pin), findsNothing);
  });
}
