import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_cheatsheet_repository.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/core/navigation/cheatsheet_routes.dart';
import 'package:hmm_console/features/cheatsheet/data/cheatsheet_launcher.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_source.dart';
import 'package:hmm_console/features/cheatsheet/presentation/screens/cheatsheet_designer_screen.dart';
import 'package:hmm_console/features/cheatsheet/presentation/screens/cheatsheet_detail_screen.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';

/// End-to-end over **real** storage.
///
/// Real: Drift (in memory), LocalHmmNoteRepository, LocalCheatsheetRepository,
/// the codec, CheatsheetsState, CheatsheetEditor, CheatsheetResolver, and the
/// designer / wallet / detail widgets driven through the real route tree.
///
/// Injected: the database seam (so the app's auth + sync provider graph stays
/// out of it), plus the three side-effect adapters — launching, source
/// navigation and the note picker.
///
/// Every task above proves one seam. This proves they compose.
void main() {
  testWidgets('create, bind, save, reload, act, edit and delete a card',
      (tester) async {
    // ---- 1. a real database with a source note to reference ----------------
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final authorId = await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    final author = await (db.select(db.authors)
          ..where((a) => a.id.equals(authorId)))
        .getSingle();

    final noteRepo = LocalHmmNoteRepository(db, () async => author);
    final catalogRepo = LocalNoteCatalogRepository(db);
    final cheatRepo = LocalCheatsheetRepository(noteRepo, catalogRepo);

    final autoCatalog = await catalogRepo.getOrCreateCatalog(
      'Hmm.AutomobileMan.AutomobileInfo',
      '{}',
    );
    final sourceNote = await noteRepo.createNote(HmmNoteCreate(
      subject: 'My Car',
      catalogId: autoCatalog.id,
      content: '{"note":{"content":{"AutomobileInfo":'
          '{"plate":"ABC123","phone":"(555) 123-4567"}}}}',
    ));

    final launched = <(ValueAction, String)>[];
    final openedSources = <String>[];

    final container = ProviderContainer(
      overrides: [
        hmmNoteRepositoryProvider.overrideWithValue(noteRepo),
        cheatsheetRepositoryModeProvider.overrideWithValue(cheatRepo),
        launchActionProvider
            .overrideWithValue((a, v) async => launched.add((a, v))),
        cheatsheetOpenSourceProvider
            .overrideWithValue((_, uuid) => openedSources.add(uuid)),
        // The picker binds row 0 to the seeded note's phone field.
        cheatsheetSourcePickerProvider.overrideWithValue(
          (_) async => CheatsheetSource(
            noteUuid: sourceNote.uuid,
            kind: SourceGranularity.field,
            locator: 'AutomobileInfo.phone',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: '/cheatsheets',
      routes: cheatsheetRoutes,
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // ---- 2. create from a template; the id is minted, never supplied -------
    router.push('/cheatsheets/new');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('template-accidentClaim')));
    await tester.pumpAndSettle();

    // ---- 3. bind one row, give it an action, leave the rest unbound --------
    await tester.tap(find.byKey(const Key('row-0-bind')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('row-0-action-call')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('designer-title')), 'Accident Claim');
    await tester.pumpAndSettle();

    // ---- 4. save: exactly one card, stored under a stable subject ----------
    await tester.tap(find.byKey(const Key('designer-save')));
    await tester.pumpAndSettle();

    final storedAfterCreate = await cheatRepo.getCards();
    expect(storedAfterCreate.length, 1);
    final cardId = storedAfterCreate.single.id;
    expect(cardId, isNotEmpty);
    expect(
        storedAfterCreate.single.rows.first.source?.noteUuid, sourceNote.uuid);
    expect(storedAfterCreate.single.rows.skip(1).every((r) => !r.isBound), isTrue,
        reason: 'a partially bound card is savable');

    final notes = await _cheatsheetNotes(noteRepo, catalogRepo);
    expect(notes.length, 1);
    expect(notes.single.subject, 'Cheatsheet:$cardId');

    // ---- 5. reload through a *fresh* repository — nothing cached -----------
    final reloaded =
        await LocalCheatsheetRepository(noteRepo, catalogRepo).getCard(cardId);
    expect(reloaded, isNotNull);
    expect(reloaded!.title, 'Accident Claim');

    // ---- 6. the wallet lists it, and search finds it ----------------------
    router.go('/cheatsheets');
    await tester.pumpAndSettle();

    expect(find.byKey(Key('wallet-card-$cardId')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('wallet-search')), 'accident');
    await tester.pumpAndSettle();
    expect(find.byKey(Key('wallet-card-$cardId')), findsOneWidget);

    // ---- 7. the detail resolves the real value from the real note ---------
    await tester.tap(find.byKey(Key('wallet-card-$cardId')));
    await tester.pumpAndSettle();

    expect(find.byType(CheatsheetDetailScreen), findsOneWidget);
    expect(find.text('(555) 123-4567'), findsOneWidget,
        reason: 'resolved live from the source note by uuid');
    expect(find.byKey(const Key('row-1-unbound')), findsOneWidget);

    // ---- 8. acting on a value reaches the launcher ------------------------
    await tester.tap(find.byKey(const Key('row-0-value')));
    await tester.pumpAndSettle();
    expect(launched, [(ValueAction.call, '(555) 123-4567')]);

    // ---- 9. edit: same card, renamed — not a second card ------------------
    await tester.tap(find.byKey(const Key('detail-edit')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('designer-title')), 'Renamed');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('designer-save')));
    await tester.pumpAndSettle();

    final afterEdit = await cheatRepo.getCards();
    expect(afterEdit.length, 1, reason: 'editing must not duplicate');
    expect(afterEdit.single.id, cardId, reason: 'identity survives an edit');
    expect(afterEdit.single.title, 'Renamed');
    expect((await _cheatsheetNotes(noteRepo, catalogRepo)).single.subject,
        'Cheatsheet:$cardId',
        reason: 'the subject is an identity, not a label');

    // ---- 10. delete through the UI: gone from the wallet and the catalog --
    // Saving the edit popped back to the detail screen.
    expect(find.byType(CheatsheetDetailScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('detail-delete')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget,
        reason: 'deletion is confirmed, not immediate');
    await tester.tap(find.byKey(const Key('delete-confirm')));
    await tester.pumpAndSettle();

    // Asserted BEFORE any manual navigation below: the screen must leave on
    // its own, or the user is stranded on a card that no longer exists.
    // Navigating first would mask a missing pop entirely.
    expect(find.byType(CheatsheetDetailScreen), findsNothing,
        reason: 'deleting pops the detail screen');

    expect(await cheatRepo.getCards(), isEmpty);
    expect(await _cheatsheetNotes(noteRepo, catalogRepo), isEmpty);

    // The source note it referenced must survive — a card is a view onto
    // notes, not a container for them.
    expect(await noteRepo.getNoteByUuid(sourceNote.uuid), isNotNull);

    router.go('/cheatsheets');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet-empty')), findsOneWidget);
  });
}

/// Reads the cheatsheet catalog's notes directly, paging to exhaustion.
Future<List<HmmNote>> _cheatsheetNotes(
  LocalHmmNoteRepository notes,
  LocalNoteCatalogRepository catalogs,
) async {
  final catalog = await catalogs.getOrCreateCatalog(cheatsheetCatalogName, '{}');
  final out = <HmmNote>[];
  var page = 1;
  while (true) {
    final res =
        await notes.getNotes(catalogId: catalog.id, page: page, pageSize: 100);
    out.addAll(res.items);
    if (res.items.isEmpty || page >= res.meta.totalPages) break;
    page++;
  }
  return out;
}
