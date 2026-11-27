import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/network/idp_token_service.dart';
import 'package:hmm_console/features/auth/providers/hmm_session_expired_provider.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

/// Home-screen notice that the Hmm session ended (the IdP refused the
/// refresh token). Local and cloud-storage modes only: the app keeps
/// working, this just invites the user to sign in again. In cloudApi the
/// login gate takes them to the login screen instead.
class HmmSessionExpiredBanner extends ConsumerWidget {
  const HmmSessionExpiredBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(dataModeProvider) == DataMode.cloudApi) {
      return const SizedBox.shrink();
    }
    final expired = ref.watch(hmmSessionExpiredProvider).value;
    if (expired == null) return const SizedBox.shrink();

    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isApple = switch (theme.platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };
    void signIn() => context.push('/auth');
    void dismiss() => ref.read(idpTokenServiceProvider).dismissExpiredSession();

    Widget action(String label, VoidCallback onPressed, {bool primary = false}) =>
        isApple
            ? CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                onPressed: onPressed,
                child: Text(
                  label,
                  style: primary
                      ? const TextStyle(fontWeight: FontWeight.w600)
                      : null,
                ),
              )
            : primary
                ? FilledButton.tonal(onPressed: onPressed, child: Text(label))
                : TextButton(onPressed: onPressed, child: Text(label));

    return Card(
      key: const Key('hmm-session-expired'),
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_clock_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l.hmmSessionExpiredTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(l.hmmSessionExpiredBody, style: theme.textTheme.bodyMedium),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                action(l.hmmSessionExpiredDismiss, dismiss),
                action(l.hmmSignInAction, signIn, primary: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
