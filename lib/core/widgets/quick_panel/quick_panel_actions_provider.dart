import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../navigation/router.dart';
import '../sync_pill.dart';
import 'quick_panel_action.dart';

/// Ordered list of actions the Quick Access Panel renders. v1 = Home +
/// Sync. Append here to add a future button (e.g. New Note, Search) — the
/// panel maps over this list, so no layout change is required.
final quickPanelActionsProvider = Provider<List<QuickPanelAction>>((ref) {
  return [
    QuickPanelAction.simple(
      label: 'Home',
      icon: Icons.home_outlined,
      // GoRouter instance .go() — runs from above the Router (the overlay
      // context has no GoRouter ancestor), same as the old HomeButton.
      onTap: (ref) => ref.read(AppRouter.config).go('/'),
    ),
    const QuickPanelAction.custom(
      label: 'Sync',
      builder: _buildSyncAction,
    ),
  ];
});

Widget _buildSyncAction(BuildContext context, WidgetRef ref) =>
    const SyncPill();
