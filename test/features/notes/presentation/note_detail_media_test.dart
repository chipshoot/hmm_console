import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/resolver/attachment_resolver.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_detail_screen.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_media_card_list.dart';

/// Resolver stub so the card resolves (no path_provider in tests).
class _FakeResolver implements IAttachmentResolver {
  @override
  Future<Uint8List?> resolve(AttachmentRef ref) async => null;
}

void main() {
  testWidgets('detail renders attachments as media cards', (tester) async {
    final note = HmmNote(
      id: 1, uuid: 'u', subject: 'Car', authorId: 1,
      createDate: DateTime(2026, 1, 1),
      attachments: NoteAttachments(
          primaryImage: const VaultRef(
              path: 'attachments/note-1/a.jpg',
              contentType: 'image/jpeg',
              byteSize: 9)),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        noteDetailProvider(1)
            .overrideWith((ref) async => NoteDetailData(note, null)),
        attachmentResolverProvider.overrideWith((ref) async => _FakeResolver()),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: const [AppColors.light]),
        home: const NoteDetailScreen(noteId: 1),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(NoteMediaCardList), findsOneWidget);
    expect(find.byType(NoteMediaCard), findsOneWidget);
  });

  testWidgets('an inline-referenced image is not also shown as a trailing card',
      (tester) async {
    const inline = VaultRef(
        path: 'attachments/note-1/a.jpg',
        contentType: 'image/jpeg',
        byteSize: 9);
    const other = VaultRef(
        path: 'attachments/note-1/b.jpg',
        contentType: 'image/jpeg',
        byteSize: 9);
    final note = HmmNote(
      id: 1, uuid: 'u', subject: 'Car', authorId: 1, catalogId: 1,
      content:
          'intro\n\n![a](hmm-attachment://attachments/note-1/a.jpg)\n\noutro',
      createDate: DateTime(2026, 1, 1),
      attachments: NoteAttachments(images: const [inline, other]),
    );
    final catalog = NoteCatalog(
        id: 1, name: 'General', schema: '{}', formatType: 3, isDefault: false);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        noteDetailProvider(1)
            .overrideWith((ref) async => NoteDetailData(note, catalog)),
        attachmentResolverProvider.overrideWith((ref) async => _FakeResolver()),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: const [AppColors.light]),
        home: const NoteDetailScreen(noteId: 1),
      ),
    ));
    await tester.pumpAndSettle();

    // Only the non-inline image (b.jpg) shows as a trailing card; a.jpg renders
    // inline in the body instead.
    expect(find.byType(NoteMediaCard), findsOneWidget);
  });
}
