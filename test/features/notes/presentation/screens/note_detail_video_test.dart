import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/video/video_platform.dart';
import 'package:hmm_console/core/data/attachments/video_attachment.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/core/data/vault/vault_file_store.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_detail_screen.dart';
import 'package:hmm_console/features/notes/presentation/widgets/video_tile.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

import '../../../../core/data/attachments/video/fake_video_platform.dart';

const _video = VideoAttachment(
  video: VaultRef(
    path: 'attachments/note-1/u1.mov',
    contentType: 'video/quicktime',
    byteSize: 5,
  ),
  poster: VaultRef(
    path: 'attachments/note-1/u1.jpg',
    contentType: 'image/jpeg',
    byteSize: 5,
  ),
  durationMs: 48000,
);

const _line = '![Video](hmm-attachment://attachments/note-1/u1.jpg)';

class _Repo {
  _Repo(String body, NoteAttachments atts) : note = _make(body, atts);
  HmmNote note;

  static HmmNote _make(String body, NoteAttachments atts) => HmmNote(
    id: 1,
    uuid: 'u',
    subject: 'Trip',
    authorId: 1,
    catalogId: 1,
    content: body,
    createDate: DateTime(2026),
    attachments: atts,
  );
}

class _FakeNoteRepo implements IHmmNoteRepository {
  _FakeNoteRepo(this.state);
  final _Repo state;
  @override
  dynamic noSuchMethod(Invocation i) {
    switch (i.memberName) {
      case #getNoteById:
        return Future.value(state.note);
      case #updateNote:
        final u = i.positionalArguments[1] as HmmNoteUpdate;
        state.note = _Repo._make(
          u.content ?? state.note.content ?? '',
          u.attachments ?? state.note.effectiveAttachments,
        );
        return Future.value(state.note);
    }
    return super.noSuchMethod(i);
  }
}

class _Files implements IVaultFileStore {
  _Files(this.file);
  final File? file;
  @override
  Future<void> importFile(String p, File s) async {}
  @override
  Future<File?> localFile(String p) async => file;
}

final _catalog = NoteCatalog(
  id: 1,
  name: 'General',
  schema: '{}',
  formatType: 3,
  isDefault: false,
);

Future<_Repo> _pump(
  WidgetTester tester, {
  required String body,
  required NoteAttachments atts,
  FakeVideoPlatform? platform,
  File? file,
}) async {
  final repo = _Repo(body, atts);
  final fake = _FakeNoteRepo(repo);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        videoPlatformProvider.overrideWithValue(
          platform ?? FakeVideoPlatform(),
        ),
        vaultFileStoreProvider.overrideWith((ref) async => _Files(file)),
        hmmNoteRepositoryProvider.overrideWithValue(fake),
        noteDetailProvider(1).overrideWith(
          (ref) async => NoteDetailData(
            await ref.watch(hmmNoteRepositoryProvider).getNoteById(1)
                as HmmNote,
            _catalog,
          ),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(extensions: const [AppColors.light]),
        home: const NoteDetailScreen(noteId: 1),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('long press shows the three menu items', (tester) async {
    await _pump(
      tester,
      body: 'hi\n\n$_line\n\nbye',
      atts: NoteAttachments(videos: [_video]),
    );
    await tester.longPress(find.byType(VideoTile));
    await tester.pumpAndSettle();
    expect(find.text('Save to Photos'), findsOneWidget);
    expect(find.text('Share…'), findsOneWidget);
    expect(find.text('Remove from note'), findsOneWidget);
  });

  testWidgets('remove then undo restores body and entry', (tester) async {
    final repo = await _pump(
      tester,
      body: 'hi\n\n$_line\n\nbye',
      atts: NoteAttachments(videos: [_video]),
    );
    await tester.longPress(find.byType(VideoTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from note'));
    await tester.pumpAndSettle();
    expect(repo.note.content, isNot(contains('u1.jpg')));
    expect(repo.note.effectiveAttachments.videos, isEmpty);
    expect(find.byType(VideoTile), findsNothing);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(repo.note.content, 'hi\n\n$_line\n\nbye');
    expect(repo.note.effectiveAttachments.videos, [_video]);
    expect(find.byType(VideoTile), findsOneWidget);
  });

  testWidgets('a video not inline is listed below the body', (tester) async {
    await _pump(
      tester,
      body: 'just text',
      atts: NoteAttachments(videos: [_video]),
    );
    expect(find.byType(VideoTile), findsOneWidget);
  });

  Future<void> choose(WidgetTester tester, String item) async {
    await tester.longPress(find.byType(VideoTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item));
    await tester.pumpAndSettle();
  }

  const notOnDevice =
      'This video is only on the device that added it, for now.';

  testWidgets('Share with the file missing says not on device', (
    tester,
  ) async {
    await _pump(
      tester,
      body: 'hi\n\n$_line',
      atts: NoteAttachments(videos: [_video]),
    );
    await choose(tester, 'Share…');
    expect(find.text(notOnDevice), findsOneWidget);
  });

  testWidgets('Save with the file missing says not on device', (tester) async {
    final platform = FakeVideoPlatform();
    await _pump(
      tester,
      body: 'hi\n\n$_line',
      atts: NoteAttachments(videos: [_video]),
      platform: platform,
    );
    await choose(tester, 'Save to Photos');
    expect(find.text(notOnDevice), findsOneWidget);
    expect(platform.saved, isEmpty);
  });

  for (final ok in [true, false]) {
    testWidgets('Save to Photos ${ok ? 'saved' : 'denied'}', (tester) async {
      final platform = FakeVideoPlatform(saveResult: ok);
      await _pump(
        tester,
        body: 'hi\n\n$_line',
        atts: NoteAttachments(videos: [_video]),
        platform: platform,
        file: File('/v/u1.mov'),
      );
      await choose(tester, 'Save to Photos');
      expect(platform.saved, ['/v/u1.mov']);
      expect(
        find.text(
          ok
              ? 'Saved to Photos'
              : "Hmm can't add to Photos. Allow it in Settings.",
        ),
        findsOneWidget,
      );
    });
  }
}
