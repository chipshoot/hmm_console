/// Which piece of a referenced note a cheatsheet row shows.
enum SourceGranularity {
  /// A single scalar leaf of the note's content JSON, addressed by a dotted
  /// path (e.g. `GasLog.station`). There is no catalog field-schema on the
  /// client, so paths come from introspecting the content itself.
  field,

  /// The block under a markdown heading in the note's description/content.
  section,

  /// The whole note body.
  whole,
}

/// What tapping a resolved value does. Explicit — v1 never infers an action
/// from the value's shape or the source's catalog.
enum ValueAction { call, map, none }

/// A reference to a piece of a note.
///
/// The referenced note is addressed by [noteUuid] — the cross-device stable
/// identity — never by the local int `HmmNote.id`, which differs per device.
class CheatsheetSource {
  const CheatsheetSource({
    required this.noteUuid,
    required this.kind,
    this.locator,
  });

  final String noteUuid;
  final SourceGranularity kind;

  /// `field` -> dotted JSON path; `section` -> heading text; `whole` -> null.
  final String? locator;

  CheatsheetSource copyWith({
    String? noteUuid,
    SourceGranularity? kind,
    String? locator,
  }) =>
      CheatsheetSource(
        noteUuid: noteUuid ?? this.noteUuid,
        kind: kind ?? this.kind,
        locator: locator ?? this.locator,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CheatsheetSource &&
        other.noteUuid == noteUuid &&
        other.kind == kind &&
        other.locator == locator;
  }

  @override
  int get hashCode => Object.hash(noteUuid, kind, locator);

  @override
  String toString() =>
      'CheatsheetSource(noteUuid: $noteUuid, kind: ${kind.name}, locator: $locator)';
}
