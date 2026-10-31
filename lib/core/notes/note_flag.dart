import 'dart:ui' show Color;

/// The seven note flag colours (Apple Mail palette). Persisted as
/// `NoteStates.flagColor`: null = unflagged, otherwise the enum index.
enum NoteFlagColor {
  red(Color(0xFFFF3B30)),
  orange(Color(0xFFFF9500)),
  yellow(Color(0xFFFFCC00)),
  green(Color(0xFF34C759)),
  blue(Color(0xFF007AFF)),
  purple(Color(0xFFAF52DE)),
  grey(Color(0xFF8E8E93));

  const NoteFlagColor(this.color);

  final Color color;

  /// The int stored in `NoteStates.flagColor` for this colour.
  int get stored => index;

  /// Display colour for a stored value. Null ⇒ unflagged (null). A value
  /// this build does not know (written by a newer client) shows as grey;
  /// the stored value itself is never rewritten.
  static NoteFlagColor? fromStored(int? value) {
    if (value == null) return null;
    if (value < 0 || value >= NoteFlagColor.values.length) {
      return NoteFlagColor.grey;
    }
    return NoteFlagColor.values[value];
  }
}
