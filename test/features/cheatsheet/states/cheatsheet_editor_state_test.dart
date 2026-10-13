import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/picker/image_byte_source.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/features/cheatsheet/data/cheatsheet_codec.dart';
import 'package:hmm_console/features/cheatsheet/data/mappers/cheatsheet_api_mapper.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/card_style.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_row.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_source.dart';
import 'package:hmm_console/features/cheatsheet/states/cheatsheet_cover_draft.dart';
import 'package:hmm_console/features/cheatsheet/states/cheatsheet_covers_supported.dart';
import 'package:hmm_console/features/cheatsheet/states/cheatsheet_editor_state.dart';
import 'package:hmm_console/features/cheatsheet/states/cheatsheets_state.dart';

/// Captures what the editor commits. A fixed subclass, not a fake WidgetRef —
/// WidgetRef is sealed and must never be faked.
class _CapturingCheatsheets extends CheatsheetsState {
  static final saved = <CheatsheetCard>[];
  static final covers = <PickedImageBytes?>[];
  static final releases = <List<VaultRef>>[];

  @override
  Future<List<CheatsheetCard>> build() async => const [];

  @override
  Future<void> save(
    CheatsheetCard card, {
    PickedImageBytes? newCover,
    List<VaultRef> released = const [],
  }) async {
    saved.add(card);
    covers.add(newCover);
    releases.add(released);
  }
}

class _Mode extends DataModeNotifier {
  _Mode(this.mode);
  final DataMode mode;
  @override
  DataMode build() => mode;
}

const _source = CheatsheetSource(
  noteUuid: 'auto1',
  kind: SourceGranularity.field,
  locator: 'AutomobileInfo.plate',
);

void main() {
  late AppLocalizations en;

  setUp(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  ProviderContainer containerWith({
    String Function()? idGen,
    DataMode mode = DataMode.local,
  }) {
    final c = ProviderContainer(
      overrides: [
        if (idGen != null) cheatsheetIdGenProvider.overrideWithValue(idGen),
        dataModeProvider.overrideWith(() => _Mode(mode)),
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

      editor.startFromTemplate('accidentClaim', en);
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
      editorOf(a).startFromTemplate('blank', en);
      editorOf(b).startFromTemplate('blank', en);

      expect(
        a.read(cheatsheetEditorProvider).id,
        isNot(b.read(cheatsheetEditorProvider).id),
      );
    });

    test('the id generator is injectable', () {
      final container = containerWith(idGen: () => 'fixed');
      editorOf(container).startFromTemplate('blank', en);

      expect(container.read(cheatsheetEditorProvider).id, 'fixed');
    });
  });

  group('editing rows', () {
    test('bindRow binds only the targeted row', () {
      final container = containerWith(idGen: () => 'fixed');
      final editor = editorOf(container);
      editor.startFromTemplate('accidentClaim', en);

      editor.bindRow(0, _source);
      final card = container.read(cheatsheetEditorProvider);

      expect(card.rows[0].source, _source);
      expect(card.rows.skip(1).every((r) => !r.isBound), isTrue);
    });

    test('unbindRow clears a binding', () {
      final container = containerWith(idGen: () => 'fixed');
      final editor = editorOf(container);
      editor.startFromTemplate('accidentClaim', en);
      editor.bindRow(0, _source);

      editor.unbindRow(0);

      expect(container.read(cheatsheetEditorProvider).rows[0].isBound, isFalse);
    });

    test('add and remove rows', () {
      final container = containerWith(idGen: () => 'fixed');
      final editor = editorOf(container);
      editor.startFromTemplate('blank', en);

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
      editor.startFromTemplate('accidentClaim', en);

      expect(
        container.read(cheatsheetEditorProvider).rows[0].valueAction,
        ValueAction.none,
      );

      editor.setValueAction(0, ValueAction.call);
      expect(
        container.read(cheatsheetEditorProvider).rows[0].valueAction,
        ValueAction.call,
      );
    });

    test('setOpenSource toggles the affordance', () {
      final container = containerWith(idGen: () => 'fixed');
      final editor = editorOf(container);
      editor.startFromTemplate('accidentClaim', en);

      editor.setOpenSource(0, false);
      expect(
        container.read(cheatsheetEditorProvider).rows[0].openSource,
        isFalse,
      );
    });

    test('out-of-range row indexes are ignored, not thrown', () {
      final container = containerWith(idGen: () => 'fixed');
      final editor = editorOf(container);
      editor.startFromTemplate('blank', en);

      expect(() => editor.bindRow(3, _source), returnsNormally);
      expect(() => editor.removeRow(3), returnsNormally);
      expect(container.read(cheatsheetEditorProvider).rows, isEmpty);
    });
  });

  group('header fields', () {
    test('title, wallet group and tags are settable', () {
      final container = containerWith(idGen: () => 'fixed');
      final editor = editorOf(container);
      editor.startFromTemplate('blank', en);

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

    test('editing a loaded card keeps its id — no duplicate on save', () async {
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

      editor.startFromTemplate('accidentClaim', en);
      editor.bindRow(0, _source);
      await editor.commit();

      final saved = _CapturingCheatsheets.saved.single;
      expect(saved.id, 'fixed');
      expect(saved.rows[0].source, _source);
      expect(
        saved.rows.skip(1).every((r) => !r.isBound),
        isTrue,
        reason: 'a partially bound card is savable',
      );
    });
  });

  group('look', () {
    setUp(() {
      _CapturingCheatsheets.covers.clear();
      _CapturingCheatsheets.releases.clear();
    });

    const eyes = '\u{1F440}';
    const star = '⭐';
    const cover = VaultRef(
      path: 'attachments/note-1/c.jpg',
      contentType: 'image/jpeg',
      byteSize: 3,
    );
    const existing = CheatsheetCard(
      id: 'e1',
      title: 'Vim',
      walletGroup: 'Reference',
      tags: [],
      templateId: 'document',
      rows: [CheatsheetRow(label: 'Motions', source: null)],
    );
    PickedImageBytes pick() => PickedImageBytes(
      bytes: Uint8List.fromList(const [1, 2, 3]),
      originalName: 'c.png',
      contentType: 'image/png',
    );

    test('the template theme stores nothing; another theme is stored', () {
      final c = containerWith();
      final editor = editorOf(c);
      editor.startFromTemplate('accidentClaim', en);

      editor.setTheme(CardThemeId.red);
      expect(c.read(cheatsheetEditorProvider).style.toMap(), {'theme': 'red'});

      editor.setTheme(CardThemeId.blue);
      expect(c.read(cheatsheetEditorProvider).style.isEmpty, isTrue);
    });

    test('pattern, icon and layout edits store only non-defaults', () {
      final c = containerWith();
      final editor = editorOf(c);
      editor.startFromTemplate('document', en);

      editor.setPattern(CardPattern.grid);
      editor.setIcon('\u{1F984}');
      editor.setLayout(CardLayout.facts);
      expect(c.read(cheatsheetEditorProvider).style.toMap(), {
        'pattern': 'grid',
        'icon': '\u{1F984}',
        'layout': 'facts',
      });

      editor.setIcon(null);
      editor.setLayout(CardLayout.keyPoints);
      expect(c.read(cheatsheetEditorProvider).style.toMap(), {
        'pattern': 'grid',
      });
    });

    test('a layout round trip keeps every row emoji', () {
      final c = containerWith();
      final editor = editorOf(c);
      editor.startFromTemplate('document', en);
      editor.addRow('Second');
      editor.setRowEmoji(0, eyes);
      editor.setRowEmoji(1, star);

      editor.setLayout(CardLayout.facts);
      editor.setLayout(CardLayout.keyPoints);

      final card = c.read(cheatsheetEditorProvider);
      expect(card.rows.map((r) => r.emoji), [eyes, star]);
      expect(
        card.style.isEmpty,
        isTrue,
        reason: 'Key points is the document default',
      );
    });

    test(
      'setRowEmoji with null or empty clears it; a stale index is a no-op',
      () {
        final c = containerWith();
        final editor = editorOf(c);
        editor.load(existing);
        editor.setRowEmoji(0, eyes);
        editor.setRowEmoji(0, '');
        expect(c.read(cheatsheetEditorProvider).rows.single.emoji, isNull);
        editor.setRowEmoji(0, eyes);
        editor.setRowEmoji(0, null);
        expect(c.read(cheatsheetEditorProvider).rows.single.emoji, isNull);
        editor.setRowEmoji(9, eyes);
        expect(c.read(cheatsheetEditorProvider).rows, hasLength(1));
      },
    );

    test('picking a cover stages it and commit hands it to save', () async {
      final c = containerWith();
      final editor = editorOf(c);
      editor.startFromTemplate('blank', en);

      editor.pickCover(pick());
      expect(c.read(cheatsheetCoverDraftProvider).pending, isNotNull);

      await editor.commit();
      expect(_CapturingCheatsheets.covers.single, isNotNull);
      expect(_CapturingCheatsheets.releases.single, isEmpty);
    });

    test('replacing a stored cover releases the old one on commit', () async {
      final c = containerWith();
      final editor = editorOf(c);
      editor.load(existing.withCover(cover));

      editor.pickCover(pick());
      expect(c.read(cheatsheetEditorProvider).cover, isNull);

      await editor.commit();
      expect(_CapturingCheatsheets.releases.single, [cover]);
      expect(_CapturingCheatsheets.covers.single, isNotNull);
    });

    test(
      'removing drops a pending pick and releases the stored cover',
      () async {
        final c = containerWith();
        final editor = editorOf(c);
        editor.load(existing.withCover(cover));
        editor.pickCover(pick());

        editor.removeCover();
        await editor.commit();

        expect(_CapturingCheatsheets.covers.single, isNull);
        expect(_CapturingCheatsheets.releases.single, [cover]);
        expect(_CapturingCheatsheets.saved.last.cover, isNull);
        expect(_CapturingCheatsheets.saved.last.style.coverPath, isNull);
      },
    );

    test('reset look clears style, row emoji and preserved raw look keys, and '
        'releases the cover', () async {
      final c = containerWith();
      final editor = editorOf(c);
      editor.load(
        existing
            .copyWith(
              style: const CardStyle({'theme': 'red', 'sparkle': true}),
              rows: const [
                CheatsheetRow(
                  label: 'Motions',
                  source: null,
                  emoji: eyes,
                  extraFields: {'hint': 1},
                ),
              ],
              extraFields: const {'future': 2},
            )
            .withCover(cover),
      );

      editor.resetLook();
      final card = c.read(cheatsheetEditorProvider);
      expect(card.style.isEmpty, isTrue);
      expect(card.cover, isNull);
      expect(card.rows.single.emoji, isNull);
      expect(card.rows.single.extraFields, {'hint': 1});
      expect(card.extraFields, {'future': 2});

      await editor.commit();
      expect(_CapturingCheatsheets.releases.single, [cover]);
    });

    test('reset look also drops a preserved non-map style and a non-string '
        'row emoji', () {
      final c = containerWith();
      final editor = editorOf(c);
      editor.load(
        existing.copyWith(
          extraFields: const {'style': 'odd'},
          rows: const [
            CheatsheetRow(
              label: 'Motions',
              source: null,
              extraFields: {'emoji': 42},
            ),
          ],
        ),
      );

      editor.resetLook();
      final card = c.read(cheatsheetEditorProvider);
      expect(card.extraFields.containsKey('style'), isFalse);
      expect(card.rows.single.extraFields.containsKey('emoji'), isFalse);
    });

    test('after reset look the wire drops every look trace', () {
      final c = containerWith();
      final editor = editorOf(c);
      editor.load(
        existing
            .copyWith(
              style: const CardStyle({'theme': 'red'}),
              rows: const [
                CheatsheetRow(label: 'Motions', source: null, emoji: eyes),
                CheatsheetRow(
                  label: 'Raw',
                  source: null,
                  extraFields: {'emoji': 42},
                ),
              ],
            )
            .withCover(cover),
      );
      editor.resetLook();
      final reset = c.read(cheatsheetEditorProvider);

      // Cloud API: Style is present and null, so the server clears its copy.
      final api = CheatsheetApiMapper.toApi(reset);
      expect(api.containsKey('Style'), isTrue);
      expect(api['Style'], isNull);
      expect(
        (api['Rows'] as List).every((r) => !(r as Map).containsKey('Emoji')),
        isTrue,
      );

      // Local / cloudStorage: no style key, no row emoji.
      final local = CheatsheetCodec.toMap(reset);
      expect(local.containsKey('style'), isFalse);
      expect(
        (local['rows'] as List).every((r) => !(r as Map).containsKey('emoji')),
        isTrue,
      );

      // A preserved non-map style is gone from both, too.
      editor.load(existing.copyWith(extraFields: const {'style': 'odd'}));
      editor.resetLook();
      final raw = c.read(cheatsheetEditorProvider);
      expect(CheatsheetApiMapper.toApi(raw)['Style'], isNull);
      expect(CheatsheetCodec.toMap(raw).containsKey('style'), isFalse);
    });

    test('covers are supported everywhere but cloudApi', () {
      expect(containerWith().read(cheatsheetCoversSupportedProvider), isTrue);
      expect(
        containerWith(
          mode: DataMode.cloudStorage,
        ).read(cheatsheetCoversSupportedProvider),
        isTrue,
      );
      expect(
        containerWith(
          mode: DataMode.cloudApi,
        ).read(cheatsheetCoversSupportedProvider),
        isFalse,
      );
    });

    test('in cloudApi, reset look keeps a cover set on another device but '
        'clears everything else', () async {
      final c = containerWith(mode: DataMode.cloudApi);
      final editor = editorOf(c);
      editor.load(
        existing.copyWith(
          style: const CardStyle({'theme': 'orange', 'cover': 'images/x.jpg'}),
          rows: const [
            CheatsheetRow(label: 'Motions', source: null, emoji: eyes),
            CheatsheetRow(
              label: 'Raw',
              source: null,
              extraFields: {'emoji': 42, 'hint': 1},
            ),
          ],
        ),
      );

      editor.resetLook();
      final card = c.read(cheatsheetEditorProvider);

      final api = CheatsheetApiMapper.toApi(card);
      expect(api['Style'], {'cover': 'images/x.jpg'});
      expect(
        (api['Rows'] as List).every((r) => !(r as Map).containsKey('Emoji')),
        isTrue,
      );
      expect(card.rows.last.extraFields, {'hint': 1});
      expect(c.read(cheatsheetCoverDraftProvider).released, isEmpty);

      await editor.commit();
      expect(_CapturingCheatsheets.releases.single, isEmpty);
    });

    test('in cloudApi, reset look without a cover sends Style null and drops '
        'a preserved raw style', () {
      final c = containerWith(mode: DataMode.cloudApi);
      final editor = editorOf(c);
      editor.load(existing.copyWith(extraFields: const {'style': 'odd'}));

      editor.resetLook();

      final api = CheatsheetApiMapper.toApi(c.read(cheatsheetEditorProvider));
      expect(api.containsKey('Style'), isTrue);
      expect(api['Style'], isNull);
    });

    test('loading a card discards a pending cover from an earlier visit', () {
      final c = containerWith();
      final editor = editorOf(c);
      editor.load(existing.withCover(cover));
      editor.pickCover(pick());

      editor.load(existing);

      final draft = c.read(cheatsheetCoverDraftProvider);
      expect(draft.pending, isNull);
      expect(draft.released, isEmpty);
    });
  });
}
