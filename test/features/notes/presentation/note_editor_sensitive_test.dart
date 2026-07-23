// Task B5 regression test: a sensitive image staged while the vault is
// unlocked, then the session relocks (5-min inactivity / app-backgrounded)
// BEFORE the note is saved. The save path must run the unlock flow before
// resolveAndRewrite ever touches the picker/vault — a VaultLockedException
// must never reach InlineImageController's strip-on-failure path. See the
// binding constraint in .superpowers/sdd/task-B5-brief.md.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/picker/image_attachment_picker.dart';
import 'package:hmm_console/core/data/attachments/picker/image_byte_source.dart';
import 'package:hmm_console/core/data/note_location.dart';
import 'package:hmm_console/core/data/vault/encrypted_vault_store.dart'
    show VaultLockedException;
import 'package:hmm_console/core/data/vault/vault_session.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/data/subsystem_anchor.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';

final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M8AAAMBAQDJ/pLvAAAAAElFTkSuQmCC');

class _FakeSource implements ImageByteSource {
  @override
  Future<PickedImageBytes?> pick(AttachmentPickSource source) async =>
      PickedImageBytes(bytes: _png, originalName: 'sensitive.jpg');
}

class _FakeMutate implements MutateNote {
  _FakeMutate({this.throwLockedOnPersist = false});

  /// Models the residual TOCTOU: the top-of-`_save()` guard already saw the
  /// vault unlocked, but auto-lock fires during one of the awaits between
  /// the guard and the actual persist call (e.g. mid `createGeneral`), so
  /// `persistInlineImage` — standing in for the real
  /// `EncryptedVaultStore.putBytes` — sees it locked and throws.
  final bool throwLockedOnPersist;

  int persistCalls = 0;
  bool? lastSensitive;
  String? lastBody;

  @override
  Future<HmmNote> createGeneral({
    required String subject,
    String? markdownBody,
    int? parentNoteId,
    DateTime? noteDate,
    NoteLocation? location,
  }) async {
    lastBody = markdownBody;
    return HmmNote(
        id: 1, uuid: 'u', subject: subject, authorId: 1,
        createDate: DateTime(2026, 1, 1), content: markdownBody);
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
        createDate: DateTime(2026, 1, 1), content: markdownBody);
  }

  @override
  Future<VaultRef> persistInlineImage(int noteId, PickedImageBytes pick) async {
    persistCalls++;
    lastSensitive = pick.sensitive;
    if (throwLockedOnPersist) {
      throw const VaultLockedException('attachments/note-1/sensitive/a.jpg');
    }
    return const VaultRef(
        path: 'attachments/note-1/sensitive/a.jpg',
        contentType: 'image/jpeg',
        byteSize: 3,
        sensitive: true);
  }

  @override
  Future<HmmNote?> setAttachments(int noteId, NoteAttachments atts) async =>
      null;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Deterministic fake session controller — no biometric platform channel.
/// `state` genuinely transitions (via the inherited Notifier `state =`
/// setter) so a direct `.lockNow()` call between staging and save models a
/// real relock, and the editor's next `ref.read(vaultSessionProvider)`
/// observes it.
class _FakeVaultSessionController extends VaultSessionController {
  _FakeVaultSessionController({
    required VaultStatus initial,
    this.biometricSucceeds = true,
    this.passphraseSucceeds = true,
  }) : _initial = initial;

  final VaultStatus _initial;
  bool biometricSucceeds;
  bool passphraseSucceeds;
  int biometricAttempts = 0;
  int passphraseAttempts = 0;

  @override
  VaultStatus build() => _initial;

  /// Overridden so _ensureVaultUnlocked's refresh()-before-read (the
  /// blocker fix) is a no-op here: this fake's `state` is driven explicitly
  /// (via `build`, `lockNow()`, and the unlock overrides below) to model
  /// the exact relock timing each test needs, and the base refresh() would
  /// otherwise reach vaultKeyServiceProvider, which these tests never
  /// override, and clobber that modeled state.
  @override
  Future<void> refresh() async {}

  @override
  Future<bool> unlockWithBiometric() async {
    biometricAttempts++;
    if (!biometricSucceeds) return false;
    state = VaultStatus.unlocked;
    return true;
  }

  @override
  Future<bool> unlockWithPassphrase(String passphrase) async {
    passphraseAttempts++;
    if (!passphraseSucceeds) return false;
    state = VaultStatus.unlocked;
    return true;
  }

  @override
  void lockNow() {
    state = VaultStatus.locked;
  }
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

Future<void> _pump(
  WidgetTester tester,
  MutateNote mutate,
  _FakeVaultSessionController controller,
) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      mutateNoteProvider.overrideWithValue(mutate),
      imageByteSourceProvider.overrideWithValue(_FakeSource()),
      subsystemAnchorsProvider.overrideWith((ref) async => const []),
      vaultSessionProvider.overrideWith(() => controller),
    ],
    child: MaterialApp.router(
      routerConfig: _router(),
      theme: ThemeData(extensions: const [AppColors.light]),
    ),
  ));
  await tester.pumpAndSettle();
}

/// Stages a sensitive image via the toolbar's lock icon, entering a title
/// first so Save won't bail out on the subject-required check.
Future<void> _stageSensitiveImage(WidgetTester tester) async {
  await tester.enterText(
      find.widgetWithText(TextField, 'Title'), 'Sensitive note');
  await tester.tap(find.byIcon(Icons.lock_outline));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'save with a relocked vault runs the unlock flow and persists the '
      'sensitive image (placeholder rewritten, NOT stripped)', (tester) async {
    final fake = _FakeMutate();
    final controller = _FakeVaultSessionController(
      initial: VaultStatus.unlocked, // unlocked at stage-time
      biometricSucceeds: true,
    );
    await _pump(tester, fake, controller);

    await _stageSensitiveImage(tester);

    final body = find.widgetWithText(TextField, 'Start writing…');
    final stagedText = tester.widget<TextField>(body).controller!.text;
    expect(stagedText, contains('hmm-attachment://pending/'));

    // Session relocks (inactivity timeout / app backgrounded) before save.
    controller.lockNow();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // The unlock flow ran (biometric) and succeeded.
    expect(controller.biometricAttempts, 1);
    // The sensitive pick was persisted — never stripped.
    expect(fake.persistCalls, 1);
    expect(fake.lastSensitive, isTrue);
    expect(fake.lastBody, isNot(contains('pending/')));
    expect(fake.lastBody, contains('attachments/note-1/sensitive/a.jpg'));
  });

  testWidgets(
      'save falls back to the passphrase dialog when biometric fails, and '
      'persists on a correct passphrase', (tester) async {
    final fake = _FakeMutate();
    final controller = _FakeVaultSessionController(
      initial: VaultStatus.unlocked,
      biometricSucceeds: true,
      passphraseSucceeds: true,
    );
    await _pump(tester, fake, controller);

    await _stageSensitiveImage(tester);

    controller
      ..lockNow()
      ..biometricSucceeds = false;

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Unlock Secure Vault'), findsOneWidget);
    // Scope to the dialog: the editor's own Title/body TextFields are also
    // in the tree underneath the modal.
    await tester.enterText(
      find.descendant(
          of: find.byType(AlertDialog), matching: find.byType(TextField)),
      'hunter2',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
    await tester.pumpAndSettle();

    expect(controller.biometricAttempts, 1);
    expect(controller.passphraseAttempts, 1);
    expect(fake.persistCalls, 1);
    expect(fake.lastSensitive, isTrue);
    expect(fake.lastBody, isNot(contains('pending/')));
  });

  testWidgets(
      'save aborts when the unlock is cancelled — staged pick is retained, '
      'never stripped, and persistInlineImage is never called', (tester) async {
    final fake = _FakeMutate();
    final controller = _FakeVaultSessionController(
      initial: VaultStatus.unlocked,
      biometricSucceeds: true,
    );
    await _pump(tester, fake, controller);

    await _stageSensitiveImage(tester);

    // Relock, and this time biometric fails and the user cancels the
    // passphrase prompt (no further interaction with the dialog).
    controller
      ..lockNow()
      ..biometricSucceeds = false;

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // A passphrase dialog appeared; dismiss/cancel it.
    expect(find.text('Unlock Secure Vault'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // persist was NEVER called — persist() must never see a locked store.
    expect(fake.persistCalls, 0);
    // The whole save aborted: createGeneral/updateGeneral never ran either.
    expect(fake.lastBody, isNull);
    // The staged pick's placeholder survives untouched (not stripped).
    final body = find.widgetWithText(TextField, 'Start writing…');
    final text = tester.widget<TextField>(body).controller!.text;
    expect(text, contains('hmm-attachment://pending/'));
    // A message told the user why nothing was saved.
    expect(find.textContaining('Unlock Secure Vault'), findsWidgets);
  });

  testWidgets(
      'defense-in-depth: vault relocks mid-save (AFTER the guard passed) — '
      'the save aborts, the placeholder is NOT stripped, and the app does '
      'not crash', (tester) async {
    // The vault stays reported "unlocked" throughout (so the top-of-`_save()`
    // guard passes and persist() is actually reached) — this fake models the
    // TOCTOU itself: `persistInlineImage` (standing in for the real
    // `EncryptedVaultStore.putBytes`) throws VaultLockedException as if
    // auto-lock fired in the window between the guard and the persist call.
    final fake = _FakeMutate(throwLockedOnPersist: true);
    final controller = _FakeVaultSessionController(
      initial: VaultStatus.unlocked,
      biometricSucceeds: true,
    );
    await _pump(tester, fake, controller);

    await _stageSensitiveImage(tester);

    final body = find.widgetWithText(TextField, 'Start writing…');
    final stagedText = tester.widget<TextField>(body).controller!.text;
    expect(stagedText, contains('hmm-attachment://pending/'));

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // No crash: pumpAndSettle above would have surfaced an unhandled
    // exception via FlutterError. persist() was reached (the guard passed).
    expect(fake.persistCalls, 1);
    // The save aborted before it could rewrite/strip the placeholder.
    final text = tester.widget<TextField>(body).controller!.text;
    expect(text, contains('hmm-attachment://pending/'));
    expect(text, isNot(contains('sensitive/a.jpg')));
    // A message told the user why nothing was saved.
    expect(
      find.textContaining('Unlock Secure Vault to save the sensitive image'),
      findsOneWidget,
    );
  });
}
