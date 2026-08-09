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
/// Every list screen in this app declares its create route as a child named
/// `new`, so the create target is always `<list path>/new`. That holds for
/// the vehicle-scoped screens too — the matched path already carries the
/// concrete id (`/automobiles/manage/7/services` → `.../7/services/new`),
/// which is why they can be offered here now. They could not be when the
/// panel only knew the location.
///
/// Each pattern CAPTURES the list path in group 1, and the create target is
/// that capture + `/new`. Capturing matters: the rule also matches detail
/// routes below the list, and deriving the target from the full path would
/// build nonsense — on `/notes/42` you would get `/notes/42/new`, which is
/// not a route.
///
/// Order matters: the vehicle-scoped rules must precede the bare
/// `/automobiles/manage` rule, which would otherwise swallow them.
class _CreateRule {
  const _CreateRule(this.pattern, this.label, this.icon);
  final String pattern;
  final String label;
  final IconData icon;
}

const _createRules = <_CreateRule>[
  _CreateRule(r'^(/notes)(/.*)?$', 'New Note', Icons.note_add_outlined),
  _CreateRule(
      r'^(/gas-logs)(/.*)?$', 'New Gas Log', Icons.local_gas_station_outlined),
  _CreateRule(
      r'^(/cheatsheets)(/.*)?$', 'New Cheatsheet', Icons.style_outlined),
  _CreateRule(r'^(/automobiles/manage/\d+/services)(/.*)?$', 'New Service',
      Icons.build_outlined),
  _CreateRule(r'^(/automobiles/manage/\d+/insurance)(/.*)?$', 'New Policy',
      Icons.shield_outlined),
  _CreateRule(r'^(/automobiles/manage/\d+/scheduled-services)(/.*)?$',
      'New Scheduled Service', Icons.event_outlined),
  _CreateRule(r'^(/automobiles/manage)(/.*)?$', 'New Vehicle',
      Icons.directions_car_outlined),
];

/// Patterns compiled once. Previously each lookup built a fresh [RegExp] per
/// rule, and did it twice — once to derive the target, once more to recover
/// the matched rule's label and icon.
final _compiledRules = [
  for (final rule in _createRules) (re: RegExp(rule.pattern), rule: rule),
];

/// Single pass: the matched rule and its target together, so callers never
/// re-scan the table.
({String target, _CreateRule rule})? _createFor(String path) {
  // On a create screen the action would push a second editor on top of the
  // one you are already filling in, so drop it there.
  if (path.endsWith('/new')) return null;
  for (final compiled in _compiledRules) {
    final m = compiled.re.firstMatch(path);
    if (m != null) return (target: '${m.group(1)}/new', rule: compiled.rule);
  }
  return null;
}

/// The route the create action pushes from [path], or null if this screen
/// has no create.
///
/// Public so it can be tested directly: [QuickPanelAction.onTap] takes a
/// WidgetRef, which is sealed in flutter_riverpod 3.x and cannot be faked,
/// so the target is unreachable through the action itself. It is also the
/// part most easily got wrong — deriving it from the full path instead of
/// the captured list prefix yields `/notes/42/new`, which is not a route.
String? quickPanelCreateTargetFor(String path) => _createFor(path)?.target;

List<QuickPanelAction> quickPanelActionsFor(String path) {
  final isHome = path == '/';

  final found = _createFor(path);
  final create = found?.rule;
  final createTarget = found?.target;

  return [
    if (!isHome)
      QuickPanelAction.simple(
        label: 'Home',
        icon: Icons.home_outlined,
        // GoRouter instance .go() — runs from above the Router (the overlay
        // context has no GoRouter ancestor), same as the old HomeButton.
        onTap: (ref) => ref.read(AppRouter.config).go('/'),
      ),
    if (create != null)
      QuickPanelAction.simple(
        label: create.label,
        icon: create.icon,
        // push, not go: the editor should return you where you came from.
        onTap: (ref) => ref.read(AppRouter.config).push(createTarget!),
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
///
/// autoDispose: the family is keyed on the route path, which carries record
/// ids (`/notes/42`, `/automobiles/manage/7/services`). Without it every
/// distinct path the panel is ever opened over stays cached for the life of
/// the session — unbounded growth on unbounded input.
final quickPanelActionsProvider =
    Provider.autoDispose.family<List<QuickPanelAction>, String>(
  (ref, path) => quickPanelActionsFor(path),
);

Widget _buildSyncAction(BuildContext context, WidgetRef ref) =>
    const SyncPill();
