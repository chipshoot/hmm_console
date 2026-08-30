import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/vault/ensure_vault_unlocked.dart';
import '../../../../core/data/vault/vault_session.dart';
import '../../../../l10n/gen/app_localizations.dart';

/// Explains why a licence photo is not on screen, and offers the way out.
///
/// Both sides are stored `sensitive: true`, so they live in the encrypted
/// vault: with the vault locked or never set up, the bytes CANNOT be decrypted
/// and the image genuinely cannot render. Before this existed the screens drew
/// a black rectangle on a black background — indistinguishable from having no
/// photo at all, and with nothing to act on.
class VaultLockedNotice extends ConsumerWidget {
  const VaultLockedNotice({
    super.key,
    required this.status,
    this.onDark = false,
    this.compact = false,
  });

  final VaultStatus status;

  /// Show-mode sits on black; the editor sits on the normal surface.
  final bool onDark;

  /// Just a lock and one word, for the 120px image slots. The full notice
  /// overflows them — and two copies of the same explanation side by side is
  /// noise anyway, so the editor shows one above the row instead.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final fg = onDark ? Colors.white70 : cs.onSurfaceVariant;

    final (title, subtitle) = switch (status) {
      VaultStatus.absent => (l.vaultSetUpTitle, l.vaultSetUpSubtitle),
      VaultStatus.corrupt => (l.vaultNeedsResetTitle, l.vaultLockedSubtitle),
      _ => (l.vaultLockedTitle, l.vaultLockedSubtitle),
    };

    if (compact) {
      return Padding(
        key: const Key('licenceVaultLockedSlot'),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, color: fg, size: 20),
            const SizedBox(height: 4),
            Text(l.vaultUnlock,
                style: TextStyle(color: fg, fontSize: 11),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return Padding(
      key: const Key('licenceVaultLockedNotice'),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, color: fg),
          const SizedBox(height: 8),
          Text(title, textAlign: TextAlign.center, style: TextStyle(color: fg)),
          const SizedBox(height: 4),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: fg, fontSize: 12)),
          if (status == VaultStatus.locked) ...[
            const SizedBox(height: 12),
            FilledButton.tonal(
              key: const Key('licenceUnlockButton'),
              // The full flow: biometric, then passphrase. Biometric alone
              // left anyone without it stuck looking at a button that did
              // nothing.
              onPressed: () => ensureVaultUnlocked(context, ref),
              child: Text(l.vaultUnlock),
            ),
          ],
        ],
      ),
    );
  }
}
