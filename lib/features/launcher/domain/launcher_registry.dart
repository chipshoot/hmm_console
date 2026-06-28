import 'package:flutter/material.dart';

import 'launcher_destination.dart';

/// Single source of truth for launcher destinations. Seeded from the
/// existing GoRouter named routes.
const List<LauncherDestination> launcherDestinations = [
  LauncherDestination(
    id: 'vehicles',
    title: 'Vehicles',
    synonyms: ['car', 'vehicle', 'auto', 'automobile', 'garage', 'manage cars'],
    icon: Icons.directions_car,
    routeName: 'automobileManagement', // RouterNames.automobileManagement.name
  ),
  LauncherDestination(
    id: 'gasLog',
    title: 'Gas Log',
    synonyms: ['gas', 'fuel', 'fill-up', 'petrol', 'mileage', 'fuel log'],
    icon: Icons.local_gas_station,
    routeName: 'gasLogList',
    needsVehicle: true,
    usesVehiclePathId: false, // scopes via selectedAutomobileIdProvider
  ),
  LauncherDestination(
    id: 'serviceRecords',
    title: 'Service Log',
    synonyms: ['service', 'maintenance', 'repair', 'car service', 'service record'],
    icon: Icons.build,
    routeName: 'serviceRecords',
    needsVehicle: true,
    usesVehiclePathId: true,
  ),
  LauncherDestination(
    id: 'scheduledServices',
    title: 'Scheduled Services',
    synonyms: ['scheduled', 'reminder', 'upcoming service', 'maintenance schedule'],
    icon: Icons.event,
    routeName: 'scheduledServices',
    needsVehicle: true,
    usesVehiclePathId: true,
  ),
  LauncherDestination(
    id: 'insurance',
    title: 'Insurance',
    synonyms: ['insurance', 'policy', 'coverage'],
    icon: Icons.shield,
    routeName: 'insurancePolicies',
    needsVehicle: true,
    usesVehiclePathId: true,
  ),
  LauncherDestination(
    id: 'vehicleNotes',
    title: 'Vehicle Notes',
    synonyms: ['vehicle notes', 'car notes'],
    icon: Icons.note_alt,
    routeName: 'vehicleNotes',
    needsVehicle: true,
    usesVehiclePathId: true,
  ),
  LauncherDestination(
    id: 'notes',
    title: 'Notes',
    synonyms: ['note', 'notes', 'journal', 'memo'],
    icon: Icons.description,
    routeName: 'notesList',
  ),
  LauncherDestination(
    id: 'gasStations',
    title: 'Gas Stations',
    synonyms: ['station', 'gas station', 'fuel station', 'discount'],
    icon: Icons.ev_station,
    routeName: 'gasStationManagement',
  ),
  LauncherDestination(
    id: 'settings',
    title: 'Settings',
    synonyms: ['settings', 'preferences', 'config', 'options'],
    icon: Icons.settings,
    routeName: 'settings',
  ),
];

/// id -> destination lookup for resolving favorites/recents/aliases.
final Map<String, LauncherDestination> launcherDestinationsById = {
  for (final d in launcherDestinations) d.id: d,
};
