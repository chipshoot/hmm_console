// Settings rows for the sensitive-attachments Secure Vault (Phase 4b /
// Task B4). Purely presentational glue over VaultSessionController — every
// row here just watches vaultSessionProvider and calls its methods; the
// session/lock/timeout policy lives in vault_session.dart (Task B3).
//
// Caller is responsible for gating this section to filesystem-backed data
// tiers (`if (dataMode != DataMode.cloudApi) const SecureVaultSection()`),
// same as ReceiptExtractionSettingsSection is inserted bare and owns its own
// section header internally.
//
// Each dialog's content is its own StatefulWidget (not a StatefulBuilder +
// manually-disposed TextEditingController) — showDialog's returned Future
// resolves as soon as Navigator.pop() is called, before the route's closing
// animation finishes, so disposing a controller right after `await
// showDialog` races a still-mounted TextField and crashes
// ("TextEditingController used after being disposed"). Owning the
// controller in State.dispose() ties its lifetime to the widget's actual
// removal from the tree instead.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/vault/vault_session.dart';
import '../../../../core/widgets/gaps.dart';

const _forgotPassphraseWarning =
    'If you forget this passphrase, these files cannot be recovered.';
const _resetConfirmToken = 'RESET';

class SecureVaultSection extends ConsumerWidget {
  const SecureVaultSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(vaultSessionProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Secure Vault',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        GapWidgets.h8,
        ..._rowsFor(context, ref, status),
      ],
    );
  }

  List<Widget> _rowsFor(
    BuildContext context,
    WidgetRef ref,
    VaultStatus status,
  ) {
    switch (status) {
      case VaultStatus.absent:
        return [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock_outline),
            title: const Text('Set up Secure Vault'),
            subtitle: const Text(
              'Encrypt sensitive attachments (e.g. registration, VIN photos) '
              'with a passphrase',
            ),
            onTap: () => _showSetupDialog(context, ref),
          ),
        ];
      case VaultStatus.locked:
        return [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock_outline),
            title: const Text('Secure Vault — locked'),
            subtitle:
                const Text('Unlock to view or add sensitive attachments'),
            trailing: TextButton(
              onPressed: () => _unlock(context, ref),
              child: const Text('Unlock'),
            ),
          ),
          _resetRow(context, ref),
        ];
      case VaultStatus.unlocked:
        return [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock_open_outlined),
            title: const Text('Secure Vault — on'),
            subtitle: const Text(
              'Sensitive attachments are unlocked on this device',
            ),
            trailing: TextButton(
              onPressed: () =>
                  ref.read(vaultSessionProvider.notifier).lockNow(),
              child: const Text('Lock now'),
            ),
          ),
          _resetRow(context, ref),
        ];
      case VaultStatus.corrupt:
        return [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.warning_amber_outlined,
                color: Theme.of(context).colorScheme.error),
            title: const Text('Secure Vault — needs reset'),
            subtitle: const Text(
              'The vault configuration could not be read and must be reset',
            ),
          ),
          _resetRow(context, ref),
        ];
    }
  }

  Widget _resetRow(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.restart_alt),
      title: const Text('Reset Secure Vault'),
      subtitle: const Text('Forgot your passphrase? Reset erases the vault'),
      onTap: () => _showResetDialog(context, ref),
    );
  }

  Future<void> _unlock(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(vaultSessionProvider.notifier);
    final viaBiometric = await controller.unlockWithBiometric();
    if (viaBiometric) return;
    if (!context.mounted) return;
    await _showPassphraseUnlockDialog(context, ref);
  }

  Future<void> _showSetupDialog(BuildContext context, WidgetRef ref) async {
    final passphrase = await showDialog<String>(
      context: context,
      builder: (_) => const _SetupDialog(),
    );
    if (passphrase == null || passphrase.isEmpty) return;
    await ref.read(vaultSessionProvider.notifier).setup(passphrase);
  }

  Future<void> _showPassphraseUnlockDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final passphrase = await showDialog<String>(
      context: context,
      builder: (_) => const _UnlockDialog(),
    );
    if (passphrase == null || passphrase.isEmpty) return;
    final controller = ref.read(vaultSessionProvider.notifier);
    final ok = await controller.unlockWithPassphrase(passphrase);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect passphrase.')),
      );
    }
  }

  Future<void> _showResetDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ResetDialog(),
    );
    if (confirmed != true) return;
    await ref.read(vaultSessionProvider.notifier).reset();
  }
}

class _SetupDialog extends StatefulWidget {
  const _SetupDialog();

  @override
  State<_SetupDialog> createState() => _SetupDialogState();
}

class _SetupDialogState extends State<_SetupDialog> {
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches =
        _passCtrl.text.isNotEmpty && _passCtrl.text == _confirmCtrl.text;
    final mismatch =
        _confirmCtrl.text.isNotEmpty && _passCtrl.text != _confirmCtrl.text;
    final errorStyle = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.error);

    return AlertDialog(
      title: const Text('Set up Secure Vault'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _passCtrl,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Passphrase'),
            onChanged: (_) => setState(() {}),
          ),
          GapWidgets.h8,
          TextField(
            controller: _confirmCtrl,
            obscureText: true,
            decoration:
                const InputDecoration(labelText: 'Confirm passphrase'),
            onChanged: (_) => setState(() {}),
          ),
          GapWidgets.h16,
          Text(_forgotPassphraseWarning, style: errorStyle),
          if (mismatch) ...[
            GapWidgets.h8,
            Text('Passphrases do not match.', style: errorStyle),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              matches ? () => Navigator.of(context).pop(_passCtrl.text) : null,
          child: const Text('Set Up'),
        ),
      ],
    );
  }
}

class _UnlockDialog extends StatefulWidget {
  const _UnlockDialog();

  @override
  State<_UnlockDialog> createState() => _UnlockDialogState();
}

class _UnlockDialogState extends State<_UnlockDialog> {
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

class _ResetDialog extends StatefulWidget {
  const _ResetDialog();

  @override
  State<_ResetDialog> createState() => _ResetDialogState();
}

class _ResetDialogState extends State<_ResetDialog> {
  final _tokenCtrl = TextEditingController();

  @override
  void dispose() {
    _tokenCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset Secure Vault'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This permanently deletes every file in the Secure Vault. '
            "This can't be undone. Type $_resetConfirmToken to confirm.",
          ),
          GapWidgets.h16,
          TextField(
            controller: _tokenCtrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Type RESET'),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _tokenCtrl.text == _resetConfirmToken
              ? () => Navigator.of(context).pop(true)
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Reset Secure Vault'),
        ),
      ],
    );
  }
}
