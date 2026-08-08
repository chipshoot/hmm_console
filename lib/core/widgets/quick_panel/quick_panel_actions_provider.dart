import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../navigation/router.dart';
import '../sync_pill.dart';
import 'quick_panel_action.dart';

/// The actions the Quick Access Panel shows on a given route.
///
/// Screen-aware by design: an action that can't do anything useful where you
/// are is noise, and "Home" while already home is worse than noise — it's a
/// control that appears to do nothing. So the panel carries the *create*
/// action for the list you're looking at, and drops Home at the root.
///
/// Pure, so the rules can be tested without a router or a widget tree.
///
/// Only globally-addressable creates belong here. The automobile-record
/// screens (service records, insurance, scheduled services) create through
/// handlers scoped to the vehicle being viewed, so they have no meaning
/// without one and keep their own on-screen buttons.
List<QuickPanelAction> quickPanelActionsFor(String path) {
  final isHome = path == '/';
  final inNotes = path == '/notes' || path.startsWith('/notes/');
  final inGasLogs = path == '/gas-logs' || path.startsWith('/gas-logs/');

  return [
    if (!isHome)
      QuickPanelAction.simple(
        label: 'Home',
        icon: Icons.home_outlined,
        // GoRouter instance .go() — runs from above the Router (the overlay
        // context has no GoRouter ancestor), same as the old HomeButton.
        onTap: (ref) => ref.read(AppRouter.config).go('/'),
      ),
    if (inNotes)
      QuickPanelAction.simple(
        label: 'New Note',
        icon: Icons.note_add_outlined,
        // push, not go: the editor should return you where you came from.
        onTap: (ref) => ref.read(AppRouter.config).push('/notes/new'),
      ),
    if (inGasLogs)
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
}

/// Panel contents for [path]. Keyed by route so moving between screens
/// rebuilds the list; the panel resolves the current path from the router,
/// which it can do without a GoRouter ancestor.
final quickPanelActionsProvider =
    Provider.family<List<QuickPanelAction>, String>(
  (ref, path) => quickPanelActionsFor(path),
);

Widget _buildSyncAction(BuildContext context, WidgetRef ref) =>
    const SyncPill();
