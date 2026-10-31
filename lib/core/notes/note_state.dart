import 'note_flag.dart';

/// The user's own state about one note — pin + coloured flag (Notes
/// redesign G14). Not part of `HmmNote`: changing it is not a note edit.
class NoteState {
  const NoteState({
    required this.noteUuid,
    this.isPinned = false,
    this.flagColor,
    required this.lastModifiedDate,
  });

  /// No stored row: unpinned, unflagged, older than any real write.
  factory NoteState.none(String noteUuid) => NoteState(
        noteUuid: noteUuid,
        lastModifiedDate: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );

  /// The note's cross-device uuid (`Notes.uuid`).
  final String noteUuid;

  final bool isPinned;

  /// Raw stored flag: null = unflagged; 0–6 = [NoteFlagColor] index; any
  /// other int came from a newer client and is preserved verbatim.
  final int? flagColor;

  /// Per-state last-writer-wins clock.
  final DateTime lastModifiedDate;

  /// Display flag ([NoteFlagColor.grey] for an unknown stored value).
  NoteFlagColor? get flag => NoteFlagColor.fromStored(flagColor);
}
