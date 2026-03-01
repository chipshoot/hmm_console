import '../entities/gas_station.dart';

/// Returns a display name for a gas station that disambiguates
/// same-name stations by appending city (and country if needed).
///
/// - If the station name is unique among [allStations], returns just the name.
/// - If duplicates exist, appends " - City" to distinguish them.
/// - If city is also the same, appends " - City, Country".
/// - For a plain station name string (no station object), returns as-is.
String stationDisplayName(GasStation station, List<GasStation> allStations) {
  final sameName = allStations
      .where((s) => s.name.toLowerCase() == station.name.toLowerCase())
      .toList();

  if (sameName.length <= 1) {
    return station.name;
  }

  // Multiple stations with same name — disambiguate with city
  if (station.city != null && station.city!.isNotEmpty) {
    // Check if city alone is enough to disambiguate
    final sameCityCount = sameName
        .where((s) =>
            s.city != null &&
            s.city!.toLowerCase() == station.city!.toLowerCase())
        .length;

    if (sameCityCount > 1 &&
        station.country != null &&
        station.country!.isNotEmpty) {
      return '${station.name} - ${station.city}, ${station.country}';
    }
    return '${station.name} - ${station.city}';
  }

  // No city available — append address or just return name
  if (station.address != null && station.address!.isNotEmpty) {
    return '${station.name} - ${station.address}';
  }

  return station.name;
}

/// Resolves a station name string (from gas log) to a display name
/// using the station list for disambiguation.
String resolveStationDisplayName(
    String? stationName, List<GasStation> allStations) {
  if (stationName == null || stationName.isEmpty) return '';

  // Find matching station(s)
  final matches = allStations
      .where((s) => s.name.toLowerCase() == stationName.toLowerCase())
      .toList();

  if (matches.isEmpty) return stationName;
  if (matches.length == 1) return stationName;

  // Multiple matches — can't determine which one from name alone,
  // just return the name (gas log doesn't store station ID reliably)
  return stationName;
}
