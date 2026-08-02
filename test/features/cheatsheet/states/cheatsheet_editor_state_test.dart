import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_row.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_source.dart';
import 'package:hmm_console/features/cheatsheet/states/cheatsheet_editor_state.dart';
import 'package:hmm_console/features/cheatsheet/states/cheatsheets_state.dart';

/// Captures what the editor commits. A fixed subclass, not a fake WidgetRef —
/// WidgetRef is sealed and must never be faked.
class _CapturingCheatsheets extends CheatsheetsState {
  static final saved = <CheatsheetCard>[];

  @override
  Future<List<CheatsheetCard>> build() async => const [];

  @override
  Future<void> save(CheatsheetCard card) async => saved.add(card);
}

const _source = CheatsheetSource(
  noteUuid: 'auto1',
  kind: SourceGranularity.field,
  locator: 'AutomobileInfo.plate',
);

void main() {
  ProviderContainer containerWith({String Function()? idGen}) {
    final c = ProviderContainer(
      overrides: [
        if (idGen != null) cheatsheetIdGenProvider.overrideWithValue(idGen),
        cheatsheetsStateProvider.overrideWith(_CapturingCheatsheets.new),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(_CapturingCheatsheets.saved.clear);

  CheatsheetEditor editorOf(ProviderContainer c) =>
      c.read(cheatsheetEditorProvider.notifier);

  group('create', () {
    test('startFromTemplate yields labelled unbound rows and a fresh id', () {
      final container = containerWith();
      final editor = editorOf(container);

      editor.startFromTemplate('accidentClaim');
      final card = container.read(cheatsheetEditorProvider);

      expect(card.id, isNotEmpty);
      expect(card.templateId, 'accidentClaim');
      expect(card.rows, isNotEmpty);
      expect(card.rows.every((r) => !r.isBound), isTrue);
      expect(card.rows.map((r) => r.label), contains('Plate'));
    });

    test('two new cards get distinct ids from the real generator', () {
      final a = containerWith();
      final b = containerWith();
      editorOf(a).startFromTemplate('blank');
      editorOf(b).startFromTemplate('blank');

      expect(
        a.read(cheatsheetEditorProvider).id,
        isNot(b.read(cheatsheetEditorProvider).id),
      );
    });

    test('the id generator is injectable', () {
      final container = containerWith(idGen: () => 'fixed');
      editorOf(container).startFromTemplate('blank');

      expect(container.read(cheatsheetEditorProvider).id, 'fixed');
    });
  });

  group('editing rows', () {
    test('bindRow binds only the targeted row', () {
      final container = containerWith(idGen: () => 'fixed');
      final editor = editorOf(container);
      editor.startFromTemplate('accidentClaim');

      editor.bindRow(0, _source);
      final card = container.read(cheatsheetEditorProvider);

      expect(card.rows[0].source, _source);
      expect(card.rows.skip(1).every((r) => !r.isBound), isTrue);
    });

    test('unbindRow clears a binding', () {
      final container = containerWith(idGen: () => 'fixed');
      final editor = editorOf(container);
      editor.startFromTemplate('accidentClaim');
      editor.bindRow(0, _source);

      editor.unbindRow(0);

      expect(container.read(cheatsheetEditorProvider).rows[0].isBound, isFalse);
    });

    test('add and remove rows', () {
      final container = containerWith(idGen: () => 'fixed');
      final editor = editorOf(container);
      editor.startFromTemplate('blank');

      editor.addRow('Plate');
      editor.addRow('VIN');
      expect(container.read(cheatsheetEditorProvider).rows.length, 2);

      editor.removeRow(0);
      final rows = container.read(cheatsheetEditorProvider).rows;
      expect(rows.length, 1);
      expect(rows.single.label, 'VIN');
    });

    test('value actions are set explicitly, never inferred', () {
      final container = containerWith(idGen: () => 'fixed');
      final editor = editorOf(container);
      editor.startFromTemplate('accidentClaim');

      expect(container.read(cheatsheetEditorProvider).rows[0].valueAction,
          ValueAction.none);

      editor.setValueAction(0, ValueAction.call);
      expect(container.read(cheatsheetEditorProvider).rows[0].valueAction,
          ValueAction.call);
    });

    test('setOpenSource toggles the affordance', () {
      final container = containerWith(idGen: () => 'fixed');
      final editor = editorOf(container);
      editor.startFromTemplate('accidentClaim');

      editor.setOpenSource(0, false);
      expect(
          container.read(cheatsheetEditorProvider).rows[0].openSource, isFalse);
    });

    test('out-of-range row indexes are ignored, not thrown', () {
      final container = containerWith(idGen: () => 'fixed');
      final editor = editorOf(container);
      editor.startFromTemplate('blank');

      expect(() => editor.bindRow(3, _source), returnsNormally);
      expect(() => editor.removeRow(3), returnsNormally);
      expect(container.read(cheatsheetEditorProvider).rows, isEmpty);
    });
  });

  group('header fields', () {
    test('title, wallet group and tags are settable', () {
      final container = containerWith(idGen: () => 'fixed');
      final editor = editorOf(container);
      editor.startFromTemplate('blank');

      editor.setTitle('My Card');
      editor.setWalletGroup('Vehicle');
      editor.setTags(const ['legal']);

      final card = container.read(cheatsheetEditorProvider);
      expect(card.title, 'My Card');
      expect(card.walletGroup, 'Vehicle');
      expect(card.tags, ['legal']);
    });
  });

  group('edit lifecycle', () {
    const existing = CheatsheetCard(
      id: 'existing-id',
      title: 'Original',
      walletGroup: 'Vehicle',
      tags: ['legal'],
      templateId: 'accidentClaim',
      rows: [CheatsheetRow(label: 'Plate', source: _source)],
    );

    test('load adopts the card verbatim', () {
      final container = containerWith(idGen: () => 'fixed');
      editorOf(container).load(existing);

      expect(container.read(cheatsheetEditorProvider), equals(existing));
    });

    test('editing a loaded card keeps its id — no duplicate on save',
        () async {
      final container = containerWith(idGen: () => 'fixed');
      final editor = editorOf(container);

      editor.load(existing);
      editor.setTitle('Renamed');
      await editor.commit();

      expect(_CapturingCheatsheets.saved.length, 1);
      final saved = _CapturingCheatsheets.saved.single;
      expect(saved.id, 'existing-id', reason: 'identity survives an edit');
      expect(saved.title, 'Renamed');
    });

    test('commit sends the working card, partial bindings and all', () async {
      final container = containerWith(idGen: () => 'fixed');
      final editor = editorOf(container);

      editor.startFromTemplate('accidentClaim');
      editor.bindRow(0, _source);
      await editor.commit();

      final saved = _CapturingCheatsheets.saved.single;
      expect(saved.id, 'fixed');
      expect(saved.rows[0].source, _source);
      expect(saved.rows.skip(1).every((r) => !r.isBound), isTrue,
          reason: 'a partially bound card is savable');
    });
  });
}
