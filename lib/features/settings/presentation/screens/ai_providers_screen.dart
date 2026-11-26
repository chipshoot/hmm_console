import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/help/help_button.dart';
import '../../../../core/help/help_registry.dart';
import '../../../../core/llm/engines/llm_engine.dart';
import '../../../../core/llm/engines/llm_engine_registry.dart';
import '../../../../core/llm/llm_key_store.dart';
import '../../../../core/navigation/route_names.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/gaps.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../widgets/ai_choice_picker.dart';

/// AI providers are only offered on iOS and Android.
bool get aiProvidersSupported =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.android;

/// The "AI providers" row in Settings, with the divider and gaps around it.
/// Draws nothing off iOS/Android.
class AiProvidersSettingsSection extends StatelessWidget {
  const AiProvidersSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    if (!aiProvidersSupported) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.smart_toy_outlined),
          title: Text(l.settingsAiProviders),
          subtitle: Text(l.settingsAiProvidersSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.pushNamed(RouterNames.aiProviders.name),
        ),
        GapWidgets.h8,
        const Divider(),
        GapWidgets.h24,
      ],
    );
  }
}

/// The purpose string the receipt scan routes under.
const kReceiptsPurpose = 'receipts';

/// Whether this device holds a key for the engine. Invalidated when the edit
/// screen closes.
final aiKeyPresentProvider = FutureProvider.autoDispose.family<bool, String>(
  (ref, id) => ref.read(llmKeyStoreProvider).hasKey(id),
);

/// Settings -> AI providers: the configured engines, add, and which one reads
/// receipts.
class AiProvidersScreen extends ConsumerWidget {
  const AiProvidersScreen({super.key});

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    String routeName, [
    Map<String, String> params = const {},
  ]) async {
    await context.pushNamed(routeName, pathParameters: params);
    ref.invalidate(aiKeyPresentProvider);
  }

  Future<void> _pickReceipts(
    BuildContext context,
    WidgetRef ref,
    LlmEngineSettings s,
  ) async {
    final l = AppLocalizations.of(context);
    final picked = await showAiChoice<String?>(context, [
      AiChoice(null, l.aiProvidersRouteDefault),
      for (final e in s.engines) AiChoice(e.id, e.label),
    ]);
    if (picked == null) return;
    await ref
        .read(llmEngineSettingsProvider.notifier)
        .setRoute(kReceiptsPurpose, picked.value);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(llmEngineSettingsProvider);
    final routed = s.routes[kReceiptsPurpose];
    final routedLabel = s.engines
        .where((e) => e.id == routed)
        .map((e) => e.label)
        .firstOrNull;
    return AppScaffold(
      title: l.aiProvidersTitle,
      actions: const [HelpButton(helpId: HelpId.aiProviders)],
      slivers: [
        SliverList.list(
          children: [
            if (s.engines.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l.aiProvidersEmpty),
              ),
            for (final e in s.engines)
              _EngineRow(
                engine: e,
                isDefault: e.id == s.defaultId,
                onTap: () => _open(
                  context,
                  ref,
                  RouterNames.aiProviderEdit.name,
                  {'id': e.id},
                ),
              ),
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(l.aiProvidersAdd),
              onTap: () => _open(context, ref, RouterNames.aiProviderNew.name),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(l.aiProvidersUseForReceipts),
              subtitle: Text(routedLabel ?? l.aiProvidersRouteDefault),
              trailing: const Icon(Icons.chevron_right),
              onTap: s.engines.isEmpty
                  ? null
                  : () => _pickReceipts(context, ref, s),
            ),
          ],
        ),
      ],
    );
  }
}

class _EngineRow extends ConsumerWidget {
  const _EngineRow({
    required this.engine,
    required this.isDefault,
    required this.onTap,
  });

  final LlmEngine engine;
  final bool isDefault;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final hasKey = ref.watch(aiKeyPresentProvider(engine.id)).value;
    final String? keyState = hasKey == null
        ? null
        : hasKey
        ? l.aiProvidersKeySaved
        : engine.requiresKey
        ? l.aiProvidersKeyNeeded
        : l.aiProvidersNoKeyNeeded;
    return ListTile(
      title: Text(engine.label),
      subtitle: keyState == null ? null : Text(keyState),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isDefault) ...[
            const Icon(Icons.star_outline, size: 16),
            const SizedBox(width: 4),
            Text(l.aiProvidersDefault),
          ],
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }
}
