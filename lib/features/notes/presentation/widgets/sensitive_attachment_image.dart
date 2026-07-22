// Blurred / lock preview for sensitive images (Task B6, Phase 4b).
//
// SensitiveAttachmentImage wraps AttachmentImage with a vault-aware gate:
// while the sensitive-attachments vault is locked (or a resolve races into
// VaultLockedException between the status check and the actual read), it
// shows a blurred lock placeholder instead of attempting to decrypt —
// tapping it runs the same unlock flow the editor uses (biometric first,
// falling back to a passphrase dialog; see
// note_editor_screen.dart#_ensureVaultUnlocked for the precedent this
// mirrors). Once unlocked it delegates straight to AttachmentImage, which
// decrypts transparently through EncryptedVaultStore — a resolver-null or
// VaultStoreException result there still renders the existing "missing"
// broken-image placeholder, distinct from the locked one.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/attachments/attachment_ref.dart';
import '../../../../core/data/attachments/resolver/attachment_resolver.dart';
import '../../../../core/data/attachments/widgets/attachment_image.dart';
import '../../../../core/data/vault/encrypted_vault_store.dart'
    show VaultLockedException;
import '../../../../core/data/vault/vault_session.dart';

/// Key on the locked placeholder's tap target — asserted by tests to
/// distinguish it from AttachmentImage's own "missing" broken-image
/// placeholder.
const Key sensitiveLockedPlaceholderKey = Key('sensitiveLockedPlaceholder');

class SensitiveAttachmentImage extends ConsumerWidget {
  const SensitiveAttachmentImage({
    required this.ref,
    required this.resolver,
    super.key,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.semanticLabel,
  });

  final VaultRef ref;
  final IAttachmentResolver resolver;
  final BoxFit fit;
  final Alignment alignment;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef wref) {
    final status = wref.watch(vaultSessionProvider);
    if (status != VaultStatus.unlocked) {
      return _LockedPlaceholder(onTap: () => _unlock(context, wref));
    }
    return _UnlockedGate(
      vaultRef: ref,
      resolver: resolver,
      fit: fit,
      alignment: alignment,
      semanticLabel: semanticLabel,
      onTapLocked: () => _unlock(context, wref),
    );
  }

  Future<void> _unlock(BuildContext context, WidgetRef wref) async {
    final status = wref.read(vaultSessionProvider);
    if (status == VaultStatus.absent || status == VaultStatus.corrupt) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Set up Secure Vault in Settings to view this image.'),
          ),
        );
      }
      return;
    }
    final ctrl = wref.read(vaultSessionProvider.notifier);
    if (await ctrl.unlockWithBiometric()) return;
    if (!context.mounted) return;
    final passphrase = await showDialog<String>(
      context: context,
      builder: (_) => const _SensitiveUnlockDialog(),
    );
    if (passphrase == null || passphrase.isEmpty) return;
    final ok = await ctrl.unlockWithPassphrase(passphrase);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect passphrase.')),
      );
    }
  }
}

/// Rendered once [vaultSessionProvider] reports unlocked. Probes the
/// resolver once up front purely to catch a [VaultLockedException] race
/// (the session read "unlocked" this frame but relocked — inactivity
/// timeout / app-backgrounded — before this resolve ran); any other
/// outcome (bytes, null, [VaultStoreException]) is left entirely to
/// AttachmentImage's own resolve+render below.
class _UnlockedGate extends StatefulWidget {
  const _UnlockedGate({
    required this.vaultRef,
    required this.resolver,
    required this.fit,
    required this.alignment,
    required this.semanticLabel,
    required this.onTapLocked,
  });

  final VaultRef vaultRef;
  final IAttachmentResolver resolver;
  final BoxFit fit;
  final Alignment alignment;
  final String? semanticLabel;
  final VoidCallback onTapLocked;

  @override
  State<_UnlockedGate> createState() => _UnlockedGateState();
}

class _UnlockedGateState extends State<_UnlockedGate> {
  late Future<bool> _lockedCheck;

  @override
  void initState() {
    super.initState();
    _lockedCheck = _checkLocked();
  }

  @override
  void didUpdateWidget(covariant _UnlockedGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vaultRef != widget.vaultRef ||
        oldWidget.resolver != widget.resolver) {
      _lockedCheck = _checkLocked();
    }
  }

  Future<bool> _checkLocked() async {
    try {
      await widget.resolver.resolve(widget.vaultRef);
      return false;
    } on VaultLockedException {
      return true;
    } catch (_) {
      // Any other failure (missing bytes, etc.) is not a "locked" signal —
      // fall through and let AttachmentImage's own resolve decide how to
      // render it (its default is the "missing" broken-image placeholder).
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _lockedCheck,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          );
        }
        if (snap.data == true) {
          return _LockedPlaceholder(onTap: widget.onTapLocked);
        }
        return AttachmentImage(
          ref: widget.vaultRef,
          resolver: widget.resolver,
          fit: widget.fit,
          alignment: widget.alignment,
          semanticLabel: widget.semanticLabel,
        );
      },
    );
  }
}

/// Blurred + lock-icon tap target shown while the vault is locked (or a
/// resolve races into [VaultLockedException]) — visually distinct from
/// AttachmentImage's plain broken-image "missing" placeholder.
class _LockedPlaceholder extends StatelessWidget {
  const _LockedPlaceholder({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      key: sensitiveLockedPlaceholderKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(color: scheme.surfaceContainerHighest),
          ),
          Center(
            child: Icon(
              Icons.lock_outline,
              size: 36,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Minimal passphrase-entry dialog for the tap-to-unlock affordance.
/// Deliberately local/private rather than reusing the B4
/// `SecureVaultSection` dialog or B5's editor-local `_EditorVaultUnlockDialog`
/// (both private to their own widgets) — a focused equivalent, not a shared
/// export, matching the precedent those two set.
class _SensitiveUnlockDialog extends StatefulWidget {
  const _SensitiveUnlockDialog();

  @override
  State<_SensitiveUnlockDialog> createState() =>
      _SensitiveUnlockDialogState();
}

class _SensitiveUnlockDialogState extends State<_SensitiveUnlockDialog> {
  final _passCtrl = TextEditingController();

  @override
  void dispose() {
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Unlock Secure Vault'),
      content: TextField(
        controller: _passCtrl,
        obscureText: true,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Passphrase'),
        onChanged: (_) => setState(() {}),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _passCtrl.text.isEmpty
              ? null
              : () => Navigator.of(context).pop(_passCtrl.text),
          child: const Text('Unlock'),
        ),
      ],
    );
  }
}
