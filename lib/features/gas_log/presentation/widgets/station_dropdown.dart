import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/entities/gas_station.dart';
import '../../domain/services/station_display_name.dart';
import '../../providers/location_provider.dart';
import '../../states/gas_logs_state.dart';
import '../../states/gas_stations_state.dart';
import 'gas_station_form_dialog.dart';

class StationDropdown extends ConsumerStatefulWidget {
  final String? initialValue;
  final ValueChanged<GasStation?> onStationChanged;

  const StationDropdown({
    super.key,
    this.initialValue,
    required this.onStationChanged,
  });

  @override
  ConsumerState<StationDropdown> createState() => _StationDropdownState();
}

class _StationDropdownState extends ConsumerState<StationDropdown> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  /// Sort stations: nearby first (if GPS available), recently-used, then alphabetical.
  List<GasStation> _sortStations(
      List<GasStation> stations, GasLogsData gasLogsData, Position? userPos) {
    // Build a map of station name → most recent gas log date
    final recentUsage = <String, DateTime>{};
    for (final log in gasLogsData.items) {
      if (log.stationName != null && log.stationName!.isNotEmpty) {
        final key = log.stationName!.toLowerCase();
        final existing = recentUsage[key];
        if (existing == null || log.date.isAfter(existing)) {
          recentUsage[key] = log.date;
        }
      }
    }

    // Pre-compute distances if GPS is available
    final distances = <int, double>{};
    if (userPos != null) {
      for (final s in stations) {
        if (s.id != null && s.latitude != null && s.longitude != null) {
          distances[s.id!] = distanceInKm(
            userPos.latitude,
            userPos.longitude,
            s.latitude!,
            s.longitude!,
          );
        }
      }
    }

    final sorted = List<GasStation>.from(stations);
    sorted.sort((a, b) {
      final aDist = a.id != null ? distances[a.id!] : null;
      final bDist = b.id != null ? distances[b.id!] : null;

      // Both have location: sort by distance
      if (aDist != null && bDist != null) {
        return aDist.compareTo(bDist);
      }
      // Only one has distance: it goes first
      if (aDist != null) return -1;
      if (bDist != null) return 1;

      // Fall back to recent usage
      final aDate = recentUsage[a.name.toLowerCase()];
      final bDate = recentUsage[b.name.toLowerCase()];
      if (aDate != null && bDate != null) {
        return bDate.compareTo(aDate);
      }
      if (aDate != null) return -1;
      if (bDate != null) return 1;

      // Neither: alphabetical
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return sorted;
  }

  Future<void> _showAddStationDialog(String? prefillName) async {
    final created = await showDialog<GasStation>(
      context: context,
      builder: (_) => GasStationFormDialog(initialName: prefillName),
    );
    if (created != null && mounted) {
      final stations = ref.read(gasStationsStateProvider).value ?? [];
      _textController.text = stationDisplayName(created, stations);
      widget.onStationChanged(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stationsAsync = ref.watch(gasStationsStateProvider);
    final gasLogsAsync = ref.watch(gasLogsStateProvider);
    final gasLogs = gasLogsAsync.hasValue
        ? gasLogsAsync.value!
        : const GasLogsData();
    final positionAsync = ref.watch(currentPositionProvider);
    final userPos = positionAsync.hasValue ? positionAsync.value : null;

    return stationsAsync.when(
      loading: () => TextFormField(
        initialValue: widget.initialValue ?? '',
        decoration: const InputDecoration(
          labelText: 'Station Name',
          border: OutlineInputBorder(),
          suffixIcon: SizedBox(
            width: 20,
            height: 20,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        enabled: false,
      ),
      error: (_, _) => _buildAutocomplete([], null),
      data: (stations) {
        final activeStations = stations.where((s) => s.isActive).toList();
        final sorted = _sortStations(activeStations, gasLogs, userPos);
        return _buildAutocomplete(sorted, userPos);
      },
    );
  }

  Widget _buildAutocomplete(List<GasStation> stations, Position? userPos) {
    String displayName(GasStation s) => stationDisplayName(s, stations);

    String? distanceLabel(GasStation s) {
      if (userPos == null || s.latitude == null || s.longitude == null) {
        return null;
      }
      final km = distanceInKm(
        userPos.latitude,
        userPos.longitude,
        s.latitude!,
        s.longitude!,
      );
      return km < 1
          ? '${(km * 1000).round()} m'
          : '${km.toStringAsFixed(1)} km';
    }

    return Autocomplete<GasStation>(
      initialValue: TextEditingValue(text: widget.initialValue ?? ''),
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return stations;
        }
        final query = textEditingValue.text.toLowerCase();
        return stations.where((s) =>
            s.name.toLowerCase().contains(query) ||
            (s.city != null && s.city!.toLowerCase().contains(query)) ||
            (s.country != null && s.country!.toLowerCase().contains(query)));
      },
      displayStringForOption: displayName,
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        // Keep our reference to the controller for dialog callback
        _textController.text = controller.text;
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Station Name',
            border: const OutlineInputBorder(),
            hintText: stations.isEmpty
                ? 'Type to create new station'
                : 'Select or type new station',
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.add_business),
                  tooltip: 'Add new station',
                  onPressed: () {
                    focusNode.unfocus();
                    _showAddStationDialog(
                      controller.text.isNotEmpty ? controller.text : null,
                    );
                  },
                ),
                if (controller.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      controller.clear();
                      widget.onStationChanged(null);
                    },
                  ),
              ],
            ),
          ),
          onChanged: (value) {
            final lower = value.toLowerCase();
            final match = stations
                .where((s) =>
                    (s.name.toLowerCase() == lower ||
                        displayName(s).toLowerCase() == lower) &&
                    s.isActive)
                .firstOrNull;
            if (match != null) {
              widget.onStationChanged(match);
            } else {
              widget.onStationChanged(
                value.isNotEmpty ? GasStation(name: value) : null,
              );
            }
          },
          onFieldSubmitted: (_) => onSubmitted(),
        );
      },
      onSelected: (station) {
        widget.onStationChanged(station);
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length + 1,
                itemBuilder: (context, index) {
                  // First item: "Add New Station" button
                  if (index == 0) {
                    return ListTile(
                      leading: const Icon(Icons.add_circle_outline,
                          color: Colors.blue),
                      title: const Text(
                        'Add New Station',
                        style: TextStyle(color: Colors.blue),
                      ),
                      onTap: () {
                        _showAddStationDialog(null);
                      },
                    );
                  }
                  final station = options.elementAt(index - 1);
                  final name = displayName(station);
                  final dist = distanceLabel(station);
                  final details = [
                    ?station.address,
                    ?dist,
                  ].join(' \u2022 ');
                  return ListTile(
                    title: Text(name),
                    subtitle: details.isNotEmpty ? Text(details) : null,
                    trailing: dist != null
                        ? Text(
                            dist,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        : null,
                    onTap: () => onSelected(station),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
