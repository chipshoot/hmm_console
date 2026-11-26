import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../engines/llm_engine.dart';
import '../llm_client.dart';
import '../llm_key_store.dart';

/// Asks once per device before content goes to [engine]'s host. Accepting
/// stores the consent and returns true; cancelling returns false and stores
/// nothing. Cupertino action sheet on iOS, Material dialog elsewhere.
Future<bool> showLlmConsentSheet(BuildContext context, LlmEngine engine) async {
  final l = AppLocalizations.of(context);
  final keys = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(llmKeyStoreProvider);
  final host = engineHost(engine);
  final message = l.llmConsentMessage(engine.label, host);
  final ios = Theme.of(context).platform == TargetPlatform.iOS;
  final bool? ok;
  if (ios) {
    ok = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        message: Text(message),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.llmConsentContinue),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l.commonCancel),
        ),
      ),
    );
  } else {
    ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.llmConsentContinue),
          ),
        ],
      ),
    );
  }
  if (ok != true) return false;
  await keys.setConsent(engine.id, host);
  return true;
}
