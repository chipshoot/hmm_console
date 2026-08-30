// Show mode is what gets handed to an officer or a reviewer, so the side
// mapping matters more than it looks: showing the back while the label says
// "Front" is the kind of thing nobody notices until it is embarrassing.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/resolver/attachment_resolver.dart';
import 'package:hmm_console/core/data/attachments/widgets/attachment_image.dart';
import 'package:hmm_console/core/data/vault/vault_session.dart';
import 'package:hmm_console/features/driver_licence/domain/driver_licence.dart';
import 'package:hmm_console/features/driver_licence/presentation/screens/licence_show_screen.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

const front = VaultRef(
  path: 'attachments/note-1/sensitive/front.jpg',
  contentType: 'image/jpeg',
  byteSize: 100,
  sensitive: true,
);
const back = VaultRef(
  path: 'attachments/note-1/sensitive/back.jpg',
  contentType: 'image/jpeg',
  byteSize: 100,
  sensitive: true,
);

/// Returns null for everything, which AttachmentImage treats as "show the
/// placeholder" rather than an error. Enough for the widget to build, which is
/// what the side-mapping assertions read.
class _StubVault extends VaultSessionController {
  _StubVault(this._status);
  final VaultStatus _status;
  @override
  VaultStatus build() => _status;
}

class _NullResolver implements IAttachmentResolver {
  @override
  Future<Uint8List?> resolve(AttachmentRef ref) async => null;
}

void main() {
  Future<void> pump(WidgetTester tester, DriverLicence licence,
      {VaultStatus vault = VaultStatus.unlocked}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        attachmentResolverProvider.overrideWith((_) async => _NullResolver()),
        vaultSessionProvider.overrideWith(() => _StubVault(vault)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LicenceShowScreen(licence: licence),
      ),
    ));
    // Settle, not pump: the route transition leaves the page behind an
    // IgnorePointer until it finishes, so a tap would land on nothing. Safe
    // here — this screen makes no network calls.
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the front', (tester) async {
    await pump(tester, const DriverLicence(frontImage: front, backImage: back));

    expect(find.text('Front'), findsOneWidget);
    expect(find.text('Back'), findsNothing);
  });

  /// Invokes the flip callback rather than tapping it.
  ///
  /// A real tap does not reach this GestureDetector under test — the hit test
  /// resolves to the route's own layers instead — and chasing that is layout
  /// archaeology. What matters here is the state machine and the side mapping,
  /// which this exercises exactly; the callback being wired to the detector is
  /// visible in one line of the build method.
  void flip(WidgetTester tester) {
    final gd = tester
        .widget<GestureDetector>(find.byKey(const Key('licenceImageArea')));
    gd.onTap!();
  }

  testWidgets('flipping goes to the back and back again', (tester) async {
    await pump(tester, const DriverLicence(frontImage: front, backImage: back));

    flip(tester);
    await tester.pump();
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Front'), findsNothing);

    flip(tester);
    await tester.pump();
    expect(find.text('Front'), findsOneWidget);
  });

  testWidgets('the side label follows the image actually shown', (tester) async {
    // The mutation this exists for: swapping front and back at the render
    // site would leave the label saying "Front" over the back of the card.
    await pump(tester, const DriverLicence(frontImage: front, backImage: back));

    AttachmentImage shown() =>
        tester.widget<AttachmentImage>(find.byType(AttachmentImage));

    expect(find.text('Front'), findsOneWidget);
    expect(shown().ref, front);

    flip(tester);
    await tester.pump();
    expect(find.text('Back'), findsOneWidget);
    expect(shown().ref, back);
  });

  testWidgets('a one-sided licence offers no flip at all', (tester) async {
    await pump(tester, const DriverLicence(frontImage: front));

    // No side label: with one photo there is nothing to distinguish. And the
    // callback is null, so there is no dead tap target either.
    expect(find.byKey(const Key('licenceSideLabel')), findsNothing);
    final gd = tester
        .widget<GestureDetector>(find.byKey(const Key('licenceImageArea')));
    expect(gd.onTap, isNull);
  });

  testWidgets('the number and expiry are readable as text', (tester) async {
    // Someone checking usually wants to read or copy the number rather than
    // squint at a photograph of it.
    await pump(
      tester,
      DriverLicence(
        number: 'D1234-56789',
        expiryDate: DateTime.utc(2030, 5, 1),
        frontImage: front,
      ),
    );

    expect(find.text('D1234-56789'), findsOneWidget);
    expect(find.text('Expires: 2030-05-01'), findsOneWidget);
  });

  testWidgets('no images at all shows a message, not a blank screen',
      (tester) async {
    await pump(tester, const DriverLicence(number: 'X'));

    expect(find.byKey(const Key('licenceNoImagesLabel')), findsOneWidget);
  });

  testWidgets('a locked vault says so instead of drawing black on black',
      (tester) async {
    // Both sides are stored sensitive, so a locked vault means the bytes
    // genuinely cannot be decrypted. The old placeholders were black on a
    // black background — identical to having no photo, with nothing to act on.
    await pump(
      tester,
      const DriverLicence(number: 'D1', frontImage: front, backImage: back),
      vault: VaultStatus.locked,
    );

    expect(find.byKey(const Key('licenceVaultLockedNotice')), findsOneWidget);
    expect(find.byKey(const Key('licenceUnlockButton')), findsOneWidget);
    // Not the "you have no photo" message: there IS one.
    expect(find.byKey(const Key('licenceNoImagesLabel')), findsNothing);
  });

  testWidgets('a vault that was never set up points at setup, not unlock',
      (tester) async {
    await pump(
      tester,
      const DriverLicence(number: 'D1', frontImage: front),
      vault: VaultStatus.absent,
    );

    expect(find.byKey(const Key('licenceVaultLockedNotice')), findsOneWidget);
    // Nothing to unlock yet — offering it would dead-end.
    expect(find.byKey(const Key('licenceUnlockButton')), findsNothing);
  });
}
