import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../gas_log/providers/selected_automobile_provider.dart';
import '../../gas_log/states/automobiles_state.dart';
import '../domain/launcher_destination.dart';
import '../domain/vehicle_resolution.dart';

/// Resolves vehicle context (if needed) and pushes the destination's
/// route. For vehicle destinations it sets `selectedAutomobileIdProvider`
/// so gas-log + nested screens stay scoped to the same vehicle; if no
/// vehicle can be resolved it pushes the automobile selector instead.
Future<void> launchDestination(
  BuildContext context,
  WidgetRef ref,
  LauncherDestination dest,
) async {
  int? vid;
  if (dest.needsVehicle) {
    final selected = ref.read(selectedAutomobileIdProvider);
    final autos = await ref.read(automobilesStateProvider.future);
    vid = pickVehicle(selectedId: selected, automobiles: autos);
  }
  final target = resolveTarget(dest, vid);
  if (target.selectVehicleId != null) {
    ref.read(selectedAutomobileIdProvider.notifier).select(target.selectVehicleId);
  }
  if (!context.mounted) return;
  context.pushNamed(target.routeName, pathParameters: target.pathParameters);
}
