import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/video/video_platform.dart';
import 'package:hmm_console/core/data/attachments/video_attachment.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
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
}) async {
  final repo = _Repo(body, atts);
  final fake = _FakeNoteRepo(repo);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        videoPlatformProvider.overrideWithValue(FakeVideoPlatform()),
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
}
