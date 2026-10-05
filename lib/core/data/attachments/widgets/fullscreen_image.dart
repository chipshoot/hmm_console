import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../vault/vault_session.dart';
import '../attachment_ref.dart';
import '../attachment_providers.dart';
import 'attachment_image.dart';
import 'sensitive_attachment_image.dart';

/// Opens [ref] full-screen in a zoomable, tap-to-dismiss dialog. Shared by the
/// note editor, the note review screen, the vehicle screen and the cheatsheet
/// so they all view photos the same way.
///
/// A sensitive [VaultRef] renders through [SensitiveAttachmentImage] (the lock
/// gate) and the dialog closes itself as soon as the vault leaves `unlocked`,
/// so a decrypted photo is never left on screen after a lock.
void showFullscreenImage(BuildContext context, AttachmentRef ref) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => _FullscreenImage(attachment: ref),
  );
}

class _FullscreenImage extends ConsumerWidget {
  const _FullscreenImage({required this.attachment});

  final AttachmentRef attachment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = attachment;
    final sensitive = a is VaultRef && a.sensitive;
    if (sensitive) {
      ref.listen<VaultStatus>(vaultSessionProvider, (prev, next) {
        if (prev == VaultStatus.unlocked && next != VaultStatus.unlocked) {
          // Removes exactly this dialog, even if something sits above it.
          final route = ModalRoute.of(context);
          if (route != null && route.isActive) {
            Navigator.of(context).removeRoute(route);
          }
        }
      });
    }
    final resolverAsync = ref.watch(attachmentResolverProvider);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.transparent,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Center(
          child: resolverAsync.when(
            data: (resolver) => InteractiveViewer(
              child: sensitive
                  ? SensitiveAttachmentImage(ref: a, resolver: resolver)
                  : AttachmentImage(ref: a, resolver: resolver),
            ),
            loading: () => const CircularProgressIndicator(),
            error: (e, _) {
              // Type only: the message can carry a vault path.
              debugPrint('FullscreenImage: resolver failed (${e.runtimeType})');
              return Text(
                AppLocalizations.of(context).attachmentPhotoLoadFailed,
                style: const TextStyle(color: Colors.white),
              );
            },
          ),
        ),
      ),
    );
  }
}
