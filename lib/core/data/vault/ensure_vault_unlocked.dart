import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/gen/app_localizations.dart';
import 'vault_session.dart';

/// Brings the vault to [VaultStatus.unlocked], asking the user if needed.
///
/// **`refresh()` first, always.** `VaultSessionController.build()` cannot
/// await, so it starts at `locked` as a safe default and stays there until a
/// caller resolves the real state. Reading the status without refreshing
/// reports "locked" no matter what the vault is actually doing — which is
/// exactly the bug this was written for: the licence screen refused to capture
/// a photo right after the vault had been unlocked in Settings.
///
/// Returns false when the vault cannot be opened, having already told the user
/// why. Callers should do nothing further.
Future<bool> ensureVaultUnlocked(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  await ref.read(vaultSessionProvider.notifier).refresh();
  final status = ref.read(vaultSessionProvider);
  if (status == VaultStatus.unlocked) return true;

  if (status == VaultStatus.absent || status == VaultStatus.corrupt) {
    // Nothing to unlock: prompting for a passphrase would dead-end.
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.vaultSetUpSubtitle)),
      );
    }
    return false;
  }

  final ctrl = ref.read(vaultSessionProvider.notifier);
  if (await ctrl.unlockWithBiometric()) return true;
  if (!context.mounted) return false;

  final passphrase = await showDialog<String>(
    context: context,
    builder: (_) => const _VaultUnlockDialog(),
  );
  if (passphrase == null || passphrase.isEmpty) return false;

  final ok = await ctrl.unlockWithPassphrase(passphrase);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.vaultIncorrectPassphrase)),
    );
  }
  return ok;
}

class _VaultUnlockDialog extends StatefulWidget {
  const _VaultUnlockDialog();

  @override
  State<_VaultUnlockDialog> createState() => _VaultUnlockDialogState();
}

class _VaultUnlockDialogState extends State<_VaultUnlockDialog> {
  final _passCtrl = TextEditingController();

  @override
  void dispose() {
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.vaultUnlockDialogTitle),
      content: TextField(
        key: const Key('vaultPassphraseField'),
        controller: _passCtrl,
        obscureText: true,
        autofocus: true,
        decoration: InputDecoration(labelText: l.vaultPassphrase),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          key: const Key('vaultUnlockConfirm'),
          onPressed: () => Navigator.of(context).pop(_passCtrl.text),
          child: Text(l.vaultUnlock),
        ),
      ],
    );
  }
}
