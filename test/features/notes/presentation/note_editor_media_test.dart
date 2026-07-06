import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/attachments/picker/image_attachment_picker.dart';
import 'package:hmm_console/core/data/attachments/picker/image_byte_source.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/core/data/note_location.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/data/subsystem_anchor.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:hmm_console/features/notes/presentation/widgets/media_toolbar.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_media_card_list.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';

final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M8AAAMBAQDJ/pLvAAAAAElFTkSuQmCC');

class _FakeSource implements ImageByteSource {
  @override
  Future<PickedImageBytes?> pick(AttachmentPickSource source) async =>
      PickedImageBytes(bytes: _png, originalName: 'a.jpg');
}

class _FakeMutate implements MutateNote {
  int attachCalls = 0;
  @override
  Future<HmmNote> createGeneral(
      {required String subject,
      String? markdownBody,
      int? parentNoteId,
      DateTime? noteDate,
      NoteLocation? location}) async {
    return HmmNote(
        id: 1, uuid: 'u', subject: subject, authorId: 1,
        createDate: DateTime(2026, 1, 1));
  }

  @override
  Future<HmmNote?> attachImageBytes(int noteId, PickedImageBytes pick) async {
    attachCalls++;
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  testWidgets('add photo shows a pending card before save; save attaches it',
      (tester) async {
    final fake = _FakeMutate();
    final router = GoRouter(
      initialLocation: '/editor',
      routes: [
        GoRoute(
          path: '/',
          builder: (c, s) => const Scaffold(body: Text('home')),
          routes: [
            GoRoute(path: 'editor', builder: (c, s) => const NoteEditorScreen()),
          ],
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        mutateNoteProvider.overrideWithValue(fake),
        imageByteSourceProvider.overrideWithValue(_FakeSource()),
        subsystemAnchorsProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(extensions: const [AppColors.light]),
      ),
    ));
    await tester.pumpAndSettle();

    // Add a photo (gallery) — no subject yet.
    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(NoteMediaCard), findsOneWidget); // pending card shown

    // Enter subject and save → the pending pick is attached.
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Hello');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(fake.attachCalls, 1);
  });

  testWidgets(
      'body stays inside a scrollable after adding images (reachable above the keyboard)',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/editor',
      routes: [
        GoRoute(
          path: '/',
          builder: (c, s) => const Scaffold(body: Text('home')),
          routes: [
            GoRoute(path: 'editor', builder: (c, s) => const NoteEditorScreen()),
          ],
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        mutateNoteProvider.overrideWithValue(_FakeMutate()),
        imageByteSourceProvider.overrideWithValue(_FakeSource()),
        subsystemAnchorsProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(extensions: const [AppColors.light]),
      ),
    ));
    await tester.pumpAndSettle();

    // Add two photos — each is a tall (180px) card that fills the page.
    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(NoteMediaCard), findsNWidgets(2));

    // The content field must remain present and inside the page's
    // SingleChildScrollView, so a focus/keyboard scrolls it into view above the
    // keyboard instead of being squeezed to nothing (the old Expanded layout
    // had no scrollable ancestor).
    final body = find.widgetWithText(TextField, 'Start writing…');
    expect(body, findsOneWidget);
    expect(
      find.ancestor(of: body, matching: find.byType(SingleChildScrollView)),
      findsOneWidget,
    );

    // Tapping the empty canvas below the body still focuses it
    // ("tap anywhere to write"), even though the body no longer fills the page.
    final bodyWidget = tester.widget<TextField>(body);
    expect(bodyWidget.focusNode, isNotNull);
    final scrollRect = tester.getRect(find.byType(SingleChildScrollView));
    await tester.tapAt(scrollRect.bottomCenter - const Offset(0, 8));
    await tester.pumpAndSettle();
    expect(bodyWidget.focusNode!.hasFocus, isTrue);
  });

  testWidgets(
      'media toolbar rides in the body (not a bottomNavigationBar) so the '
      'keyboard cannot cover it', (tester) async {
    await _pumpEditor(tester);

    // The toolbar must NOT be the Scaffold.bottomNavigationBar — that always
    // sits behind the software keyboard. It lives in the body instead, where
    // resizeToAvoidBottomInset lifts it above the keyboard.
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
    await _pumpEditor(tester);

    // Focus the body — the keyboard would come up on a real device.
    final body = find.widgetWithText(TextField, 'Start writing…');
    await tester.tap(body);
    await tester.pump();
    expect(tester.widget<TextField>(body).focusNode!.hasFocus, isTrue);

    // No keyboard inset yet → no hide button (avoids a dead control), and the
    // subsystem strip is shown.
    expect(find.byIcon(Icons.keyboard_hide_outlined), findsNothing);
    expect(find.text('Attach to subsystem'), findsOneWidget);

    // Simulate the software keyboard raising the bottom view inset.
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    addTearDown(tester.view.reset);
    await tester.pump();

    // The hide button appears; the subsystem strip collapses to free writing
    // space and keep MediaToolbar the only fixed child (no overflow).
    expect(find.byIcon(Icons.keyboard_hide_outlined), findsOneWidget);
    expect(find.text('Attach to subsystem'), findsNothing);
    await tester.tap(find.byIcon(Icons.keyboard_hide_outlined));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(body).focusNode!.hasFocus, isFalse);
  });
}

Future<void> _pumpEditor(WidgetTester tester) async {
  final router = GoRouter(
    initialLocation: '/editor',
    routes: [
      GoRoute(
        path: '/',
        builder: (c, s) => const Scaffold(body: Text('home')),
        routes: [
          GoRoute(path: 'editor', builder: (c, s) => const NoteEditorScreen()),
        ],
      ),
    ],
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [
      mutateNoteProvider.overrideWithValue(_FakeMutate()),
      imageByteSourceProvider.overrideWithValue(_FakeSource()),
      subsystemAnchorsProvider.overrideWith((ref) async => const []),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(extensions: const [AppColors.light]),
    ),
  ));
  await tester.pumpAndSettle();
}
