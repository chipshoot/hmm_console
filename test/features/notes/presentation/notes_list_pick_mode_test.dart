import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_picker.dart';
import 'package:hmm_console/features/notes/presentation/screens/notes_list_screen.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppLocalizations get _l => lookupAppLocalizations(const Locale('en'));

HmmNote _note(int id, String subject) => HmmNote(
  id: id,
  uuid: 'u$id',
  subject: subject,
  authorId: 1,
  createDate: DateTime.now(),
);

class _List extends NotesListState {
  @override
  Future<NotesListData> build() async => NotesListData(
    all: [_note(1, 'Family doctor'), _note(2, 'Cheatsheet:card')],
    catalogsById: const {},
  );
}

/// A Notes list that has not finished loading (or is paused offstage).
class _Loading extends NotesListState {
  @override
  Future<NotesListData> build() => Completer<NotesListData>().future;
}

Widget _app(Widget home, {NotesListState Function() list = _List.new}) =>
    ProviderScope(
      overrides: [notesListStateProvider.overrideWith(list)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(extensions: const [AppColors.light]),
        home: home,
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('in pick mode a tap picks the note; editing actions are gone', (
    t,
  ) async {
    final picked = <HmmNote>[];
    await t.pumpWidget(_app(NotesListScreen(onPick: picked.add)));
    await t.pumpAndSettle();

    expect(find.text(_l.notesPickTitle), findsWidgets);
    expect(find.byTooltip(_l.notesSubsystemsTitle), findsNothing);
    await t.tap(find.text('Family doctor'));
    await t.pumpAndSettle();
    expect(picked.map((n) => n.id), [1]);
  });

  testWidgets('notes canPick refuses are not offered', (t) async {
    await t.pumpWidget(
      _app(
        NotesListScreen(
          onPick: (_) {},
          canPick: (n, _) => !n.subject.startsWith('Cheatsheet:'),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Family doctor'), findsOneWidget);
    expect(find.text('Cheatsheet:card'), findsNothing);
  });

  testWidgets('the picker returns the note and puts the Notes search back', (
    t,
  ) async {
    HmmNote? result;
    late WidgetRef outer;
    await t.pumpWidget(
      _app(
        Consumer(
          builder: (context, ref, _) {
            outer = ref;
            return Scaffold(
              body: TextButton(
                onPressed: () async => result = await showNotePicker(context),
                child: const Text('pick'),
              ),
            );
          },
        ),
      ),
    );
    await t.pumpAndSettle();
    await outer.read(notesListStateProvider.future);
    outer.read(notesListStateProvider.notifier).setText('');

    await t.tap(find.text('pick'));
    await t.pumpAndSettle();
    // Searching inside the picker changes the shared Notes query...
    outer.read(notesListStateProvider.notifier).setText('family');
    await t.pumpAndSettle();
    await t.tap(find.text('Family doctor'));
    await t.pumpAndSettle();

    expect(result?.id, 1);
    // ...and leaving restores what the Notes screen had.
    expect(outer.read(notesListStateProvider).value?.query.text, '');
  });

  testWidgets('the picker opens even while the Notes list is still loading', (
    t,
  ) async {
    // On the device the Notes list can be offstage and paused, so its data
    // never arrives until a screen shows it. Waiting for it before opening
    // the picker meant tapping "Tap to bind" did nothing.
    await t.pumpWidget(
      _app(
        list: _Loading.new,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showNotePicker(context),
              child: const Text('pick'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('pick'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byType(NotesListScreen), findsOneWidget);
  });
}
