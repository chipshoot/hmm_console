// Task B6 (Phase 4b): blurred/lock previews for sensitive images.
//
// Mirrors attachment_image_test.dart's approach — an in-process fake
// resolver so futures resolve deterministically under flutter_test, driven
// with explicit tester.pump() calls rather than pumpAndSettle (the default
// CircularProgressIndicator loading state animates indefinitely and would
// trip pumpAndSettle's iteration cap).

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/resolver/attachment_resolver.dart';
import 'package:hmm_console/core/data/attachments/widgets/attachment_image.dart';
import 'package:hmm_console/core/data/vault/encrypted_vault_store.dart'
    show VaultLockedException;
import 'package:hmm_console/core/data/vault/vault_session.dart';
import 'package:hmm_console/features/notes/presentation/widgets/sensitive_attachment_image.dart';

const _lockedPlaceholderKey = Key('sensitiveLockedPlaceholder');

class _FakeResolver implements IAttachmentResolver {
  _FakeResolver({this.bytes, this.throwLocked = false});
  final Uint8List? bytes;
  final bool throwLocked;
  int calls = 0;

  @override
  Future<Uint8List?> resolve(AttachmentRef ref) async {
    calls++;
    if (throwLocked) {
      throw const VaultLockedException('attachments/note-1/sensitive/x.png');
    }
    return bytes;
  }
}

/// Fixed-status fake session controller — no biometric platform channel,
/// no real vault I/O. Mirrors
/// test/features/notes/presentation/note_editor_sensitive_test.dart's
/// _FakeVaultSessionController precedent.
class _FakeVaultSessionController extends VaultSessionController {
  _FakeVaultSessionController(this._initial);
  final VaultStatus _initial;

  @override
  VaultStatus build() => _initial;
}

// 1x1 transparent PNG so Image.memory has something decodable to chew on.
final Uint8List _pngBytes = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

const _sensitiveRef = VaultRef(
  path: 'attachments/note-1/sensitive/x.png',
  contentType: 'image/png',
  byteSize: 1,
  sensitive: true,
);

const _plainRef = VaultRef(
  path: 'attachments/note-1/x.png',
  contentType: 'image/png',
  byteSize: 1,
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump();
  }
}

Widget _harness({
  required VaultStatus status,
  required IAttachmentResolver resolver,
  VaultRef ref = _sensitiveRef,
}) {
  return ProviderScope(
    overrides: [
      vaultSessionProvider
          .overrideWith(() => _FakeVaultSessionController(status)),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 100,
          height: 100,
          child: SensitiveAttachmentImage(ref: ref, resolver: resolver),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
      'locked vault shows the sensitiveLockedPlaceholder, not broken-image',
      (tester) async {
    final resolver = _FakeResolver(bytes: _pngBytes);
    await tester.pumpWidget(
        _harness(status: VaultStatus.locked, resolver: resolver));
    await _settle(tester);

    expect(find.byKey(_lockedPlaceholderKey), findsOneWidget);
    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
    expect(find.byType(Image), findsNothing);
    // Locked: the widget never even attempts to resolve the ciphertext.
    expect(resolver.calls, 0);
  });

  testWidgets('unlocked vault renders the image via AttachmentImage',
      (tester) async {
    final resolver = _FakeResolver(bytes: _pngBytes);
    await tester.pumpWidget(
        _harness(status: VaultStatus.unlocked, resolver: resolver));
    await _settle(tester);

    expect(find.byType(Image), findsOneWidget);
    expect(find.byKey(_lockedPlaceholderKey), findsNothing);
    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
  });

  testWidgets(
      'missing sensitive bytes while unlocked shows broken-image, '
      'distinct from the locked placeholder', (tester) async {
    final resolver = _FakeResolver();
    await tester.pumpWidget(
        _harness(status: VaultStatus.unlocked, resolver: resolver));
    await _settle(tester);

    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    expect(find.byKey(_lockedPlaceholderKey), findsNothing);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets(
      'a resolve that throws VaultLockedException while nominally unlocked '
      'still shows the locked placeholder, not broken-image', (tester) async {
    final resolver = _FakeResolver(throwLocked: true);
    await tester.pumpWidget(
        _harness(status: VaultStatus.unlocked, resolver: resolver));
    await _settle(tester);

    expect(find.byKey(_lockedPlaceholderKey), findsOneWidget);
    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
  });

  testWidgets(
      'non-sensitive ref path via plain AttachmentImage is unaffected by '
      'vault lock status (unchanged behavior)', (tester) async {
    // Mirrors the wiring: a non-sensitive VaultRef never goes through
    // SensitiveAttachmentImage — it always renders via plain AttachmentImage,
    // which doesn't watch vaultSessionProvider at all, so a locked vault
    // has zero effect on it.
    final resolver = _FakeResolver(bytes: _pngBytes);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        vaultSessionProvider
            .overrideWith(() => _FakeVaultSessionController(VaultStatus.locked)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 100,
            height: 100,
            child: AttachmentImage(ref: _plainRef, resolver: resolver),
          ),
        ),
      ),
    ));
    await _settle(tester);

    expect(find.byType(Image), findsOneWidget);
    expect(find.byKey(_lockedPlaceholderKey), findsNothing);
  });
}
