import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One entry in the Quick Access Panel's extensible registry
/// (quickPanelActionsProvider). Two shapes:
///   - QuickPanelAction.simple: a uniform icon+label tile that runs onTap
///     (the panel handles dismiss).
///   - QuickPanelAction.custom: a caller-provided builder widget, for
///     stateful entries like the Sync status pill.
/// Adding a future button is appending one of these to the provider — no
/// panel-layout change needed.
class QuickPanelAction {
  const QuickPanelAction.simple({
    required this.label,
    required this.icon,
    required this.onTap,
  }) : builder = null;

  const QuickPanelAction.custom({
    required this.label,
    required this.builder,
  })  : icon = null,
        onTap = null;

  final String label;
  final IconData? icon;
  final void Function(WidgetRef ref)? onTap;
  final Widget Function(BuildContext context, WidgetRef ref)? builder;

  bool get isCustom => builder != null;
}
