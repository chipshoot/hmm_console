import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_link_picker.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';

class _StubListState extends NotesListState {
  @override
  Future<NotesListData> build() async => NotesListData(
    all: [
      HmmNote(
        id: 1,
        uuid: 'u1',
        subject: 'A',
        authorId: 1,
        createDate: DateTime(2026, 1, 1),
      ),
      HmmNote(
        id: 2,
        uuid: 'u2',
        subject: 'B',
        authorId: 1,
        createDate: DateTime(2026, 1, 1),
      ),
      HmmNote(
        id: 3,
        uuid: 'u3',
        subject: 'C',
        authorId: 1,
        createDate: DateTime(2026, 1, 1),
      ),
    ],
    catalogsById: const {},
  );
}

/// Never completes — keeps the provider in AsyncLoading.
class _LoadingListState extends NotesListState {
  @override
  Future<NotesListData> build() => Completer<NotesListData>().future;
}

/// Throws — puts the provider into AsyncError.
class _ErrorListState extends NotesListState {
  @override
  Future<NotesListData> build() async => throw StateError('boom');
}

class _Harness extends ConsumerWidget {
  const _Harness({required this.onResult, this.excludeNoteId});
  final ValueChanged<HmmNote?> onResult;
  final int? excludeNoteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            final note = await showNoteLinkPicker(
              context,
              ref,
              excludeNoteId: excludeNoteId,
            );
            onResult(note);
          },
          child: const Text('Open picker'),
        ),
      ),
    );
  }
}

Future<void> _pump(
  WidgetTester tester, {
  ValueChanged<HmmNote?>? onResult,
  int? excludeNoteId,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [notesListStateProvider.overrideWith(_StubListState.new)],
      child: MaterialApp(
        home: _Harness(
          onResult: onResult ?? (_) {},
          excludeNoteId: excludeNoteId,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open picker'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists all notes and filters by search query', (tester) async {
    await _pump(tester);

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'B');
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'A'), findsNothing);
    expect(find.widgetWithText(ListTile, 'B'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'C'), findsNothing);
  });

  testWidgets('tapping a note completes the future with that note', (
    tester,
  ) async {
    HmmNote? picked;
    await _pump(tester, onResult: (n) => picked = n);

    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();

    expect(picked, isNotNull);
    expect(picked!.uuid, 'u2');
    expect(picked!.subject, 'B');
  });

  testWidgets('excludeNoteId hides that note from the list', (tester) async {
    await _pump(tester, excludeNoteId: 2);

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsNothing);
    expect(find.text('C'), findsOneWidget);
  });

  testWidgets('shows a spinner while the notes list is loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [notesListStateProvider.overrideWith(_LoadingListState.new)],
        child: const MaterialApp(home: _Harness(onResult: _noop)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open picker'));
    // Don't settle: the provider never resolves and the spinner animates.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('shows an error message when the notes list fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [notesListStateProvider.overrideWith(_ErrorListState.new)],
        child: const MaterialApp(home: _Harness(onResult: _noop)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load notes"), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });
}

void _noop(HmmNote? _) {}
