import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/video_attachment.dart';
import 'package:hmm_console/core/notes/note_state.dart';
import 'package:hmm_console/core/settings/app_settings.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_row.dart';
import 'package:hmm_console/features/notes/query/note_results.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

VideoAttachment _v(int? ms) => VideoAttachment(
  video: const VaultRef(
    path: 'attachments/n/v.mov',
    contentType: 'video/quicktime',
    byteSize: 9,
  ),
  durationMs: ms,
);

void main() {
  group('videoListMark', () {
    test('one video shows its length', () {
      expect(videoListMark([_v(48000)]), '0:48');
    });

    test('several videos show the count and the summed known lengths', () {
      expect(videoListMark([_v(60000), _v(75000), _v(null)]), '3 · 2:15');
    });

    test('several videos without lengths show the count only', () {
      expect(videoListMark([_v(null), _v(null)]), '2');
    });

    test('one video without a length shows the count', () {
      expect(videoListMark([_v(null)]), '1');
    });
  });

  testWidgets('a row shows the video length beside the video icon', (t) async {
    final note = HmmNote(
      id: 1,
      uuid: 'u1',
      subject: 'Grocery',
      authorId: 1,
      createDate: DateTime(2026, 6, 15, 9, 30),
      content: 'Milk',
      attachments: NoteAttachments(videos: [_v(48000)]),
    );
    final hit = NoteHit(
      note: note,
      title: 'Grocery',
      state: NoteState(noteUuid: 'u1', lastModifiedDate: DateTime(2026)),
      titleMatches: const [],
    );
    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(extensions: const [AppColors.light]),
          home: Scaffold(
            body: NoteRow(
              hit: hit,
              density: NoteRowDensity.standard,
              domainKey: 'General',
              catalogName: null,
              parentTitle: null,
              tags: const [],
              date: note.effectiveNoteDate,
              now: DateTime(2026, 6, 15, 12),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
    final text = [
      for (final w in t.widgetList<RichText>(find.byType(RichText)))
        w.text.toPlainText(),
    ].join('|');
    expect(text, contains('0:48'));
  });
}
