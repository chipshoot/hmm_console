import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/notes/note_state.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/notes_list_screen.dart';
import 'package:hmm_console/features/notes/query/note_query.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The results provider buckets against the real clock, so every date here is
// relative to now.
final _now = DateTime.now();
final _today = DateTime(_now.year, _now.month, _now.day);
final _yesterday = DateTime(_now.year, _now.month, _now.day - 1, 12);
final _lastMonth = DateTime(_now.year, _now.month - 1, 15);
final _twoMonthsAgo = DateTime(_now.year, _now.month - 2, 3);

HmmNote _note(int id, String subject, DateTime date) => HmmNote(
  id: id,
  uuid: 'u$id',
  subject: subject,
  authorId: 1,
  createDate: date,
);

class _DatedList extends NotesListState {
  @override
  Future<NotesListData> build() async => NotesListData(
    all: [
      _note(1, 'Pinned plan', _lastMonth),
      _note(2, 'Today note', _today),
      for (var i = 0; i < 30; i++) _note(10 + i, 'Yesterday $i', _yesterday),
      _note(3, 'Old note', _twoMonthsAgo),
    ],
    catalogsById: const {},
    statesByUuid: {
      'u1': NoteState(
        noteUuid: 'u1',
        isPinned: true,
        lastModifiedDate: DateTime.utc(2026),
      ),
    },
  );
}

class _LetterList extends NotesListState {
  @override
  Future<NotesListData> build() async => NotesListData(
    all: [
      _note(1, 'banana bread', _today),
      _note(2, 'Apple pie', _yesterday),
      _note(3, 'Avocado', _twoMonthsAgo),
    ],
    catalogsById: const {},
    query: const NoteQuery.initial().copyWith(sort: NoteSort.subjectAZ),
  );
}

/// A 2024 note edited today, listed by last-modified date.
class _EditedList extends NotesListState {
  @override
  Future<NotesListData> build() async => NotesListData(
    all: [
      HmmNote(
        id: 1,
        uuid: 'u1',
        subject: 'Old but edited',
        authorId: 1,
        createDate: DateTime(2024, 3, 4),
        lastModifiedDate: _today.add(const Duration(hours: 9, minutes: 30)),
      ),
    ],
    catalogsById: const {},
    query: const NoteQuery.initial().copyWith(sort: NoteSort.lastModified),
  );
}

Widget _app(NotesListState Function() state, {Locale? locale}) => ProviderScope(
  overrides: [notesListStateProvider.overrideWith(state)],
  child: MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(extensions: const [AppColors.light]),
    home: const NotesListScreen(),
  ),
);

double _top(WidgetTester t, String text) => t.getTopLeft(find.text(text)).dy;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('pinned section first, then date sections with sticky headers', (
    t,
  ) async {
    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await t.pumpWidget(_app(_DatedList.new));
    await t.pumpAndSettle();

    final month = DateFormat.yMMM('en').format(_twoMonthsAgo);
    // Headers in order; the old month is far below, so scroll it into view.
    expect(_top(t, 'Pinned'), lessThan(_top(t, 'Pinned plan')));
    expect(_top(t, 'Pinned plan'), lessThan(_top(t, 'Today')));
    expect(_top(t, 'Today'), lessThan(_top(t, 'Today note')));
    expect(_top(t, 'Today note'), lessThan(_top(t, 'Yesterday')));
    // The pinned note is not repeated in its own month.
    expect(find.text('Pinned plan'), findsOneWidget);
    expect(find.text(DateFormat.yMMM('en').format(_lastMonth)), findsNothing);

    // Scroll into Yesterday's rows: its header sticks; earlier ones are gone.
    await t.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await t.pumpAndSettle();
    expect(find.text('Yesterday').hitTestable(), findsOneWidget);
    expect(
      _top(t, 'Yesterday'),
      lessThan(100),
      reason: 'pinned just under the collapsed top bar',
    );
    expect(find.text('Today').hitTestable(), findsNothing);
    expect(find.text('Pinned').hitTestable(), findsNothing);
    expect(
      _top(t, 'Yesterday'),
      lessThan(_top(t, 'Yesterday 5')),
      reason: 'the header stays above the rows it heads',
    );

    await t.drag(find.byType(CustomScrollView), const Offset(0, -4000));
    await t.pumpAndSettle();
    expect(find.text(month).hitTestable(), findsOneWidget);
    expect(find.text('Old note'), findsOneWidget);
  });

  testWidgets('A–Z sort shows letter headers', (t) async {
    await t.pumpWidget(_app(_LetterList.new));
    await t.pumpAndSettle();

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(_top(t, 'A'), lessThan(_top(t, 'Apple pie')));
    expect(_top(t, 'Avocado'), lessThan(_top(t, 'B')));
    expect(_top(t, 'B'), lessThan(_top(t, 'banana bread')));
    expect(find.text('Today'), findsNothing);
  });

  testWidgets('headers follow the locale', (t) async {
    t.view.physicalSize = const Size(400, 3000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await t.pumpWidget(_app(_DatedList.new, locale: const Locale('zh')));
    await t.pumpAndSettle();

    expect(find.text('置顶'), findsOneWidget);
    expect(find.text('今天'), findsOneWidget);
    expect(find.text('昨天'), findsOneWidget);
    expect(
      find.text('${_twoMonthsAgo.year}年${_twoMonthsAgo.month}月'),
      findsOneWidget,
    );
  });

  testWidgets('last-modified sort: the row shows the date it is grouped by', (
    t,
  ) async {
    await t.pumpWidget(_app(_EditedList.new));
    await t.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    final edited = _today.add(const Duration(hours: 9, minutes: 30));
    expect(find.text(DateFormat.jm('en').format(edited)), findsOneWidget);
    expect(
      find.text(DateFormat.yMd('en').format(DateTime(2024, 3, 4))),
      findsNothing,
    );
  });
}
