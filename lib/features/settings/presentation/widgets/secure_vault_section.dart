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
import '../../../../l10n/gen/app_localizations.dart';

/// The word the user must type to confirm a vault reset.
///
/// Deliberately NOT localized. It is a value the user types, not copy they
/// read: translating it would demand a Chinese IME to destroy a vault, and the
/// comparison at the bottom of this file is an exact string match. The ARB
/// strings that mention it take it as a placeholder, so each locale phrases the
/// sentence naturally while the token itself stays constant.
const _resetConfirmToken = 'RESET';

class SecureVaultSection extends ConsumerStatefulWidget {
  const SecureVaultSection({super.key});

  @override
  ConsumerState<SecureVaultSection> createState() =>
      _SecureVaultSectionState();
}

class _SecureVaultSectionState extends ConsumerState<SecureVaultSection> {
  @override
  void initState() {
    super.initState();
    // Blocker fix: VaultSessionController.build() cannot await, so it
    // starts out `locked` and only refresh() computes the real state (see
    // vault_session.dart). Settings is one of the two production entry
    // points that must show the real status (the other is the note
    // editor's _ensureVaultUnlocked) — without this, a fresh install with
    // no vault yet stays stuck on the `locked` row (Unlock/Reset) and the
    // `absent` "Set up Secure Vault" tile — the only setup entry point —
    // never renders. Fire-and-forget: refresh() sets provider state
    // directly, which rebuilds this widget via ref.watch below.
    Future.microtask(
      () => ref.read(vaultSessionProvider.notifier).refresh(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(vaultSessionProvider);
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.vaultSectionTitle,
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
    final l = AppLocalizations.of(context);
    switch (status) {
      case VaultStatus.absent:
        return [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock_outline),
            title: Text(l.vaultSetUpTitle),
            subtitle: Text(l.vaultSetUpSubtitle),
            onTap: () => _showSetupDialog(context, ref),
          ),
        ];
      case VaultStatus.locked:
        return [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock_outline),
            title: Text(l.vaultLockedTitle),
            subtitle: Text(l.vaultLockedSubtitle),
            trailing: TextButton(
              onPressed: () => _unlock(context, ref),
              child: Text(l.vaultUnlock),
            ),
          ),
          _resetRow(context, ref),
        ];
      case VaultStatus.unlocked:
        return [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock_open_outlined),
            title: Text(l.vaultOnTitle),
            subtitle: Text(l.vaultOnSubtitle),
            trailing: TextButton(
              onPressed: () =>
                  ref.read(vaultSessionProvider.notifier).lockNow(),
              child: Text(l.vaultLockNow),
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
            title: Text(l.vaultNeedsResetTitle),
            subtitle: Text(l.vaultNeedsResetSubtitle),
          ),
          _resetRow(context, ref),
        ];
    }
  }

  Widget _resetRow(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.restart_alt),
      title: Text(l.vaultResetTitle),
      subtitle: Text(l.vaultResetSubtitle),
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
        SnackBar(
          content: Text(AppLocalizations.of(context).vaultIncorrectPassphrase),
        ),
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
    final l = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l.vaultSetUpTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _passCtrl,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(labelText: l.vaultPassphrase),
            onChanged: (_) => setState(() {}),
          ),
          GapWidgets.h8,
          TextField(
            controller: _confirmCtrl,
            obscureText: true,
            decoration: InputDecoration(labelText: l.vaultConfirmPassphrase),
            onChanged: (_) => setState(() {}),
          ),
          GapWidgets.h16,
          Text(l.vaultForgotWarning, style: errorStyle),
          if (mismatch) ...[
            GapWidgets.h8,
            Text(l.vaultPassphrasesDoNotMatch, style: errorStyle),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed:
              matches ? () => Navigator.of(context).pop(_passCtrl.text) : null,
          child: Text(l.vaultSetUpAction),
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
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.vaultUnlockDialogTitle),
      content: TextField(
        controller: _passCtrl,
        obscureText: true,
        autofocus: true,
        decoration: InputDecoration(labelText: l.vaultPassphrase),
        onChanged: (_) => setState(() {}),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed: _passCtrl.text.isEmpty
              ? null
              : () => Navigator.of(context).pop(_passCtrl.text),
          child: Text(l.vaultUnlock),
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
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.vaultResetTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The token is passed in rather than baked into the sentence, so
          // every locale shows the same word the comparison below expects.
          Text(l.vaultResetWarning(_resetConfirmToken)),
          GapWidgets.h16,
          TextField(
            controller: _tokenCtrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l.vaultResetTypeToken(_resetConfirmToken),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed: _tokenCtrl.text == _resetConfirmToken
              ? () => Navigator.of(context).pop(true)
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(l.vaultResetTitle),
        ),
      ],
    );
  }
}
