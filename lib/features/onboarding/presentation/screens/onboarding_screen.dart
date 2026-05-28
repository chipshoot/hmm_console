import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/data_mode.dart';
import '../../../../core/data/sync/onedrive_auth.dart';
import '../../../../core/data/sync/sync_controller.dart';
import '../../providers/onboarding_provider.dart';

/// Single-screen post-sign-in onboarding (Phase E):
///
///   ○ New to Hmm — start fresh on this device (local storage)
///   ○ I already use Hmm on another device — restore from OneDrive
///
/// On either branch we call `markCompleted()` once the user commits.
/// The router redirect picks that up and re-routes them to /. The
/// migration branch additionally:
///   1. Flips DataMode → cloudStorage
///   2. Triggers the OneDrive OAuth flow
///   3. Fires a manual Sync Now so Phase A pulls down all data + Phase
///      D.2 pulls down settings before the user lands on the dashboard.
///
/// On failure during the migration branch we leave the user on this
/// screen with a retry + a "Skip for now" escape so they're never
/// stranded (they can also configure cloud sync from Settings later).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Choice { newUser, migrating }

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  _Choice? _choice;
  bool _busy = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Get started',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Pick the option that matches your situation. You can '
                'change this any time in Settings.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              // Two-radio group via the modern RadioGroup ancestor —
              // same pattern as the WiFi-only toggle in Settings.
              RadioGroup<_Choice>(
                groupValue: _choice,
                // RadioGroup requires a non-null onChanged. We can't
                // skip it during sync, so we no-op the change while
                // _busy and let the Continue button's disabled state
                // tell the user the form is locked.
                onChanged: (v) {
                  if (_busy) return;
                  setState(() => _choice = v);
                },
                child: Column(
                  children: const [
                    _ChoiceTile(
                      value: _Choice.newUser,
                      title: 'New to Hmm',
                      subtitle: 'Start fresh on this device. Your data stays '
                          'local until you turn on cloud sync in Settings.',
                    ),
                    SizedBox(height: 8),
                    _ChoiceTile(
                      value: _Choice.migrating,
                      title: 'I already use Hmm on another device',
                      subtitle: "Sign in to OneDrive and pull your existing "
                          "data + settings down to this device.",
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton(
                onPressed: (_choice == null || _busy) ? null : _onContinue,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Continue'),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                // Escape hatch — if migration keeps failing for reasons
                // outside our control (e.g., Microsoft outage), let the
                // user finish onboarding anyway. They can wire up cloud
                // sync from Settings whenever.
                TextButton(
                  onPressed: _busy ? null : _skipAndFinish,
                  child: const Text('Skip for now'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onContinue() async {
    setState(() => _errorMessage = null);
    switch (_choice!) {
      case _Choice.newUser:
        await _finishAsNewUser();
        break;
      case _Choice.migrating:
        await _finishAsMigrating();
        break;
    }
  }

  Future<void> _finishAsNewUser() async {
    // No cloud setup; just flag onboarding done and bounce home. The
    // app stays on DataMode.local (the default).
    await ref.read(onboardingCompletedProvider.notifier).markCompleted();
    if (!mounted) return;
    context.go('/');
  }

  Future<void> _finishAsMigrating() async {
    setState(() => _busy = true);
    try {
      // 1) Flip the tier first so the orchestrator's provider rebuilds
      //    with the OneDrive sync provider before we hit Sync Now.
      await ref.read(dataModeProvider.notifier).setMode(DataMode.cloudStorage);

      // 2) Sign in to OneDrive. This is the same flow Settings →
      //    "Sign in to OneDrive" uses, so failures surface identically.
      await ref.read(oneDriveAuthProvider).signIn();
      // Invalidate the auth-state provider so the Settings screen
      // shows "Signed in" if the user navigates there later.
      ref.invalidate(oneDriveAuthStateProvider);

      // 3) Pull everything. SyncController.triggerManualSync bypasses
      //    the throttle but still respects in-flight. Phase A migration
      //    runs as part of syncNow() if a legacy marker is missing.
      final result =
          await ref.read(syncControllerProvider).triggerManualSync();
      if (result == null) {
        // Already in flight — shouldn't normally happen during
        // onboarding, but if it does, treat as success.
      } else if (!result.success) {
        throw Exception(
          result.errors.isEmpty
              ? 'Sync failed for an unknown reason.'
              : result.errors.first.message,
        );
      }

      // 4) Done — mark onboarding complete and go home.
      await ref.read(onboardingCompletedProvider.notifier).markCompleted();
      if (!mounted) return;
      context.go('/');
    } on OneDriveAuthException catch (e) {
      // Most likely path: user cancelled the OneDrive sheet, or the
      // browser session timed out. Stay on the screen with the
      // message so they can retry.
      setState(() {
        _busy = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _errorMessage = 'Could not restore from cloud: $e';
      });
    }
  }

  /// Last-resort "I'll deal with cloud later" exit. Marks onboarding
  /// complete + goes home WITHOUT changing DataMode (we already set it
  /// to cloudStorage above, but the user might want to be back on
  /// local if cloud setup failed). To be safe, flip it back.
  Future<void> _skipAndFinish() async {
    await ref.read(dataModeProvider.notifier).setMode(DataMode.local);
    await ref.read(onboardingCompletedProvider.notifier).markCompleted();
    if (!mounted) return;
    context.go('/');
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.value,
    required this.title,
    required this.subtitle,
  });

  final _Choice value;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: RadioListTile<_Choice>(
        value: value,
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle, style: theme.textTheme.bodySmall),
        ),
      ),
    );
  }
}
