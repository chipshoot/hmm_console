import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/core/data/local/local_note_state_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_detail_screen.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

const _banner = 'This note was moved to Recently Deleted';

/// Drift streams need real time; widgets need pumps. Alternate until
/// [done] holds (at most ~10 s).
Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('tapping Restore on a real deleted note clears the banner', (
    tester,
  ) async {
    late HmmDatabase db;
    late int noteId;
    late ProviderContainer container;
    await tester.runAsync(() async {
      db = HmmDatabase(NativeDatabase.memory());
      final authorId = await db
          .into(db.authors)
          .insert(AuthorsCompanion.insert(accountName: 'tester'));
      final author = await (db.select(
        db.authors,
      )..where((a) => a.id.equals(authorId))).getSingle();
      final repo = LocalHmmNoteRepository(db, () async => author);
      final note = await repo.createNote(
        const HmmNoteCreate(subject: 's', catalogId: 1, content: 'c'),
      );
      noteId = note.id;
      await repo.deleteNote(noteId);
      container = ProviderContainer(
        overrides: [
          hmmNoteRepositoryProvider.overrideWithValue(repo),
          noteCatalogRepositoryProvider.overrideWithValue(
            LocalNoteCatalogRepository(db),
          ),
          noteStateRepositoryProvider.overrideWithValue(
            LocalNoteStateRepository(db),
          ),
        ],
      );
    });
    addTearDown(() => tester.runAsync(db.close));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(extensions: const [AppColors.light]),
          home: NoteDetailScreen(noteId: noteId),
        ),
      ),
    );
    await _until(tester, () => find.text(_banner).evaluate().isNotEmpty);
    expect(find.text(_banner), findsOneWidget);

    await tester.tap(find.text('Restore'));
    await _until(
      tester,
      () => find.text('Note restored').evaluate().isNotEmpty,
    );
    await _until(tester, () => find.text(_banner).evaluate().isEmpty);

    expect(find.text('Note restored'), findsOneWidget);
    expect(find.text(_banner), findsNothing);

    // Unmount so drift's stream-cleanup timers and the snackbar can finish.
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(seconds: 10));
  });
}
