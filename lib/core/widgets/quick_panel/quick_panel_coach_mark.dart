import 'package:flutter/material.dart';

/// One-time first-run hint pointing at the bottom-right Quick Access
/// hot-zone. Shown by HomeSyncOverlay when quickPanelHintShown is false
/// and the feature is enabled; dismissed via onDismiss (which persists the
/// flag). Built in-repo — no coach-mark package.
class QuickPanelCoachMark extends StatelessWidget {
  const QuickPanelCoachMark({required this.onDismiss, super.key});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDismiss, // tapping the scrim also dismisses
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.5),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 80),
              child: Align(
                alignment: Alignment.bottomRight,
                child: Material(
                  color: cs.inverseSurface,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: 220,
                          child: Text(
                            'Long-press this corner for Home & quick Sync.',
                            style: TextStyle(color: cs.onInverseSurface),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: onDismiss,
                          child: const Text('Got it'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
