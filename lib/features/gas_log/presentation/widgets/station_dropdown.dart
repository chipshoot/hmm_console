import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/gas_station.dart';
import '../../states/gas_stations_state.dart';

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
  @override
  Widget build(BuildContext context) {
    final stationsAsync = ref.watch(gasStationsStateProvider);

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
      error: (_, _) => _buildAutocomplete([]),
      data: (stations) {
        final activeStations =
            stations.where((s) => s.isActive).toList();
        return _buildAutocomplete(activeStations);
      },
    );
  }

  Widget _buildAutocomplete(List<GasStation> stations) {
    return Autocomplete<GasStation>(
      initialValue: TextEditingValue(text: widget.initialValue ?? ''),
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return stations;
        }
        return stations.where((s) => s.name
            .toLowerCase()
            .contains(textEditingValue.text.toLowerCase()));
      },
      displayStringForOption: (station) => station.name,
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Station Name',
            border: const OutlineInputBorder(),
            hintText: stations.isEmpty
                ? 'Type to create new station'
                : 'Select or type new station',
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      controller.clear();
                      widget.onStationChanged(null);
                    },
                  )
                : null,
          ),
          onChanged: (value) {
            final match = stations
                .where((s) =>
                    s.name.toLowerCase() == value.toLowerCase() && s.isActive)
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
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final station = options.elementAt(index);
                  return ListTile(
                    title: Text(station.name),
                    subtitle: station.city != null
                        ? Text(station.city!)
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
