import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/core/network/pagination.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_source.dart';
import 'package:hmm_console/features/cheatsheet/presentation/widgets/source_picker.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';

/// Pages exactly the way the real repository does, so "no silent cap" is
/// actually exercised rather than assumed.
class _FakeNotes implements IHmmNoteRepository {
  _FakeNotes(this._all);

  final List<HmmNote> _all;

  @override
  Future<PageList<HmmNote>> getNotes({
    int? catalogId,
    int? parentNoteId,
    int page = 1,
    int pageSize = 20,
    bool includeDeleted = false,
  }) async {
    final start = (page - 1) * pageSize;
    final items = start >= _all.length
        ? <HmmNote>[]
        : _all.skip(start).take(pageSize).toList();
    return PageList(
      items: items,
      meta: PaginationMeta(
        totalCount: _all.length,
        pageSize: pageSize,
        currentPage: page,
        totalPages: (_all.length / pageSize).ceil(),
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not faked');
}

HmmNote note(
  int id, {
  required String subject,
  String? content,
  String? description,
}) =>
    HmmNote(
      id: id,
      uuid: 'uuid-$id',
      subject: subject,
      authorId: 1,
      createDate: DateTime(2026),
      content: content,
      description: description,
    );

final autoNote = note(
  1,
  subject: 'My Car',
  content: '{"note":{"content":{"AutomobileInfo":{"plate":"ABC123",'
      '"vin":"1HG","id":7,"createdDate":"2026-01-01"}}}}',
);

final docNote = note(
  2,
  subject: 'Vim Notes',
  description: '# Title\nintro\n## Shortcuts\n- dd delete line\n',
);

void main() {
  Future<CheatsheetSource? Function()> mount(
    WidgetTester tester,
    List<HmmNote> notes,
  ) async {
    CheatsheetSource? picked;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hmmNoteRepositoryProvider.overrideWithValue(_FakeNotes(notes)),
        ],
        child: MaterialApp(
          home: Scaffold(body: SourcePicker(onSelected: (s) => picked = s)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return () => picked;
  }

  testWidgets('lists the notes to choose from', (tester) async {
    await mount(tester, [autoNote, docNote]);

    expect(find.text('My Car'), findsOneWidget);
    expect(find.text('Vim Notes'), findsOneWidget);
  });

  testWidgets('search filters notes case-insensitively', (tester) async {
    await mount(tester, [autoNote, docNote]);

    await tester.enterText(find.byKey(const Key('source-picker-search')), 'vim');
    await tester.pumpAndSettle();

    expect(find.text('Vim Notes'), findsOneWidget);
    expect(find.text('My Car'), findsNothing);
  });

  testWidgets('notes past the first page are reachable — no silent cap',
      (tester) async {
    // 250 notes against the picker's 100-per-page fetch: three real pages, so
    // a picker that took only the first would lose 150 of them.
    final many = [for (var i = 1; i <= 250; i++) note(i, subject: 'Note $i')];
    await mount(tester, many);

    // Search by key, not by text: the search field itself renders the query,
    // so find.text would match the field as well as the row.
    await tester.enterText(
        find.byKey(const Key('source-picker-search')), 'Note 250');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('source-note-uuid-250')), findsOneWidget);
  });

  testWidgets('picking a field returns a field source', (tester) async {
    final picked = await mount(tester, [autoNote, docNote]);

    await tester.tap(find.text('My Car'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AutomobileInfo.plate'));
    await tester.pumpAndSettle();

    expect(picked(), isNotNull);
    expect(picked()!.noteUuid, 'uuid-1');
    expect(picked()!.kind, SourceGranularity.field);
    expect(picked()!.locator, 'AutomobileInfo.plate');
  });

  testWidgets('internal and audit keys are not offered as fields',
      (tester) async {
    await mount(tester, [autoNote]);

    await tester.tap(find.text('My Car'));
    await tester.pumpAndSettle();

    expect(find.text('AutomobileInfo.plate'), findsOneWidget);
    expect(find.text('AutomobileInfo.id'), findsNothing);
    expect(find.text('AutomobileInfo.createdDate'), findsNothing);
  });

  testWidgets('picking a section returns a section source', (tester) async {
    final picked = await mount(tester, [docNote]);

    await tester.tap(find.text('Vim Notes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shortcuts'));
    await tester.pumpAndSettle();

    expect(picked()!.kind, SourceGranularity.section);
    expect(picked()!.locator, 'Shortcuts');
    expect(picked()!.noteUuid, 'uuid-2');
  });

  testWidgets('whole note is always offered, even with no fields or sections',
      (tester) async {
    final picked = await mount(tester, [note(3, subject: 'Plain')]);

    await tester.tap(find.text('Plain'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('granularity-whole')));
    await tester.pumpAndSettle();

    expect(picked()!.kind, SourceGranularity.whole);
    expect(picked()!.locator, isNull);
  });

  testWidgets('an empty note list shows an empty state, not a blank sheet',
      (tester) async {
    await mount(tester, []);

    expect(find.byKey(const Key('source-picker-empty')), findsOneWidget);
  });
}
