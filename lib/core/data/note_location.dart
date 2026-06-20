/// Optional note location (Phase 2b). All-or-none at the boundary:
/// [empty] signals "clear", a populated instance signals "set", and a null
/// reference (in patch objects) signals "don't touch".
class NoteLocation {
  const NoteLocation({this.latitude, this.longitude, this.label});

  final double? latitude;
  final double? longitude;
  final String? label;

  bool get isEmpty => latitude == null && longitude == null;

  static const empty = NoteLocation();
}
