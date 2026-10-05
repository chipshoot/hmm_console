import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/resolver/attachment_resolver.dart';
import 'package:hmm_console/core/data/attachments/widgets/attachment_image.dart';
import 'package:hmm_console/core/data/attachments/widgets/fullscreen_image.dart';
import 'package:hmm_console/core/data/vault/vault_session.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

/// Resolver stub so the provider yields `data` (no path_provider in tests).
class _FakeResolver implements IAttachmentResolver {
  @override
  Future<Uint8List?> resolve(AttachmentRef ref) async => null;
}

/// Vault session the test drives directly: no biometric channel, no I/O.
class _StubVault extends VaultSessionController {
  _StubVault(this._initial);
  final VaultStatus _initial;

  @override
  VaultStatus build() => _initial;

  @override
  Future<void> refresh() async {}

  void set(VaultStatus s) => state = s;
}

const _sensitive = VaultRef(
  path: 'attachments/note-1/sensitive/a.jpg',
  contentType: 'image/jpeg',
  byteSize: 10,
  sensitive: true,
);

const _plain = VaultRef(
  path: 'attachments/note-1/a.jpg',
  contentType: 'image/jpeg',
  byteSize: 10,
);

Future<_StubVault> _open(
  WidgetTester t,
  AttachmentRef ref, {
  VaultStatus status = VaultStatus.unlocked,
  Object? resolverError,
}) async {
  final vault = _StubVault(status);
  await t.pumpWidget(ProviderScope(
    overrides: [
      attachmentResolverProvider.overrideWith((ref) async {
        if (resolverError != null) throw resolverError;
        return _FakeResolver();
      }),
      vaultSessionProvider.overrideWith(() => vault),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showFullscreenImage(ctx, ref),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  // Build the session up front so the test can drive it even when the
  // dialog (non-sensitive) never reads it.
  ProviderScope.containerOf(t.element(find.text('open')))
      .read(vaultSessionProvider);
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
  return vault;
}

void main() {
  testWidgets('opens a zoomable dialog with the image', (t) async {
    const ref = VaultRef(
        path: 'attachments/note-1/a.jpg', contentType: 'image/jpeg', byteSize: 10);
    await t.pumpWidget(ProviderScope(
      overrides: [
        attachmentResolverProvider.overrideWith((ref) async => _FakeResolver()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showFullscreenImage(ctx, ref),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle(); // open the dialog + resolve the resolver future
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(AttachmentImage), findsOneWidget);
  });

  testWidgets('a sensitive photo closes when the vault locks', (t) async {
    final vault = await _open(t, _sensitive);
    expect(find.byType(InteractiveViewer), findsOneWidget);

    vault.set(VaultStatus.locked);
    await t.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('a sensitive photo opened while locked shows the lock gate', (
    t,
  ) async {
    await _open(t, _sensitive, status: VaultStatus.locked);
    expect(find.byKey(const Key('sensitiveLockedPlaceholder')), findsOneWidget);
    expect(find.byType(AttachmentImage), findsNothing);
  });

  testWidgets('a non-sensitive photo ignores a vault lock', (t) async {
    final vault = await _open(t, _plain);
    vault.set(VaultStatus.locked);
    await t.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(AttachmentImage), findsOneWidget);
  });

  testWidgets('a resolver failure shows a localized message, not the error', (
    t,
  ) async {
    await _open(t, _plain, resolverError: StateError('/secret/path.jpg'));
    expect(find.text('Could not load photo'), findsOneWidget);
    expect(find.textContaining('secret'), findsNothing);
  });
}
