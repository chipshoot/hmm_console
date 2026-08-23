import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/core/network/pagination.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_source.dart';
import 'package:hmm_console/features/cheatsheet/presentation/widgets/source_picker.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';

/// Pages exactly the way the real repository does, so "no silent cap" is
/// actually exercised rather than assumed.
///
/// Note it does NOT honour `catalogId`, and that is on purpose: the picker
/// deliberately fetches every catalog and ranks afterwards, so a fake that
/// filtered would hide a picker that had quietly gone back to querying one
/// catalog and made out-of-domain notes unreachable again.
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

class _FakeCatalogs implements INoteCatalogRepository {
  @override
  Future<List<NoteCatalog>> getCatalogs() async => [
        for (final e in catalogNames.entries)
          NoteCatalog(
            id: e.key,
            name: e.value,
            schema: '{}',
            formatType: 0,
            isDefault: false,
          ),
      ];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not faked');
}

/// The catalogs as the app really lays them out.
const catalogNames = <int, String>{
  1: 'Hmm.AutomobileMan.AutomobileInfo',
  2: 'Hmm.AutomobileMan.AutoInsurancePolicy',
  4: 'General',
  5: 'Hmm.CheatsheetMan.Cheatsheet',
  6: 'Hmm.System.Subsystem',
};

HmmNote note(
  int id, {
  required String subject,
  String? content,
  String? description,
  int? catalogId,
}) =>
    HmmNote(
      id: id,
      uuid: 'uuid-$id',
      subject: subject,
      authorId: 1,
      createDate: DateTime(2026),
      content: content,
      description: description,
      catalogId: catalogId,
    );

final autoNote = note(
  1,
  subject: 'My Car',
  catalogId: 1,
  content: '{"note":{"content":{"AutomobileInfo":{"plate":"ABC123",'
      '"vin":"1HG","id":7,"createdDate":"2026-01-01"}}}}',
);

final docNote = note(
  2,
  subject: 'Vim Notes',
  catalogId: 4,
  description: '# Title\nintro\n## Shortcuts\n- dd delete line\n',
);

final policyNote = note(3, subject: 'State Farm 4471', catalogId: 2);
final contactNote = note(4, subject: "Dad's contact info", catalogId: 4);
final savedCard = note(5, subject: 'Cheatsheet:abc-123', catalogId: 5);
final anchorNote = note(6, subject: 'Automobile', catalogId: 6);

void main() {
  Future<CheatsheetSource? Function()> mount(
    WidgetTester tester,
    List<HmmNote> notes, {
    String templateId = 'blank',
  }) async {
    CheatsheetSource? picked;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hmmNoteRepositoryProvider.overrideWithValue(_FakeNotes(notes)),
          noteCatalogRepositoryProvider.overrideWithValue(_FakeCatalogs()),
        ],
        child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      
          home: Scaffold(
            body: SourcePicker(
              templateId: templateId,
              onSelected: (s) => picked = s,
            ),
          ),
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
    final many = [
      for (var i = 1; i <= 250; i++) note(i, subject: 'Note $i', catalogId: 4)
    ];
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
    final picked =
        await mount(tester, [note(3, subject: 'Plain', catalogId: 4)]);

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

  group('what the picker offers is scoped to the card', () {
    testWidgets('an accident claim shows vehicle notes under their own heading',
        (tester) async {
      await mount(
        tester,
        [contactNote, autoNote, policyNote],
        templateId: 'accidentClaim',
      );

      expect(find.text('VEHICLE'), findsOneWidget);
      expect(find.text('OTHER NOTES'), findsOneWidget);

      // Ranked, not just labelled: both vehicle notes must sit above the
      // contact note, which is the entire point of the change.
      final vehicleHeading = tester.getTopLeft(find.text('VEHICLE')).dy;
      final otherHeading = tester.getTopLeft(find.text('OTHER NOTES')).dy;
      expect(
          tester.getTopLeft(find.text('My Car')).dy, greaterThan(vehicleHeading));
      expect(tester.getTopLeft(find.text('State Farm 4471')).dy,
          lessThan(otherHeading));
      expect(tester.getTopLeft(find.text("Dad's contact info")).dy,
          greaterThan(otherHeading));
    });

    testWidgets('out-of-domain notes stay bindable, not hidden', (tester) async {
      // The Accident Claim template asks for Driver, Phone and Address, which
      // live in a General note. Hiding them would trade one annoyance for
      // three rows that can never be filled.
      await mount(
        tester,
        [autoNote, contactNote],
        templateId: 'accidentClaim',
      );

      expect(find.text("Dad's contact info"), findsOneWidget);

      await tester.tap(find.text("Dad's contact info"));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('granularity-whole')), findsOneWidget);
    });

    testWidgets('saved cheatsheet cards are never offered as sources',
        (tester) async {
      // Cards are stored as notes under Hmm.CheatsheetMan.Cheatsheet. Before
      // this, every card you saved came back here as something to reference.
      await mount(
        tester,
        [autoNote, savedCard],
        templateId: 'accidentClaim',
      );

      expect(find.text('Cheatsheet:abc-123'), findsNothing);
      expect(find.text('My Car'), findsOneWidget);
    });

    testWidgets('subsystem anchor notes are never offered as sources',
        (tester) async {
      await mount(tester, [docNote, anchorNote], templateId: 'accidentClaim');

      // The anchor's subject is 'Automobile' — indistinguishable from a real
      // note by name alone, which is why this is filtered by catalog.
      expect(find.text('Automobile'), findsNothing);
      expect(find.text('Vim Notes'), findsOneWidget);
    });

    testWidgets(
        'a card with nothing but infrastructure notes shows the empty state',
        (tester) async {
      await mount(tester, [savedCard, anchorNote], templateId: 'accidentClaim');

      expect(find.byKey(const Key('source-picker-empty')), findsOneWidget);
    });

    testWidgets('a template with no domain shows one plain list, no headings',
        (tester) async {
      await mount(tester, [autoNote, docNote], templateId: 'blank');

      expect(find.text('VEHICLE'), findsNothing);
      expect(find.text('OTHER NOTES'), findsNothing);
      expect(find.text('My Car'), findsOneWidget);
      expect(find.text('Vim Notes'), findsOneWidget);
    });

    testWidgets('headings disappear when a search empties one group',
        (tester) async {
      await mount(
        tester,
        [autoNote, contactNote],
        templateId: 'accidentClaim',
      );

      await tester.enterText(
          find.byKey(const Key('source-picker-search')), 'car');
      await tester.pumpAndSettle();

      // Only the vehicle note matches, so 'Other notes' would sit over nothing.
      expect(find.text('My Car'), findsOneWidget);
      expect(find.text('OTHER NOTES'), findsNothing);
    });

    testWidgets('a search matching nothing shows the no-matches state',
        (tester) async {
      await mount(
        tester,
        [autoNote, contactNote],
        templateId: 'accidentClaim',
      );

      await tester.enterText(
          find.byKey(const Key('source-picker-search')), 'zzz');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('source-picker-no-matches')), findsOneWidget);
      expect(find.byKey(const Key('source-picker-empty')), findsNothing);
    });
  });
}
