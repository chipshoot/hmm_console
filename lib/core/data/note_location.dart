/// Optional note location (Phase 2b). All-or-none at the boundary:
/// [empty] signals "clear", a populated instance signals "set", and a null
/// reference (in patch objects) signals "don't touch".
class NoteLocation {
  const NoteLocation({this.latitude, this.longitude, this.label});

  final double? latitude;
  final double? longitude;
  final String? label;

  /// Coordinates define presence: a location with null lat/lng is "empty"
  /// even if it carries a [label]. A label alone is never a location.
  bool get isEmpty => latitude == null && longitude == null;

  static const empty = NoteLocation();
}
