import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/attachments/attachment_providers.dart';
import '../../../../core/data/attachments/attachment_ref.dart';
import '../../../../core/data/attachments/widgets/attachment_image.dart';
import '../../../../core/data/vault/vault_session.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/driver_licence.dart';
import '../widgets/vault_locked_notice.dart';

/// Full-screen licence, for showing to someone who asked to see it.
///
/// Deliberately NOT doing brightness or wakelock control: both need new
/// platform plugins (`screen_brightness`, `wakelock_plus`). Adding one here
/// would be a scope change, not an implementation detail.
class LicenceShowScreen extends ConsumerStatefulWidget {
  const LicenceShowScreen({
    super.key,
    required this.licence,
    this.showBackFirst = false,
  });

  final DriverLicence licence;

  /// Opening from the BACK slot should land on the back — otherwise tapping a
  /// specific side shows the other one, which reads as a bug.
  final bool showBackFirst;

  @override
  ConsumerState<LicenceShowScreen> createState() => _LicenceShowScreenState();
}

class _LicenceShowScreenState extends ConsumerState<LicenceShowScreen> {
  /// Opens on the front by default — that is the side with the photo and the
  /// number, and the side anyone asking will expect first.
  late bool _showingFront = !widget.showBackFirst;

  /// The sides actually available. A licence photographed on one side only is
  /// still worth showing, so the flip is offered only when there are two.
  @override
  void initState() {
    super.initState();
    // Resolve the real vault state; without this the screen shows the locked
    // notice over an image it could decrypt.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(vaultSessionProvider.notifier).refresh();
    });
  }

  bool get _canFlip =>
      widget.licence.frontImage != null && widget.licence.backImage != null;

  VaultRef? get _current {
    final l = widget.licence;
    if (_showingFront) return l.frontImage ?? l.backImage;
    return l.backImage ?? l.frontImage;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final l = widget.licence;
    final resolver = ref.watch(attachmentResolverProvider).value;
    final current = _current;
    // Both sides are sensitive, so a locked vault means the bytes cannot be
    // decrypted at all. Saying so beats a black rectangle on black.
    final vault = ref.watch(vaultSessionProvider);
    final locked = vault != VaultStatus.unlocked;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(loc.licenceTitle),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              // "No photo" and "photo not loaded yet" are different states.
              // Collapsing them would tell someone holding out their phone
              // that they have no licence saved, when they do and it is
              // simply still decrypting.
              child: current == null
                  ? Center(
                      child: Text(
                        loc.licenceNoImages,
                        key: const Key('licenceNoImagesLabel'),
                        style: const TextStyle(color: Colors.white70),
                      ),
                    )
                  : locked
                      ? Center(
                          child: VaultLockedNotice(
                              status: vault, onDark: true))
                      : GestureDetector(
                          key: const Key('licenceImageArea'),
                          behavior: HitTestBehavior.opaque,
                          onTap: _canFlip
                              ? () =>
                                  setState(() => _showingFront = !_showingFront)
                              : null,
                          child: resolver == null
                              ? const Center(
                                  key: Key('licenceImageLoading'),
                                  child: CircularProgressIndicator.adaptive())
                              : AttachmentImage(
                                  key: ValueKey(current.path),
                                  ref: current,
                                  resolver: resolver,
                                  loadingPlaceholder: const Center(
                                      child:
                                          CircularProgressIndicator.adaptive()),
                                  // Was black-on-black: a failed decrypt drew
                                  // an invisible rectangle, so "cannot show
                                  // it" and "there is nothing here" looked
                                  // identical.
                                  errorPlaceholder: const Center(
                                    key: Key('licenceImageFailed'),
                                    child: Icon(Icons.broken_image_outlined,
                                        color: Colors.white54, size: 48),
                                  ),
                                ),
                        ),
            ),
            // The number and expiry in text as well as on the photo: someone
            // checking often wants to read or copy the number rather than
            // squint at a picture of it.
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_canFlip)
                    Text(
                      _showingFront ? loc.licenceFront : loc.licenceBack,
                      key: const Key('licenceSideLabel'),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  if ((l.number ?? '').isNotEmpty)
                    Text(
                      l.number!,
                      key: const Key('licenceNumberText'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                  if (l.expiryDate != null)
                    Text(
                      '${loc.licenceExpires}: '
                      '${l.expiryDate!.year}-'
                      '${l.expiryDate!.month.toString().padLeft(2, '0')}-'
                      '${l.expiryDate!.day.toString().padLeft(2, '0')}',
                      key: const Key('licenceExpiryText'),
                      style: const TextStyle(color: Colors.white70),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
