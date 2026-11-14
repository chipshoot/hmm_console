import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/resolver/attachment_resolver.dart';
import 'package:hmm_console/core/data/attachments/video_attachment.dart';
import 'package:hmm_console/core/data/attachments/widgets/sensitive_attachment_image.dart';
import 'package:hmm_console/core/notes/note_state.dart';
import 'package:hmm_console/core/settings/app_settings.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_preview_text.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_row.dart';
import 'package:hmm_console/features/notes/query/note_results.dart';
import 'package:hmm_console/features/notes/rendering/note_display.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

class _NullResolver implements IAttachmentResolver {
  @override
  Future<Uint8List?> resolve(AttachmentRef ref) async => null;
}

class _FakeEntry implements NoteDisplayEntry {
  @override
  NoteDisplay display(HmmNote note, AppLocalizations l) =>
      (title: 'Dr Zhang', preview: 'Doctor · +1 555 0100');
  @override
  String title(HmmNote note, AppLocalizations l) => 'Dr Zhang';
  @override
  NoteTarget? target(HmmNote note) => null;
}

final _now = DateTime(2026, 6, 15, 12);

HmmNote _note({
  String content = 'Milk and eggs',
  NoteAttachments? attachments,
  DateTime? date,
  double? lat,
  String? place,
}) => HmmNote(
  id: 1,
  uuid: 'u1',
  subject: 'Grocery',
  authorId: 1,
  createDate: date ?? DateTime(2026, 6, 15, 9, 30),
  content: content,
  attachments: attachments,
  latitude: lat,
  longitude: lat,
  locationLabel: place,
);

NoteHit _hit(
  HmmNote note, {
  String title = 'Grocery',
  bool pinned = false,
  int? flag,
  List<TextRange> titleMatches = const [],
}) => NoteHit(
  note: note,
  title: title,
  state: NoteState(
    noteUuid: note.uuid,
    isPinned: pinned,
    flagColor: flag,
    lastModifiedDate: DateTime(2026),
  ),
  titleMatches: titleMatches,
);

Widget _host(
  NoteHit hit, {
  NoteRowDensity density = NoteRowDensity.standard,
  String? catalogName,
  List<({int id, String name})> tags = const [],
  String? parentTitle,
  bool entity = false,
  DateTime? date,
}) => ProviderScope(
  overrides: [
    attachmentResolverProvider.overrideWith((_) async => _NullResolver()),
    if (entity)
      noteDisplayRegistryProvider.overrideWithValue(
        NoteDisplayRegistry({'Contact': _FakeEntry()}),
      ),
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(extensions: const [AppColors.light]),
    home: Scaffold(
      body: NoteRow(
        hit: hit,
        density: density,
        domainKey: 'General',
        catalogName: catalogName,
        parentTitle: parentTitle,
        tags: tags,
        date: date ?? hit.note.effectiveNoteDate,
        now: _now,
      ),
    ),
  ),
);

String _allText(WidgetTester t) => [
  for (final w in t.widgetList<RichText>(find.byType(RichText)))
    w.text.toPlainText(),
].join('|');

int _previewMaxLines(WidgetTester t) => t
    .widgetList<RichText>(find.byType(RichText))
    .where((r) => r.text.toPlainText().contains('Milk'))
    .first
    .maxLines!;

const _vault = VaultRef(
  path: 'attachments/a.jpg',
  contentType: 'image/jpeg',
  byteSize: 1,
);

void main() {
  testWidgets('standard shows 2 preview lines, compact none, rich 4 + thumb', (
    t,
  ) async {
    final note = _note(attachments: NoteAttachments(primaryImage: _vault));
    await t.pumpWidget(_host(_hit(note)));
    await t.pumpAndSettle();
    expect(_previewMaxLines(t), 2);
    expect(find.byIcon(Icons.attach_file), findsOneWidget);

    await t.pumpWidget(_host(_hit(note), density: NoteRowDensity.compact));
    await t.pumpAndSettle();
    expect(_allText(t), isNot(contains('Milk')));

    await t.pumpWidget(_host(_hit(note), density: NoteRowDensity.rich));
    await t.pumpAndSettle();
    expect(_previewMaxLines(t), 4);
    expect(
      find.byWidgetPredicate((w) => w is SizedBox && w.width == 56),
      findsOneWidget,
    );
  });

  testWidgets('no raw markdown in any density', (t) async {
    final note = _note(content: '**Bold**\n\n- [ ] task');
    for (final d in NoteRowDensity.values) {
      await t.pumpWidget(_host(_hit(note), density: d));
      await t.pumpAndSettle();
      expect(_allText(t), isNot(contains('**')));
      expect(_allText(t), isNot(contains('[ ]')));
    }
  });

  testWidgets('pin icon and coloured flag show; unknown flag shows grey', (
    t,
  ) async {
    await t.pumpWidget(_host(_hit(_note(), pinned: true, flag: 0)));
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.push_pin), findsOneWidget);
    expect(
      t.widget<Icon>(find.byIcon(Icons.flag)).color,
      const Color(0xFFFF3B30),
    );

    await t.pumpWidget(_host(_hit(_note(), flag: 99)));
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.push_pin), findsNothing);
    expect(
      t.widget<Icon>(find.byIcon(Icons.flag)).color,
      const Color(0xFF8E8E93),
    );

    await t.pumpWidget(_host(_hit(_note())));
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.flag), findsNothing);
  });

  testWidgets('meta line shows 2 tags and "+1", attachment count and place', (
    t,
  ) async {
    final note = _note(
      attachments: NoteAttachments(
        primaryImage: _vault,
        images: const [
          VaultRef(
            path: 'attachments/b.jpg',
            contentType: 'image/jpeg',
            byteSize: 1,
          ),
        ],
        files: const [
          VaultRef(
            path: 'attachments/c.pdf',
            contentType: 'application/pdf',
            byteSize: 1,
          ),
        ],
      ),
      lat: 1,
      place: 'Home',
    );
    await t.pumpWidget(
      _host(
        _hit(note),
        parentTitle: 'Civic',
        tags: const [
          (id: 1, name: 'a'),
          (id: 2, name: 'b'),
          (id: 3, name: 'c'),
        ],
      ),
    );
    await t.pumpAndSettle();
    expect(_allText(t), contains('General · Civic · '));
    expect(_allText(t), contains('a, b +1'));
    expect(_allText(t), contains(' 3'));
    expect(_allText(t), contains('Home'));
    expect(find.byIcon(Icons.sell_outlined), findsOneWidget);
    expect(find.byIcon(Icons.attach_file), findsOneWidget);
    expect(find.byIcon(Icons.place_outlined), findsOneWidget);
  });

  testWidgets('omitted meta parts leave no stray separator', (t) async {
    await t.pumpWidget(_host(_hit(_note(lat: 1))));
    await t.pumpAndSettle();
    expect(_allText(t), contains('General · '));
    expect(_allText(t), isNot(contains('·  ')));
    expect(_allText(t), isNot(contains('· |')));
  });

  testWidgets(
    'sensitive thumbnail shows a lock, never SensitiveAttachmentImage',
    (t) async {
      final note = _note(
        attachments: NoteAttachments(
          primaryImage: const VaultRef(
            path: 'attachments/sensitive/s.jpg',
            contentType: 'image/jpeg',
            byteSize: 1,
            sensitive: true,
          ),
        ),
      );
      await t.pumpWidget(_host(_hit(note), density: NoteRowDensity.rich));
      await t.pumpAndSettle();
      expect(find.byType(SensitiveAttachmentImage), findsNothing);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    },
  );

  testWidgets(
    'semantics label reads title, date, flagged colour, pinned, preview',
    (t) async {
      final handle = t.ensureSemantics();
      await t.pumpWidget(_host(_hit(_note(), pinned: true, flag: 0)));
      await t.pumpAndSettle();
      expect(
        t.getSemantics(find.byType(NoteRow)).label,
        'Grocery, 9:30 AM, flagged Red, pinned, Milk and eggs',
      );
      handle.dispose();
    },
  );

  testWidgets(
    'trailing time: today time, this year month-day, else full date',
    (t) async {
      await t.pumpWidget(_host(_hit(_note())));
      await t.pumpAndSettle();
      expect(find.text('9:30 AM'), findsOneWidget);
      await t.pumpWidget(_host(_hit(_note(date: DateTime(2026, 2, 3)))));
      await t.pumpAndSettle();
      expect(find.text('Feb 3'), findsOneWidget);
      await t.pumpWidget(_host(_hit(_note(date: DateTime(2024, 2, 3)))));
      await t.pumpAndSettle();
      expect(find.text('2/3/2024'), findsOneWidget);
    },
  );

  testWidgets('an image-only note has no blank preview line', (t) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(
      _host(_hit(_note(content: '![p](hmm-attachment://attachments/a.jpg)'))),
    );
    await t.pumpAndSettle();
    expect(find.byType(NotePreviewText), findsNothing);
    expect(t.getSemantics(find.byType(NoteRow)).label, 'Grocery, 9:30 AM');
    handle.dispose();
  });

  testWidgets('trailing time and semantics use the date passed in', (t) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(
      _host(
        _hit(_note(date: DateTime(2024, 3, 4))),
        date: DateTime(2026, 6, 15, 9, 30),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('9:30 AM'), findsOneWidget);
    expect(find.text('3/4/2024'), findsNothing);
    expect(
      t.getSemantics(find.byType(NoteRow)).label,
      startsWith('Grocery, 9:30 AM'),
    );
    handle.dispose();
  });

  testWidgets(
    'entity note row shows its display title and plain preview, not JSON',
    (t) async {
      final note = _note(content: '{"note":{"content":{"Contact":{}}}}');
      await t.pumpWidget(
        _host(
          _hit(note, title: 'Dr Zhang'),
          catalogName: 'Contact',
          entity: true,
        ),
      );
      await t.pumpAndSettle();
      expect(_allText(t), contains('Dr Zhang'));
      expect(_allText(t), contains('Doctor · +1 555 0100'));
      expect(_allText(t), isNot(contains('{')));
    },
  );

  testWidgets('title match ranges past the title are clamped, not thrown', (
    t,
  ) async {
    await t.pumpWidget(
      _host(
        _hit(
          _note(),
          title: 'Milky',
          titleMatches: const [
            TextRange(start: 2, end: 99),
            TextRange(start: -1, end: 1),
            TextRange(start: 50, end: 60),
          ],
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.textContaining('Milky', findRichText: true), findsOneWidget);
  });

  group('videos', () {
    const video = VideoAttachment(
      video: VaultRef(
        path: 'attachments/note-1/v.mov',
        contentType: 'video/quicktime',
        byteSize: 9,
      ),
      poster: VaultRef(
        path: 'attachments/note-1/v.jpg',
        contentType: 'image/jpeg',
        byteSize: 1,
      ),
      durationMs: 7633,
    );
    bool thumb(WidgetTester t) => t
        .widgetList<SizedBox>(find.byType(SizedBox))
        .any((b) => b.width == 56 && b.height == 56);

    testWidgets('meta line shows a video icon and the video count', (t) async {
      final note = _note(attachments: NoteAttachments(videos: [video, video]));
      await t.pumpWidget(_host(_hit(note)));
      await t.pumpAndSettle();

      expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
      expect(_allText(t), contains(' 2'));
      // Videos are not photos or files: no paperclip.
      expect(find.byIcon(Icons.attach_file), findsNothing);
    });

    testWidgets('rich row of a video-only note shows the poster with a play '
        'badge', (t) async {
      final note = _note(attachments: NoteAttachments(videos: [video]));
      await t.pumpWidget(_host(_hit(note), density: NoteRowDensity.rich));
      await t.pumpAndSettle();

      expect(thumb(t), isTrue);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('a photo wins the thumbnail over a video poster', (t) async {
      final note = _note(
        attachments: NoteAttachments(images: [_vault], videos: [video]),
      );
      await t.pumpWidget(_host(_hit(note), density: NoteRowDensity.rich));
      await t.pumpAndSettle();

      expect(thumb(t), isTrue);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });

    testWidgets('standard rows show no thumbnail for a video', (t) async {
      final note = _note(attachments: NoteAttachments(videos: [video]));
      await t.pumpWidget(_host(_hit(note)));
      await t.pumpAndSettle();

      expect(thumb(t), isFalse);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });
  });
}
