import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/gas_station_repository.dart';
import '../domain/entities/gas_station.dart';

class GasStationsState extends AsyncNotifier<List<GasStation>> {
  @override
  Future<List<GasStation>> build() async {
    return ref.read(gasStationRepositoryProvider).getGasStations();
  }

  Future<GasStation> getOrCreateStation(String name) async {
    final stations = state.value ?? [];

    // Check if station already exists (case-insensitive match)
    final existing = stations
        .where((s) => s.name.toLowerCase() == name.toLowerCase() && s.isActive)
        .firstOrNull;
    if (existing != null) {
      return existing;
    }

    // Create new station with name only
    final created = await ref
        .read(gasStationRepositoryProvider)
        .createGasStation(GasStation(name: name));

    // Refresh station list
    state = AsyncValue.data([...stations, created]);

    return created;
  }

  Future<GasStation> createStation(GasStation station) async {
    final created =
        await ref.read(gasStationRepositoryProvider).createGasStation(station);

    // Add to local state
    final stations = state.value ?? [];
    state = AsyncValue.data([...stations, created]);

    return created;
  }

  Future<GasStation> updateStation(int id, GasStation station) async {
    final updated = await ref
        .read(gasStationRepositoryProvider)
        .updateGasStation(id, station);

    // Update local state
    final stations = state.value ?? [];
    state = AsyncValue.data(
      stations.map((s) => s.id == id ? updated : s).toList(),
    );

    return updated;
  }

  Future<void> deleteStation(int id) async {
    await ref.read(gasStationRepositoryProvider).deleteGasStation(id);

    // Remove from local state (backend soft-deletes, so mark inactive)
    final stations = state.value ?? [];
    state = AsyncValue.data(
      stations
          .map((s) => s.id == id ? s.copyWith(isActive: false) : s)
          .toList(),
    );
  }

  void refresh() {
    ref.invalidateSelf();
  }
}

final gasStationsStateProvider =
    AsyncNotifierProvider<GasStationsState, List<GasStation>>(
  () => GasStationsState(),
);
