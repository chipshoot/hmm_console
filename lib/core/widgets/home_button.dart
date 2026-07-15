import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigation/router.dart';

/// Small floating control that jumps to the Dashboard from anywhere in
/// the app. Lives inside the persistent Home+Sync overlay (mounted once,
/// above the router, in `main.dart` — see `HomeSyncOverlay`), never
/// per-screen.
///
/// Uses the `GoRouter` INSTANCE's `.go()` method directly (not the
/// `context.go(...)` extension) because this widget's `BuildContext` sits
/// above the Router in the tree (see Finding 5 in
/// `docs/superpowers/plans/2026-07-15-sync-safety-phase1.md`), so it has
/// no `GoRouter` ancestor to resolve via `GoRouter.of(context)`.
class HomeButton extends ConsumerWidget {
  const HomeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(
        icon: const Icon(Icons.home_outlined),
        tooltip: 'Home',
        onPressed: () => ref.read(AppRouter.config).go('/'),
      ),
    );
  }
}
