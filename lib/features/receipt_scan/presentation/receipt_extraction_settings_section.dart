import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings_controller.dart';
import '../domain/receipt_draft.dart';
import '../providers/receipt_extractor_providers.dart';

/// Settings control for the receipt-extraction preference. Selecting Cloud AI
/// the first time shows a one-time consent sheet (the receipt is uploaded to
/// the backend); on-device keeps everything on-device.
class ReceiptExtractionSettingsSection extends ConsumerWidget {
  const ReceiptExtractionSettingsSection({super.key});

  Future<void> _select(
    BuildContext context,
    WidgetRef ref,
    ReceiptExtractorMode mode,
  ) async {
    final l = AppLocalizations.of(context);
    if (mode == ReceiptExtractorMode.cloudAi) {
      final consented =
          (await ref.read(settingsProvider.future)).receiptCloudConsent;
      if (!consented) {
        if (!context.mounted) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l.receiptCloudAiTitle),
            content: Text(l.receiptCloudAiBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l.receiptEnableCloudAi),
              ),
            ],
          ),
        );
        if (ok != true) return;
        await ref.read(settingsProvider.notifier).setReceiptCloudConsent(true);
      }
    }
    await ref.read(receiptExtractorModeProvider.notifier).setMode(mode);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final mode = ref.watch(receiptExtractorModeProvider);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Receipt extraction',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        RadioGroup<ReceiptExtractorMode>(
          groupValue: mode,
          onChanged: (v) {
            if (v != null) _select(context, ref, v);
          },
          child: Column(
            children: [
              RadioListTile<ReceiptExtractorMode>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: ReceiptExtractorMode.onDevice,
                title: Text(l.receiptOnDevice),
                subtitle: Text(l.receiptOnDeviceSubtitle),
              ),
              RadioListTile<ReceiptExtractorMode>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: ReceiptExtractorMode.cloudAi,
                title: Text(l.receiptCloudAi),
                subtitle: Text(l.receiptCloudAiSubtitle),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
