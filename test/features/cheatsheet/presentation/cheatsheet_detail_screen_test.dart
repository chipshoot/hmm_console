import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:hmm_console/core/help/help_button.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/card_style.dart';
import 'package:hmm_console/features/cheatsheet/presentation/look/cheatsheet_palette.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/resolver/attachment_resolver.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/vault/vault_session.dart';
import 'package:hmm_console/core/data/attachments/widgets/sensitive_attachment_image.dart';
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
  static final removed = <String>[];

  @override
  Future<List<CheatsheetCard>> build() async => seed;

  /// When set, [remove] throws it instead of removing.
  static Object? removeError;

  @override
  Future<void> remove(String id) async {
    if (removeError != null) throw removeError!;
    removed.add(id);
  }
}

final autoNote = HmmNote(
  id: 1,
  uuid: 'auto1',
  subject: 'My Car',
  authorId: 1,
  createDate: DateTime(2026),
  content:
      '{"note":{"content":{"AutomobileInfo":{"plate":"ABC123",'
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
  setUp(() {
    _SeededCheatsheets.seed = const [card];
    _SeededCheatsheets.removed.clear();
  });

  Future<
    ({
      List<(ValueAction, String)> launched,
      List<String> openedSources,
      List<String> edited,
    })
  >
  mount(WidgetTester tester, {bool launchFails = false}) async {
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
          cheatsheetOpenSourceProvider.overrideWithValue(
            (_, uuid) => openedSources.add(uuid),
          ),
          cheatsheetEditCardProvider.overrideWithValue(
            (_, id) => edited.add(id),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CheatsheetDetailScreen(cardId: 'c1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (launched: launched, openedSources: openedSources, edited: edited);
  }

  testWidgets('renders resolved values, placeholders and section text', (
    tester,
  ) async {
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

  testWidgets('a launch failure shows a message and does not crash', (
    tester,
  ) async {
    await mount(tester, launchFails: true);

    await tester.tap(find.byKey(const Key('row-3-value')));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // NOTE: `_launch` catches `on Exception`, not everything, so a programming
  // Error is never disguised as "could not open that". That path is
  // deliberately not asserted here: an Error thrown from a fire-and-forget
  // onTap callback surfaces as an unhandled *zone* error, which flutter_test
  // treats as a test failure — pinning it needs zone plumbing out of
  // proportion to the value. The Exception path is covered above.

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

  group('delete', () {
    testWidgets('asks for confirmation before deleting anything', (
      tester,
    ) async {
      await mount(tester);

      await tester.tap(find.byKey(const Key('detail-delete')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        _SeededCheatsheets.removed,
        isEmpty,
        reason: 'nothing is deleted until confirmed',
      );
    });

    testWidgets('cancelling leaves the card alone', (tester) async {
      await mount(tester);

      await tester.tap(find.byKey(const Key('detail-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete-cancel')));
      await tester.pumpAndSettle();

      expect(_SeededCheatsheets.removed, isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('a failed delete says so without the exception text', (
      tester,
    ) async {
      _SeededCheatsheets.removeError = StateError('/vault/secret-path');
      addTearDown(() => _SeededCheatsheets.removeError = null);
      await mount(tester);

      await tester.tap(find.byKey(const Key('detail-delete')));
      await tester.pumpAndSettle();
      final logs = await _captureLogs(() async {
        await tester.tap(find.byKey(const Key('delete-confirm')));
        await tester.pumpAndSettle();
      });

      expect(find.text('Could not delete this cheatsheet.'), findsOneWidget);
      expect(find.textContaining('secret-path'), findsNothing);
      expect(logs.join('\n'), contains('StateError'));
      expect(logs.join('\n'), isNot(contains('secret-path')));
    });

    testWidgets('confirming deletes this card', (tester) async {
      await mount(tester);

      await tester.tap(find.byKey(const Key('detail-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete-confirm')));
      await tester.pumpAndSettle();

      expect(_SeededCheatsheets.removed, ['c1']);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the confirmation says source notes are NOT deleted', (
      tester,
    ) async {
      // Deleting a card must not read as deleting the notes it points at.
      // Asserting merely that the word "notes" appears is useless: the
      // opposite message ("this will also delete the notes it references")
      // contains it too, and an earlier version of this test passed against
      // exactly that inversion.
      await mount(tester);

      await tester.tap(find.byKey(const Key('detail-delete')));
      await tester.pumpAndSettle();

      expect(find.textContaining('not deleted'), findsOneWidget);
    });
  });

  group('image rows', () {
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAA'
      'DUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );
    const front = VaultRef(
      path: 'images/front.png',
      contentType: 'image/png',
      byteSize: 70,
      sensitive: true,
    );
    final licenceNote = HmmNote(
      id: 3,
      uuid: 'lic1',
      subject: 'Licence',
      authorId: 1,
      createDate: DateTime(2026),
      content:
          '{"note":{"content":{"DriverLicence":'
          '{"frontImagePath":"images/front.png"}}}}',
      attachments: NoteAttachments(images: const [front]),
    );
    const imageCard = CheatsheetCard(
      id: 'c1',
      title: 'Claim',
      walletGroup: 'Vehicle',
      tags: [],
      templateId: 'accidentClaim',
      rows: [
        CheatsheetRow(
          label: 'Licence (front)',
          source: CheatsheetSource(
            noteUuid: 'lic1',
            kind: SourceGranularity.image,
            locator: 'images/front.png',
          ),
        ),
      ],
    );

    Future<void> mountImage(
      WidgetTester tester,
      VaultStatus vault, {
      bool resolverFails = false,
    }) async {
      _SeededCheatsheets.seed = const [imageCard];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hmmNoteRepositoryProvider.overrideWithValue(
              _FakeNotes({'lic1': licenceNote}),
            ),
            cheatsheetsStateProvider.overrideWith(_SeededCheatsheets.new),
            attachmentResolverProvider.overrideWith(
              (ref) async => resolverFails
                  ? throw StateError('no resolver')
                  : _BytesResolver(png),
            ),
            vaultSessionProvider.overrideWith(() => _StubVault(vault)),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CheatsheetDetailScreen(cardId: 'c1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the photo, never its vault path', (tester) async {
      await mountImage(tester, VaultStatus.unlocked);

      expect(find.byKey(const Key('row-0-image')), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.textContaining('images/front.png'), findsNothing);
      expect(find.byKey(const Key('row-0-missing')), findsNothing);
    });

    testWidgets('a failed resolver shows a broken placeholder, not a spinner', (
      tester,
    ) async {
      await mountImage(tester, VaultStatus.unlocked, resolverFails: true);

      expect(find.byKey(const Key('row-0-image-error')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a locked vault shows the lock, not a broken image', (
      tester,
    ) async {
      await mountImage(tester, VaultStatus.locked);

      expect(find.byKey(sensitiveLockedPlaceholderKey), findsOneWidget);
    });
  });
  group('look', () {
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAA'
      'DUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );

    final keyPointsCard = card.copyWith(
      style: const CardStyle({'layout': 'keyPoints'}),
      rows: [
        card.rows[0].copyWith(emoji: '\u{1F440}'),
        card.rows[1],
        card.rows[2].copyWith(emoji: 'not an emoji'),
        ...card.rows.sublist(3),
      ],
    );

    Future<List<(ValueAction, String)>> mountLook(
      WidgetTester tester,
      CheatsheetCard c, {
      VaultStatus vault = VaultStatus.unlocked,
      Map<String, HmmNote>? notes,
    }) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final launched = <(ValueAction, String)>[];
      _SeededCheatsheets.seed = [c];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hmmNoteRepositoryProvider.overrideWithValue(
              _FakeNotes(notes ?? {'auto1': autoNote, 'doc1': docNote}),
            ),
            cheatsheetsStateProvider.overrideWith(_SeededCheatsheets.new),
            launchActionProvider.overrideWithValue((action, value) async {
              launched.add((action, value));
            }),
            attachmentResolverProvider.overrideWith(
              (ref) async => _BytesResolver(png),
            ),
            vaultSessionProvider.overrideWith(() => _StubVault(vault)),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CheatsheetDetailScreen(cardId: 'c1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return launched;
    }

    String textOf(WidgetTester tester, String key) =>
        tester.widget<Text>(find.byKey(Key(key))).data!;

    testWidgets('the header shows the icon, title and group · rows', (
      tester,
    ) async {
      await mountLook(tester, card);

      expect(find.byKey(const Key('detail-header')), findsOneWidget);
      expect(textOf(tester, 'detail-header-icon'), CardLookDefaults.dividers);
      expect(textOf(tester, 'detail-header-title'), 'Claim');
      expect(textOf(tester, 'detail-header-subtitle'), 'Vehicle · 6 rows');
    });

    testWidgets('Facts stays the default and renders rows as before', (
      tester,
    ) async {
      await mountLook(tester, card);

      expect(find.byKey(const Key('keypoint-0')), findsNothing);
      expect(find.text('ABC123'), findsOneWidget);
      expect(find.byKey(const Key('row-2-unbound')), findsOneWidget);
      expect(find.byKey(const Key('row-1-missing')), findsOneWidget);
    });

    testWidgets('Key points numbers rows, shows valid row emoji and a theme '
        'border', (tester) async {
      await mountLook(tester, keyPointsCard);

      String number(int i) => tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(Key('keypoint-$i-number')),
              matching: find.byType(Text),
            ),
          )
          .data!;
      expect(number(0), '1');
      expect(number(3), '4');
      expect(find.byKey(const Key('keypoint-0-emoji')), findsOneWidget);
      expect(
        find.byKey(const Key('keypoint-2-emoji')),
        findsNothing,
        reason: 'an invalid stored emoji is not shown',
      );

      final slate = CheatsheetPalette.of(CardThemeId.slate, Brightness.light);
      final box =
          tester
                  .widget<Container>(find.byKey(const Key('keypoint-0')))
                  .decoration!
              as BoxDecoration;
      expect((box.border! as Border).left.color, slate.background);
    });

    testWidgets('Key points keeps unbound, missing, section text and actions', (
      tester,
    ) async {
      final launched = await mountLook(tester, keyPointsCard);

      expect(find.byKey(const Key('row-2-unbound')), findsOneWidget);
      expect(find.byKey(const Key('row-1-missing')), findsOneWidget);
      expect(find.textContaining('dd delete line'), findsOneWidget);

      await tester.tap(find.byKey(const Key('row-3-value')));
      await tester.pumpAndSettle();
      expect(launched, [(ValueAction.call, '(555) 123-4567')]);
    });

    testWidgets('an image row renders in Key points', (tester) async {
      const front = VaultRef(
        path: 'images/front.png',
        contentType: 'image/png',
        byteSize: 70,
      );
      final licence = HmmNote(
        id: 3,
        uuid: 'lic1',
        subject: 'Licence',
        authorId: 1,
        createDate: DateTime(2026),
        content:
            '{"note":{"content":{"DriverLicence":'
            '{"frontImagePath":"images/front.png"}}}}',
        attachments: NoteAttachments(images: const [front]),
      );
      final imageCard = card.copyWith(
        style: const CardStyle({'layout': 'keyPoints'}),
        rows: const [
          CheatsheetRow(
            label: 'Licence (front)',
            source: CheatsheetSource(
              noteUuid: 'lic1',
              kind: SourceGranularity.image,
              locator: 'images/front.png',
            ),
          ),
        ],
      );
      await mountLook(tester, imageCard, notes: {'lic1': licence});

      expect(find.byKey(const Key('keypoint-0')), findsOneWidget);
      expect(find.byKey(const Key('row-0-image')), findsOneWidget);
    });

    testWidgets('a locked sensitive cover shows the tap-to-unlock tile in the '
        'header', (tester) async {
      const secret = VaultRef(
        path: 'attachments/note-9/sensitive/c.png',
        contentType: 'image/png',
        byteSize: 70,
        sensitive: true,
      );
      await mountLook(
        tester,
        card.withCover(secret),
        vault: VaultStatus.locked,
      );

      expect(
        find.descendant(
          of: find.byKey(const Key('detail-header')),
          matching: find.byKey(sensitiveLockedPlaceholderKey),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a cover card colours the app bar dark with white actions', (
      tester,
    ) async {
      const cover = VaultRef(
        path: 'attachments/note-9/c.png',
        contentType: 'image/png',
        byteSize: 70,
      );
      await mountLook(tester, card.withCover(cover));

      final bar = tester.widget<AppBar>(find.byType(AppBar));
      final expected = CheatsheetPalette.forCover(
        CardThemeId.slate,
        Brightness.light,
      );
      expect(bar.backgroundColor, expected.background);
      expect(bar.foregroundColor, expected.foreground);
      expect(find.byKey(const Key('card-surface-cover')), findsOneWidget);
    });

    testWidgets('the detail has a help button that explains both layouts, '
        'the header and the lock tile', (tester) async {
      await mountLook(tester, card);

      await tester.tap(find.byType(HelpButton));
      await tester.pumpAndSettle();

      expect(find.text('Facts layout'), findsOneWidget);
      expect(find.text('Key points layout'), findsOneWidget);
      expect(find.text('Cover header'), findsOneWidget);
      expect(find.text('Locked cover'), findsOneWidget);
    });
  });
}

class _BytesResolver implements IAttachmentResolver {
  _BytesResolver(this.bytes);
  final Uint8List bytes;
  @override
  Future<Uint8List?> resolve(AttachmentRef ref) async => bytes;
}

class _StubVault extends VaultSessionController {
  _StubVault(this._status);
  final VaultStatus _status;
  @override
  VaultStatus build() => _status;
  @override
  Future<void> refresh() async => state = _status;
}

/// Captures debugPrint output for [body], restoring it before returning (the
/// widget binding checks debugPrint is unchanged before tear-downs run).
Future<List<String>> _captureLogs(Future<void> Function() body) async {
  final logs = <String>[];
  final saved = debugPrint;
  debugPrint = (String? m, {int? wrapWidth}) => logs.add(m ?? '');
  try {
    await body();
  } finally {
    debugPrint = saved;
  }
  return logs;
}
