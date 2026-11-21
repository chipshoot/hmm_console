import '../contract/dated_note.dart';
import '../domain/calendar_event.dart';

/// GoRouter location of the screen [owner]'s date comes from: asked of the
/// first source covering the owner's subsystem; null when that source has no
/// such entity any more, or no source covers the subsystem.
Future<String?> linkedSourceLocation(
  List<DatedNoteSource> sources,
  EventOwner owner,
) async {
  for (final s in sources) {
    if (s.subsystems.contains(owner.subsystem)) return s.locationOf(owner);
  }
  return null;
}
