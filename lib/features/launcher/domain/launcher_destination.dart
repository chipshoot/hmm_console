import 'package:flutter/widgets.dart';

/// A place the launcher can jump to (a feature screen or sub-screen).
/// Destinations are app navigation targets, not data entities.
@immutable
class LauncherDestination {
  const LauncherDestination({
    required this.id,
    required this.title,
    required this.icon,
    required this.routeName,
    this.synonyms = const [],
    this.needsVehicle = false,
    this.usesVehiclePathId = false,
  });

  /// Stable id (e.g. 'gasLog'); used by favorites/recents/aliases.
  final String id;
  final String title;
  final List<String> synonyms;
  final IconData icon;

  /// A `RouterNames` value's `.name`.
  final String routeName;

  /// True if the destination is scoped to a vehicle (must resolve one
  /// before navigating).
  final bool needsVehicle;

  /// True if the route takes the vehicle id as an `:id` path parameter
  /// (service/scheduled/insurance/vehicle-notes). False for Gas Log,
  /// which scopes via `selectedAutomobileIdProvider` and has no path id.
  final bool usesVehiclePathId;
}
