import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';

import '../../../core/data/note_location.dart';
import '../../gas_log/providers/location_provider.dart';

/// Builds a human label from a placemark, e.g. "Seattle, WA". Null when the
/// placemark is null or yields no usable parts.
String? formatPlacemark(Placemark? p) {
  if (p == null) return null;
  final parts = [p.locality, p.administrativeArea]
      .where((s) => s != null && s.isNotEmpty)
      .cast<String>()
      .toList();
  return parts.isEmpty ? null : parts.join(', ');
}

/// Best-effort current-location capture: GPS fix + reverse-geocoded label.
/// Returns null when no fix is available (denied/off/timeout). The label may
/// be null even when coordinates are present (geocode failed).
///
/// The whole body is guarded: `Geolocator.getCurrentPosition` *throws*
/// `TimeoutException` (and on some platforms permission/service exceptions),
/// so we swallow any error and return null to honour the "best-effort, never
/// crash the editor" contract.
final noteLocationCaptureProvider = FutureProvider<NoteLocation?>((ref) async {
  try {
    final pos = await ref.watch(currentPositionProvider.future);
    if (pos == null) return null;
    final place = await ref.watch(reverseGeocodeProvider(
      (latitude: pos.latitude, longitude: pos.longitude),
    ).future);
    return NoteLocation(
      latitude: pos.latitude,
      longitude: pos.longitude,
      label: formatPlacemark(place),
    );
  } catch (_) {
    return null;
  }
});
