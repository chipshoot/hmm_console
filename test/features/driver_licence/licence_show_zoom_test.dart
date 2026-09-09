// Reported: show mode displayed only the middle of the card, with no way to
// scroll or zoom. AttachmentImage defaults to BoxFit.cover, which crops.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/resolver/attachment_resolver.dart';
import 'package:hmm_console/core/data/attachments/widgets/attachment_image.dart';
import 'package:hmm_console/core/data/vault/vault_session.dart';
import 'package:hmm_console/features/driver_licence/domain/driver_licence.dart';
import 'package:hmm_console/features/driver_licence/presentation/screens/licence_show_screen.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

const _front = VaultRef(
  path: 'attachments/note-1/sensitive/front.jpg',
  contentType: 'image/jpeg',
  byteSize: 100,
  sensitive: true,
);

class _NullResolver implements IAttachmentResolver {
  @override
  Future<Uint8List?> resolve(AttachmentRef ref) async => null;
}

class _UnlockedVault extends VaultSessionController {
  @override
  VaultStatus build() => VaultStatus.unlocked;
  @override
  Future<void> refresh() async => state = VaultStatus.unlocked;
}

void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        attachmentResolverProvider.overrideWith((_) async => _NullResolver()),
        vaultSessionProvider.overrideWith(_UnlockedVault.new),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LicenceShowScreen(
          licence: DriverLicence(number: 'D1', frontImage: _front),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('the whole card is visible, not a cropped middle', (tester) async {
    await pump(tester);

    final image =
        tester.widget<AttachmentImage>(find.byType(AttachmentImage));
    expect(image.fit, BoxFit.contain,
        reason: 'cover crops a landscape card inside a portrait screen');
  });

  testWidgets('the image can be zoomed and panned', (tester) async {
    await pump(tester);

    expect(find.byType(InteractiveViewer), findsOneWidget,
        reason: 'someone holding out an ID needs to enlarge the small print');
  });
}
