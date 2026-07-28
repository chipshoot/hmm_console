import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/cheatsheet/data/cheatsheet_launcher.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_row.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_source.dart';
import 'package:hmm_console/features/cheatsheet/presentation/screens/cheatsheet_detail_screen.dart';
import 'package:hmm_console/features/cheatsheet/states/cheatsheets_state.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';

/// The real resolver and extractor run against these — only the note store is
/// faked, so resolution is genuinely exercised rather than stubbed out.
class _FakeNotes implements IHmmNoteRepository {
  _FakeNotes(this._byUuid);

  final Map<String, HmmNote> _byUuid;

  @override
  Future<HmmNote?> getNoteByUuid(String uuid) async => _byUuid[uuid];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not faked');
}

class _SeededCheatsheets extends CheatsheetsState {
  static List<CheatsheetCard> seed = const [];

  @override
  Future<List<CheatsheetCard>> build() async => seed;
}

final autoNote = HmmNote(
  id: 1,
  uuid: 'auto1',
  subject: 'My Car',
  authorId: 1,
  createDate: DateTime(2026),
  content: '{"note":{"content":{"AutomobileInfo":{"plate":"ABC123",'
      '"phone":"(555) 123-4567","address":"1 Main St"}}}}',
);

final docNote = HmmNote(
  id: 2,
  uuid: 'doc1',
  subject: 'Vim Notes',
  authorId: 1,
  createDate: DateTime(2026),
  description: '# Title\nintro\n## Shortcuts\n- dd delete line\n',
);

const card = CheatsheetCard(
  id: 'c1',
  title: 'Claim',
  walletGroup: 'Vehicle',
  tags: [],
  templateId: 'blank',
  rows: [
    CheatsheetRow(
      label: 'Plate',
      source: CheatsheetSource(
        noteUuid: 'auto1',
        kind: SourceGranularity.field,
        locator: 'AutomobileInfo.plate',
      ),
    ),
    CheatsheetRow(
      label: 'Gone',
      source: CheatsheetSource(
        noteUuid: 'missing-uuid',
        kind: SourceGranularity.whole,
      ),
    ),
    CheatsheetRow(label: 'Nothing yet', source: null),
    CheatsheetRow(
      label: 'Phone',
      source: CheatsheetSource(
        noteUuid: 'auto1',
        kind: SourceGranularity.field,
        locator: 'AutomobileInfo.phone',
      ),
      valueAction: ValueAction.call,
    ),
    CheatsheetRow(
      label: 'Address',
      source: CheatsheetSource(
        noteUuid: 'auto1',
        kind: SourceGranularity.field,
        locator: 'AutomobileInfo.address',
      ),
      valueAction: ValueAction.map,
    ),
    CheatsheetRow(
      label: 'Shortcuts',
      source: CheatsheetSource(
        noteUuid: 'doc1',
        kind: SourceGranularity.section,
        locator: 'Shortcuts',
      ),
    ),
  ],
);

void main() {
  setUp(() => _SeededCheatsheets.seed = const [card]);

  Future<
      ({
        List<(ValueAction, String)> launched,
        List<String> openedSources,
        List<String> edited,
      })> mount(
    WidgetTester tester, {
    bool launchFails = false,
  }) async {
    final launched = <(ValueAction, String)>[];
    final openedSources = <String>[];
    final edited = <String>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hmmNoteRepositoryProvider.overrideWithValue(
            _FakeNotes({'auto1': autoNote, 'doc1': docNote}),
          ),
          cheatsheetsStateProvider.overrideWith(_SeededCheatsheets.new),
          launchActionProvider.overrideWithValue((action, value) async {
            launched.add((action, value));
            if (launchFails) throw LaunchActionException(Uri.parse('tel:x'));
          }),
          cheatsheetOpenSourceProvider
              .overrideWithValue((_, uuid) => openedSources.add(uuid)),
          cheatsheetEditCardProvider.overrideWithValue((_, id) => edited.add(id)),
        ],
        child: const MaterialApp(home: CheatsheetDetailScreen(cardId: 'c1')),
      ),
    );
    await tester.pumpAndSettle();
    return (launched: launched, openedSources: openedSources, edited: edited);
  }

  testWidgets('renders resolved values, placeholders and section text',
      (tester) async {
    await mount(tester);

    expect(find.text('ABC123'), findsOneWidget);
    expect(find.textContaining('dd delete line'), findsOneWidget);
    expect(find.byKey(const Key('row-2-unbound')), findsOneWidget);
    expect(find.byKey(const Key('row-1-missing')), findsOneWidget);
  });

  testWidgets('a call value launches a tel action', (tester) async {
    final r = await mount(tester);

    await tester.tap(find.byKey(const Key('row-3-value')));
    await tester.pumpAndSettle();

    expect(r.launched, [(ValueAction.call, '(555) 123-4567')]);
  });

  testWidgets('a map value launches a maps action', (tester) async {
    final r = await mount(tester);

    await tester.tap(find.byKey(const Key('row-4-value')));
    await tester.pumpAndSettle();

    expect(r.launched, [(ValueAction.map, '1 Main St')]);
  });

  testWidgets('a row with no action is not tappable', (tester) async {
    final r = await mount(tester);

    await tester.tap(find.byKey(const Key('row-0-value')));
    await tester.pumpAndSettle();

    expect(r.launched, isEmpty);
  });

  testWidgets('open-source navigates by the row source uuid', (tester) async {
    final r = await mount(tester);

    await tester.tap(find.byKey(const Key('row-0-open-source')));
    await tester.pumpAndSettle();

    expect(r.openedSources, ['auto1']);
  });

  testWidgets('a launch failure shows a message and does not crash',
      (tester) async {
    await mount(tester, launchFails: true);

    await tester.tap(find.byKey(const Key('row-3-value')));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the edit action targets this card', (tester) async {
    final r = await mount(tester);

    await tester.tap(find.byKey(const Key('detail-edit')));
    await tester.pumpAndSettle();

    expect(r.edited, ['c1']);
  });

  testWidgets('an unknown card shows a not-found state', (tester) async {
    _SeededCheatsheets.seed = const [];
    await mount(tester);

    expect(find.byKey(const Key('detail-not-found')), findsOneWidget);
  });
}
