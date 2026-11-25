import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/idp_token_service.dart';
import '../../../l10n/gen/app_localizations.dart';

/// Thrown by a provider that needs a Hmm session when none exists.
class HmmSignInRequired implements Exception {
  const HmmSignInRequired();

  @override
  String toString() => 'HmmSignInRequired';
}

/// Returns true when a Hmm session exists (no UI), or after the user signs in
/// through the sheet. Returns false when the user cancels or login fails.
Future<bool> ensureHmmSignedIn(
  BuildContext context,
  WidgetRef ref, {
  required String feature,
}) async {
  if (await ref.read(idpTokenServiceProvider).hasHmmSession()) return true;
  if (!context.mounted) return false;

  final l = AppLocalizations.of(context);
  final isApple = switch (Theme.of(context).platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => true,
    _ => false,
  };
  final title = l.hmmSignInSheetTitle(feature);

  final wantsSignIn = isApple
      ? await showCupertinoModalPopup<bool>(
          // ignore: use_build_context_synchronously
          context: context,
          builder: (ctx) => CupertinoActionSheet(
            title: Text(title),
            message: Text(l.hmmSignInSheetBody),
            actions: [
              CupertinoActionSheetAction(
                isDefaultAction: true,
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l.hmmSignInAction),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.commonCancel),
            ),
          ),
        )
      : await showModalBottomSheet<bool>(
          // ignore: use_build_context_synchronously
          context: context,
          builder: (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(l.hmmSignInSheetBody),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(l.hmmSignInAction),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(l.commonCancel),
                  ),
                ],
              ),
            ),
          ),
        );

  if (wantsSignIn != true || !context.mounted) return false;
  return await context.push<bool>('/auth') == true;
}
