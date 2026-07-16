import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'quick_panel_action.dart';
import 'quick_panel_actions_provider.dart';

/// Half-transparent rounded panel that renders the
/// quickPanelActionsProvider registry as a vertical stack of tiles.
/// Revealed by the HomeSyncOverlay long-press hot-zone (Task 4). Simple
/// actions render as icon+label tiles that run their onTap then call
/// onDismiss; custom actions embed their builder widget as-is.
class QuickAccessPanel extends ConsumerWidget {
  const QuickAccessPanel({required this.onDismiss, super.key});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final actions = ref.watch(quickPanelActionsProvider);
    return Material(
      color: cs.surface.withValues(alpha: 0.75), // half-transparent
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final action in actions)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: action.isCustom
                    ? action.builder!(context, ref)
                    : _SimpleTile(
                        action: action,
                        onTap: () {
                          action.onTap!(ref);
                          onDismiss();
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SimpleTile extends StatelessWidget {
  const _SimpleTile({required this.action, required this.onTap});

  final QuickPanelAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(action.icon, size: 18, color: cs.onSurface),
            const SizedBox(width: 10),
            Text(action.label,
                style: TextStyle(fontSize: 13, color: cs.onSurface)),
          ],
        ),
      ),
    );
  }
}
