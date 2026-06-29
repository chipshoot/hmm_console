import '../../../core/navigation/route_names.dart';
import '../../gas_log/domain/entities/automobile.dart';
import 'launcher_destination.dart';

/// Picks the vehicle to scope a launch to: the explicitly-selected
/// vehicle if any, else the only vehicle, else null (caller routes to
/// the picker). Pure — unit-tested in isolation.
int? pickVehicle({required int? selectedId, required List<Automobile> automobiles}) {
  if (selectedId != null) return selectedId;
  if (automobiles.length == 1) return automobiles.first.id;
  return null;
}

/// Where a launch should go, plus whether to set the selected-vehicle
/// provider first. Pure data so navigation can be decided + tested
/// without a BuildContext.
class LaunchTarget {
  const LaunchTarget(
    this.routeName, {
    this.pathParameters = const {},
    this.selectVehicleId,
  });

  final String routeName;
  final Map<String, String> pathParameters;

  /// If non-null, set `selectedAutomobileIdProvider` to this before
  /// navigating (keeps gas-log + nested screens scoped consistently).
  final int? selectVehicleId;
}

/// Turns a destination + resolved vehicle id into a [LaunchTarget].
LaunchTarget resolveTarget(LauncherDestination dest, int? resolvedVehicleId) {
  if (!dest.needsVehicle) return LaunchTarget(dest.routeName);
  if (resolvedVehicleId == null) {
    return LaunchTarget(RouterNames.automobileSelector.name);
  }
  if (dest.usesVehiclePathId) {
    return LaunchTarget(
      dest.routeName,
      pathParameters: {'id': '$resolvedVehicleId'},
      selectVehicleId: resolvedVehicleId,
    );
  }
  return LaunchTarget(dest.routeName, selectVehicleId: resolvedVehicleId);
}
