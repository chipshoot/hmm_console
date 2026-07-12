import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/picker/image_attachment_picker.dart';
import 'package:hmm_console/core/data/attachments/picker/image_byte_source.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/core/data/note_location.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/data/subsystem_anchor.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:hmm_console/features/notes/presentation/widgets/media_toolbar.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';

final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M8AAAMBAQDJ/pLvAAAAAElFTkSuQmCC');

class _FakeSource implements ImageByteSource {
  @override
  Future<PickedImageBytes?> pick(AttachmentPickSource source) async =>
      PickedImageBytes(bytes: _png, originalName: 'a.jpg');
}

class _FakeMutate implements MutateNote {
  int persistCalls = 0;
  int setAttachmentsCalls = 0;
  NoteAttachments? lastAttachments;
  String? lastBody;

  @override
  Future<HmmNote> createGeneral(
      {required String subject,
      String? markdownBody,
      int? parentNoteId,
      DateTime? noteDate,
      NoteLocation? location}) async {
    lastBody = markdownBody;
    return HmmNote(
        id: 1, uuid: 'u', subject: subject, authorId: 1,
        createDate: DateTime(2026, 1, 1));
  }

  @override
  Future<HmmNote> updateGeneral(int id,
      {String? subject,
      String? markdownBody,
      DateTime? noteDate,
      NoteLocation? location}) async {
    lastBody = markdownBody;
    return HmmNote(
        id: 1, uuid: 'u', subject: 's', authorId: 1,
        createDate: DateTime(2026, 1, 1));
  }

  /// When true, persisting throws (e.g. an oversize photo).
  bool throwOnPersist = false;

  @override
  Future<VaultRef> persistInlineImage(int noteId, PickedImageBytes pick) async {
    persistCalls++;
    if (throwOnPersist) throw Exception('too big');
    return const VaultRef(
        path: 'attachments/note-1/a.jpg',
        contentType: 'image/jpeg',
        byteSize: 3);
  }

  @override
  Future<HmmNote?> setAttachments(int noteId, NoteAttachments atts) async {
    setAttachmentsCalls++;
    lastAttachments = atts;
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

GoRouter _router() => GoRouter(
      initialLocation: '/editor',
      routes: [
        GoRoute(
          path: '/',
          builder: (c, s) => const Scaffold(body: Text('home')),
          routes: [
            GoRoute(
                path: 'editor', builder: (c, s) => const NoteEditorScreen()),
          ],
        ),
      ],
    );

Future<void> _pump(WidgetTester tester, MutateNote mutate) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      mutateNoteProvider.overrideWithValue(mutate),
      imageByteSourceProvider.overrideWithValue(_FakeSource()),
      subsystemAnchorsProvider.overrideWith((ref) async => const []),
    ],
    child: MaterialApp.router(
      routerConfig: _router(),
      theme: ThemeData(extensions: const [AppColors.light]),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('picking an image inserts it inline; save persists + rewrites',
      (tester) async {
    final fake = _FakeMutate();
    await _pump(tester, fake);

    // Add a photo (gallery) — it is inserted inline, not as a trailing card.
    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    await tester.pumpAndSettle();

    final body = find.widgetWithText(TextField, 'Start writing…');
    final bodyText = tester.widget<TextField>(body).controller!.text;
    expect(bodyText, contains('hmm-attachment://pending/'));
    expect(find.byType(Image), findsWidgets); // live preview renders the image

    // Enter subject and save → the inline pick is persisted and rewritten.
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Hello');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(fake.persistCalls, 1);
    expect(fake.setAttachmentsCalls, 1);
    expect(fake.lastAttachments!.images.whereType<VaultRef>().map((r) => r.path),
        contains('attachments/note-1/a.jpg'));
    expect(fake.lastBody, contains('attachments/note-1/a.jpg'));
    expect(fake.lastBody, isNot(contains('pending/')));
  });

  testWidgets('a failed image pick never leaves pending/ in saved content',
      (tester) async {
    final fake = _FakeMutate()..throwOnPersist = true;
    await _pump(tester, fake);

    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Hello');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // The persisted body was rewritten to strip the failed placeholder — no
    // `pending/` survives, and the image ref was not added.
    expect(fake.lastBody, isNotNull);
    expect(fake.lastBody, isNot(contains('pending/')));
    expect(fake.lastBody, isNot(contains('hmm-attachment://')));
    expect(fake.setAttachmentsCalls, 0);
    expect(find.textContaining("couldn't be added"), findsOneWidget);
  });

  testWidgets(
      'body stays inside a scrollable after adding inline images', (tester) async {
    await _pump(tester, _FakeMutate());

    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    await tester.pumpAndSettle();

    final body = find.widgetWithText(TextField, 'Start writing…');
    final bodyText = tester.widget<TextField>(body).controller!.text;
    expect('hmm-attachment://pending/'.allMatches(bodyText).length, 2);

    expect(body, findsOneWidget);
    expect(
      find.ancestor(of: body, matching: find.byType(SingleChildScrollView)),
      findsOneWidget,
    );
  });

  testWidgets(
      'media toolbar rides in the body (not a bottomNavigationBar)',
      (tester) async {
    await _pump(tester, _FakeMutate());

    final scaffold = tester.widget<Scaffold>(
      find.descendant(
        of: find.byType(NoteEditorScreen),
        matching: find.byType(Scaffold),
      ),
    );
    expect(scaffold.bottomNavigationBar, isNull);
    expect(find.byType(MediaToolbar), findsOneWidget);
  });

  testWidgets(
      'keyboard-hide button shows only while the keyboard is up and dismisses it',
      (tester) async {
    await _pump(tester, _FakeMutate());

    final body = find.widgetWithText(TextField, 'Start writing…');
    await tester.tap(body);
    await tester.pump();
    expect(tester.widget<TextField>(body).focusNode!.hasFocus, isTrue);

    expect(find.byIcon(Icons.keyboard_hide_outlined), findsNothing);
    expect(find.text('Attach to subsystem'), findsOneWidget);

    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    addTearDown(tester.view.reset);
    await tester.pump();

    expect(find.byIcon(Icons.keyboard_hide_outlined), findsOneWidget);
    expect(find.text('Attach to subsystem'), findsNothing);
    await tester.tap(find.byIcon(Icons.keyboard_hide_outlined));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(body).focusNode!.hasFocus, isFalse);
  });
}
