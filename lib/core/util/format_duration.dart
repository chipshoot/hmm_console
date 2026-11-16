/// A media length as a clock: `0:48`, `10:05`, or `1:02:05` from an hour.
/// Used by video link cards, attached videos, list rows and shared text.
String formatClock(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
  return '$m:$ss';
}

/// An attached video's length from its stored milliseconds, as a clock.
String formatVideoLength(int ms) => formatClock(ms ~/ 1000);
