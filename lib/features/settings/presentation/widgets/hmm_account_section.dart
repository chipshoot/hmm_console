import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/data_mode.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/hmm_sign_in_sheet.dart';
import '../../../auth/providers/current_user_provider.dart';
import '../../../auth/providers/hmm_session_expired_provider.dart';
import '../../../auth/usecases/signout_usecase.dart';

/// Switches the data mode. Hmm cloud (`cloudApi`) needs a Hmm session, so the
/// sign-in happens FIRST: switching first would rebuild the router and bounce
/// the user to the login screen. Returns false (mode unchanged) when the user
/// cancels. Every other target switches straight away.
Future<bool> switchDataMode(
  BuildContext context,
  WidgetRef ref,
  DataMode to,
) async {
  // Taken before any await: signing in can rebuild the router and dispose
  // the caller, after which its ref must not be used.
  final dataMode = ref.read(dataModeProvider.notifier);
  if (to == DataMode.cloudApi) {
    final l = AppLocalizations.of(context);
    final ok = await ensureHmmSignedIn(
      context,
      ref,
      feature: l.hmmFeatureCloud,
    );
    if (!ok) return false;
  }
  await dataMode.setMode(to);
  return true;
}

/// The Hmm account row in Settings, shown in every mode. Signing out only
/// clears the Hmm session; local data stays on the device.
class HmmAccountSection extends ConsumerWidget {
  const HmmAccountSection({super.key});

  /// Everything is read before the await: in cloudApi, signing out flips
  /// the login gate and the router disposes Settings before it returns.
  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final signOut = ref.read(signOutUseCaseProvider);
    final currentUser = ref.read(currentUserProvider.notifier);
    try {
      await signOut.signOut();
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.settingsHmmSignOutFailed)),
      );
      return;
    }
    currentUser.setUser(null);
    messenger.showSnackBar(SnackBar(content: Text(l.settingsHmmSignedOut)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider);
    final isApple = switch (Theme.of(context).platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };
    final signedIn = user != null;
    // The IdP ended the session: say so, rather than a plain "not signed in".
    final expired = signedIn ? null : ref.watch(hmmSessionExpiredProvider).value;
    final label = signedIn ? l.settingsHmmSignOut : l.hmmSignInAction;
    void onPressed() =>
        signedIn ? _signOut(context, ref) : context.push('/auth');

    return Column(
      key: const Key('hmm-account-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.settingsHmmAccount,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          signedIn
              ? l.settingsHmmSignedInAs(user.email ?? '')
              : expired == null
                  ? l.settingsHmmNotSignedIn
                  : expired.isEmpty
                      ? l.hmmSessionExpiredBody
                      : l.settingsHmmSessionExpired(expired),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: isApple
              ? CupertinoButton(
                  key: const Key('hmm-account-action'),
                  padding: EdgeInsets.zero,
                  onPressed: onPressed,
                  child: Text(label),
                )
              : OutlinedButton(
                  key: const Key('hmm-account-action'),
                  onPressed: onPressed,
                  child: Text(label),
                ),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 24),
      ],
    );
  }
}
