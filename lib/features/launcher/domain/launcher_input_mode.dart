/// How the home search box interprets the current input.
enum LauncherInputMode {
  /// Nothing typed (or only whitespace) -> show the favorites/recents landing.
  empty,

  /// Leading '/' -> function search (the launcher).
  command,

  /// Plain text -> reserved for the future AI assistant (a stub in v1).
  assistant,
}

/// Classifies raw input. Leading whitespace is tolerated before '/'.
LauncherInputMode modeOf(String raw) {
  final t = raw.trimLeft();
  if (t.trim().isEmpty) return LauncherInputMode.empty;
  if (t.startsWith('/')) return LauncherInputMode.command;
  return LauncherInputMode.assistant;
}

/// The command-mode query: the text after the leading '/', trimmed.
/// Returns '' when not in command mode or when only '/' was typed.
String commandQuery(String raw) {
  final t = raw.trimLeft();
  if (!t.startsWith('/')) return '';
  return t.substring(1).trim();
}
