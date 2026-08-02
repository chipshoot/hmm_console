import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../navigation/router.dart';
import '../sync_pill.dart';
import 'quick_panel_action.dart';

/// Ordered list of actions the Quick Access Panel renders: Home, the two
/// global "new" actions, then Sync. Append here to add a future button —
/// the panel maps over this list, so no layout change is required.
///
/// Only globally-addressable actions belong here. The automobile-record
/// screens (service records, insurance, scheduled services) add through
/// screen-local handlers scoped to the vehicle being viewed, so they have
/// no meaning without one and stay on their own screens.
final quickPanelActionsProvider = Provider<List<QuickPanelAction>>((ref) {
  return [
    QuickPanelAction.simple(
      label: 'Home',
      icon: Icons.home_outlined,
      // GoRouter instance .go() — runs from above the Router (the overlay
      // context has no GoRouter ancestor), same as the old HomeButton.
      onTap: (ref) => ref.read(AppRouter.config).go('/'),
    ),
    QuickPanelAction.simple(
      label: 'New Note',
      icon: Icons.note_add_outlined,
      // push, not go: the editor should return you where you came from.
      onTap: (ref) => ref.read(AppRouter.config).push('/notes/new'),
    ),
    QuickPanelAction.simple(
      label: 'New Gas Log',
      icon: Icons.local_gas_station_outlined,
      onTap: (ref) => ref.read(AppRouter.config).push('/gas-logs/new'),
    ),
    const QuickPanelAction.custom(
      label: 'Sync',
      builder: _buildSyncAction,
    ),
  ];
});

Widget _buildSyncAction(BuildContext context, WidgetRef ref) =>
    const SyncPill();
