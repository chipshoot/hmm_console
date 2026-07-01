import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/receipt_draft.dart';
import '../providers/receipt_extractor_providers.dart';

/// SharedPreferences flag: has the user consented to uploading receipts for
/// Cloud AI extraction? The consent sheet fires only until this is set.
const _consentKey = 'receipt_cloud_consent';

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
    if (mode == ReceiptExtractorMode.cloudAi) {
      final prefs = await SharedPreferences.getInstance();
      final consented = prefs.getBool(_consentKey) ?? false;
      if (!consented) {
        if (!context.mounted) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Use Cloud AI for receipts?'),
            content: const Text(
              'Your receipt photo or PDF will be uploaded to the Hmm server, '
              'which uses AI to read it and fill in the fields. On-device '
              "extraction keeps everything on your phone but can't read PDFs "
              "and won't itemize as accurately.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Enable Cloud AI'),
              ),
            ],
          ),
        );
        if (ok != true) return;
        await prefs.setBool(_consentKey, true);
      }
    }
    await ref.read(receiptExtractorModeProvider.notifier).setMode(mode);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          child: const Column(
            children: [
              RadioListTile<ReceiptExtractorMode>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: ReceiptExtractorMode.onDevice,
                title: Text('On-device (private)'),
                subtitle: Text(
                  "Reads photos on your phone. Nothing is uploaded. Can't read "
                  'PDFs.',
                ),
              ),
              RadioListTile<ReceiptExtractorMode>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: ReceiptExtractorMode.cloudAi,
                title: Text('Cloud AI (more accurate)'),
                subtitle: Text(
                  'Uploads the receipt for AI extraction. Reads PDFs and '
                  'itemizes.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
