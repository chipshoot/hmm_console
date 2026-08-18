import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_row.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_source.dart';
import 'package:hmm_console/features/cheatsheet/presentation/screens/cheatsheet_designer_screen.dart';
import 'package:hmm_console/features/cheatsheet/states/cheatsheet_editor_state.dart';
import 'package:hmm_console/features/cheatsheet/states/cheatsheets_state.dart';

const _source = CheatsheetSource(
  noteUuid: 'auto1',
  kind: SourceGranularity.field,
  locator: 'AutomobileInfo.plate',
);

/// Seeds the wallet and records what the designer commits.
class _CapturingCheatsheets extends CheatsheetsState {
  static List<CheatsheetCard> seed = const [];
  static final saved = <CheatsheetCard>[];

  @override
  Future<List<CheatsheetCard>> build() async => seed;

  @override
  Future<void> save(CheatsheetCard card) async => saved.add(card);
}

const existingCard = CheatsheetCard(
  id: 'existing-id',
  title: 'Original',
  walletGroup: 'Vehicle',
  tags: ['legal'],
  templateId: 'accidentClaim',
  rows: [
    CheatsheetRow(label: 'Plate', source: _source),
    CheatsheetRow(label: 'VIN', source: null),
  ],
);

void main() {
  setUp(() {
    _CapturingCheatsheets.seed = const [];
    _CapturingCheatsheets.saved.clear();
  });

  /// The templateId the screen last handed the picker. The picker ranks notes
  /// by it, so a screen that passed the wrong one — or a constant — would look
  /// entirely correct here while offering the wrong notes in the real app.
  String? lastPickerTemplateId;

  Future<void> mount(
    WidgetTester tester, {
    String? cardId,
    CheatsheetSource? pickerResult,
  }) async {
    lastPickerTemplateId = null;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cheatsheetIdGenProvider.overrideWithValue(() => 'new-id'),
          cheatsheetsStateProvider.overrideWith(_CapturingCheatsheets.new),
          cheatsheetSourcePickerProvider.overrideWithValue(
            (_, {required templateId}) async {
              lastPickerTemplateId = templateId;
              return pickerResult;
            },
          ),
        ],
        child: MaterialApp(home: CheatsheetDesignerScreen(cardId: cardId)),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('create', () {
    testWidgets('offers the templates, then shows unbound labelled rows',
        (tester) async {
      await mount(tester);

      expect(find.byKey(const Key('template-accidentClaim')), findsOneWidget);

      await tester.tap(find.byKey(const Key('template-accidentClaim')));
      await tester.pumpAndSettle();

      expect(find.text('Plate'), findsOneWidget);
      expect(find.text('Tap to bind'), findsWidgets);
    });

    testWidgets('binds a row through the picker and saves partially bound',
        (tester) async {
      await mount(tester, pickerResult: _source);
      await tester.tap(find.byKey(const Key('template-accidentClaim')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('row-0-bind')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('designer-save')));
      await tester.pumpAndSettle();

      final saved = _CapturingCheatsheets.saved.single;
      expect(saved.id, 'new-id');
      expect(saved.rows[0].source, _source);
      expect(saved.rows.skip(1).every((r) => !r.isBound), isTrue,
          reason: 'a partially bound card is savable');
    });

    testWidgets('the picker is told which template it is binding for',
        (tester) async {
      // The seam the "picker shows every note in the app" bug lived in. The
      // picker cannot rank vehicle notes first unless the screen tells it what
      // card this is, and every assertion above passes whether it does or not.
      await mount(tester, pickerResult: _source);
      await tester.tap(find.byKey(const Key('template-accidentClaim')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('row-0-bind')));
      await tester.pumpAndSettle();

      expect(lastPickerTemplateId, 'accidentClaim');
    });

    testWidgets('a different template reaches the picker as itself',
        (tester) async {
      // Pins it to the card rather than to a constant: hardcoding
      // 'accidentClaim' at the call site would satisfy the test above.
      await mount(tester, pickerResult: _source);
      await tester.tap(find.byKey(const Key('template-blank')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('designer-new-row')), 'Plate');
      await tester.tap(find.byKey(const Key('designer-add-row')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('row-0-bind')));
      await tester.pumpAndSettle();

      expect(lastPickerTemplateId, 'blank');
    });

    testWidgets('value actions are chosen explicitly', (tester) async {
      await mount(tester, pickerResult: _source);
      await tester.tap(find.byKey(const Key('template-accidentClaim')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('row-0-action-call')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('designer-save')));
      await tester.pumpAndSettle();

      expect(_CapturingCheatsheets.saved.single.rows[0].valueAction,
          ValueAction.call);
    });

    testWidgets('title and wallet group are editable', (tester) async {
      await mount(tester);
      await tester.tap(find.byKey(const Key('template-blank')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('designer-title')), 'My Card');
      await tester.enterText(
          find.byKey(const Key('designer-wallet-group')), 'Health');
      await tester.tap(find.byKey(const Key('designer-save')));
      await tester.pumpAndSettle();

      final saved = _CapturingCheatsheets.saved.single;
      expect(saved.title, 'My Card');
      expect(saved.walletGroup, 'Health');
    });

    testWidgets('rows can be added and removed', (tester) async {
      await mount(tester);
      await tester.tap(find.byKey(const Key('template-blank')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('designer-new-row')), 'Plate');
      await tester.tap(find.byKey(const Key('designer-add-row')));
      await tester.pumpAndSettle();
      expect(find.text('Plate'), findsOneWidget);

      await tester.tap(find.byKey(const Key('row-0-remove')));
      await tester.pumpAndSettle();
      expect(find.text('Plate'), findsNothing);
    });

    testWidgets('no quick-access switch and no reorder handle in v1',
        (tester) async {
      await mount(tester);
      await tester.tap(find.byKey(const Key('template-accidentClaim')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('designer-quick-access')), findsNothing);
      expect(find.byType(ReorderableListView), findsNothing);
    });
  });

  group('two cards in one session', () {
    // Regression for a silent-overwrite bug that per-test ProviderScope
    // isolation hid: the editor's working copy outlived the screen, so the
    // second "new" reused the first card's id and overwrote it.
    //
    // What this pins: the visit-local `_started` flag in the designer. Revert
    // that guard — go back to deciding create-mode from `card.id.isEmpty` —
    // and this test fails. It was briefly blunt while a redundant
    // `reset()`-after-commit also masked the bug; that call has since been
    // removed (it read `ref` after an await and blanked the outgoing frame),
    // which left this test sharp again.
    testWidgets('starting a second new card does not reuse the first',
        (tester) async {
      var nextId = 0;
      final container = ProviderContainer(
        overrides: [
          cheatsheetIdGenProvider.overrideWithValue(() => 'id-${++nextId}'),
          cheatsheetsStateProvider.overrideWith(_CapturingCheatsheets.new),
          cheatsheetSourcePickerProvider
              .overrideWithValue((_, {required templateId}) async => null),
        ],
      );
      addTearDown(container.dispose);

      Future<void> openDesigner() async {
        // Pump something else first so the previous designer's State is
        // disposed — otherwise pumpWidget reuses it, which a real route push
        // would never do. The ProviderContainer is deliberately shared: that
        // is the thing that leaks between visits.
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SizedBox.shrink()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: CheatsheetDesignerScreen()),
          ),
        );
        await tester.pumpAndSettle();
      }

      // First card.
      await openDesigner();
      await tester.tap(find.byKey(const Key('template-accidentClaim')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('designer-title')), 'First');
      await tester.tap(find.byKey(const Key('designer-save')));
      await tester.pumpAndSettle();

      // Second card, same session.
      await openDesigner();

      expect(find.byKey(const Key('template-accidentClaim')), findsOneWidget,
          reason: 'a new card starts at the template chooser, not mid-edit');

      await tester.tap(find.byKey(const Key('template-blank')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('designer-title')), 'Second');
      await tester.tap(find.byKey(const Key('designer-save')));
      await tester.pumpAndSettle();

      expect(_CapturingCheatsheets.saved.length, 2);
      final ids = _CapturingCheatsheets.saved.map((c) => c.id).toList();
      expect(ids.toSet().length, 2,
          reason: 'the second card must not overwrite the first');
      expect(
          _CapturingCheatsheets.saved.map((c) => c.title), ['First', 'Second']);
    });
  });

  group('edit', () {
    testWidgets('loads the existing card without a template chooser',
        (tester) async {
      _CapturingCheatsheets.seed = const [existingCard];
      await mount(tester, cardId: 'existing-id');

      expect(find.byKey(const Key('template-accidentClaim')), findsNothing);
      expect(find.text('Plate'), findsOneWidget);
      expect(find.text('VIN'), findsOneWidget);
    });

    testWidgets('renaming and saving keeps the id — no duplicate card',
        (tester) async {
      _CapturingCheatsheets.seed = const [existingCard];
      await mount(tester, cardId: 'existing-id');

      await tester.enterText(find.byKey(const Key('designer-title')), 'Renamed');
      await tester.tap(find.byKey(const Key('designer-save')));
      await tester.pumpAndSettle();

      expect(_CapturingCheatsheets.saved.length, 1);
      final saved = _CapturingCheatsheets.saved.single;
      expect(saved.id, 'existing-id', reason: 'identity survives an edit');
      expect(saved.title, 'Renamed');
    });

    testWidgets('an existing binding is shown rather than "Tap to bind"',
        (tester) async {
      _CapturingCheatsheets.seed = const [existingCard];
      await mount(tester, cardId: 'existing-id');

      expect(find.textContaining('AutomobileInfo.plate'), findsOneWidget);
      expect(find.text('Tap to bind'), findsOneWidget); // only the VIN row
    });

    testWidgets('the loaded card\'s template reaches the picker',
        (tester) async {
      // Distinct wiring from the create flow: there the template comes from
      // startFromTemplate, here from load(existing). If the editor had not
      // taken the loaded card by the time a row is bound, the picker would
      // silently rank against the blank default and offer every note again.
      _CapturingCheatsheets.seed = const [existingCard];
      await mount(tester, cardId: 'existing-id', pickerResult: _source);

      await tester.tap(find.byKey(const Key('row-1-bind')));
      await tester.pumpAndSettle();

      expect(lastPickerTemplateId, 'accidentClaim');
    });

    testWidgets('an unknown card id shows a not-found message', (tester) async {
      _CapturingCheatsheets.seed = const [];
      await mount(tester, cardId: 'nope');

      expect(find.byKey(const Key('designer-not-found')), findsOneWidget);
    });
  });
}
