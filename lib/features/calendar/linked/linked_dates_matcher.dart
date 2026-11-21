import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../contract/dated_note.dart';
import '../contract/i_calendar_repository.dart';
import '../domain/calendar_event.dart';
import '../domain/linked_event.dart';
import '../presentation/linked_event_title.dart';

/// What one matcher run did.
class MatchResult {
  const MatchResult(this.created, this.updated, this.removed);
  final int created, updated, removed;

  @override
  bool operator ==(Object other) =>
      other is MatchResult &&
      other.created == created &&
      other.updated == updated &&
      other.removed == removed;

  @override
  int get hashCode => Object.hash(created, updated, removed);

  @override
  String toString() => 'MatchResult($created, $updated, $removed)';
}

/// The reminders a new linked event starts with: a birthday on the day at
/// 09:00, anything else 30 days before.
List<Reminder> defaultLinkedReminders(LinkedKind kind) => [
  Reminder(minutesBefore: kind == LinkedKind.birthday ? 0 : 43200),
];

/// Makes the stored linked events match the wanted [DatedItem]s.
///
/// Matcher-owned: `linked`, start, rrule, owner, `reminderBody` (and the title
/// when new or when kind/args change). Everything else (reminders, Time
/// Sensitive, notes, done/skip) belongs to the owner and is kept, including
/// from a soft-deleted event that comes back. Writes only on a difference.
class LinkedDatesMatcher {
  LinkedDatesMatcher(this._repo, {required AppLocalizations l}) : _l = l;

  final ICalendarRepository _repo;
  final AppLocalizations _l;

  /// With [removals] false (or when any item fails) nothing is deleted:
  /// the wanted list may be incomplete.
  Future<MatchResult> apply({
    required List<DatedItem> wanted,
    required Set<String> subsystems,
    bool removals = true,
  }) async {
    final items = <String, DatedItem>{};
    for (final item in wanted) {
      items.putIfAbsent(item.key, () => item);
    }
    var created = 0, updated = 0, removed = 0;
    final wantedIds = <String>{};
    var failed = false;
    for (final item in items.values) {
      final id = item.eventId;
      wantedIds.add(id);
      try {
        final live = await _repo.getEvent(id);
        if (live != null) {
          if (_matches(live, item)) continue;
          final info = linkedInfoOf(live);
          final sameContent =
              info != null &&
              info.kind == item.kind &&
              jsonEncode(linkedToJson(info.kind, info.args)) ==
                  jsonEncode(linkedToJson(item.kind, item.args));
          await _repo.saveEvent(_withOwned(live, item, retitle: !sameContent));
          updated++;
          continue;
        }
        final prev = await _repo.getEventIncludingDeleted(id);
        if (prev != null) {
          await _repo.saveEvent(_withOwned(prev, item, retitle: true));
        } else {
          await _repo.saveEvent(_fresh(item));
        }
        created++;
      } catch (e) {
        // One unreadable note or id collision must not block the rest.
        debugPrint('Linked date skipped (${e.runtimeType})');
        failed = true;
      }
    }
    if (!removals || failed) return MatchResult(created, updated, removed);
    for (final e in await _repo.eventsOwnedBySubsystems(subsystems)) {
      if (linkedInfoOf(e) == null || wantedIds.contains(e.id)) continue;
      await _repo.deleteEvent(e.id);
      removed++;
    }
    return MatchResult(created, updated, removed);
  }

  String _canonicalLinked(CalendarEvent e) {
    final info = linkedInfoOf(e);
    return info == null ? '' : jsonEncode(linkedToJson(info.kind, info.args));
  }

  bool _matches(CalendarEvent e, DatedItem item) =>
      _canonicalLinked(e) == jsonEncode(linkedToJson(item.kind, item.args)) &&
      e.start.wireKey == item.date.wireKey &&
      e.rrule == item.repeat?.format() &&
      e.owner?.subsystem == item.owner.subsystem &&
      e.owner?.noteUuid == item.owner.noteUuid &&
      e.extraFields['reminderBody'] == item.reminderBody;

  Map<String, Object?> _extra(Map<String, Object?> base, DatedItem item) {
    final extra = <String, Object?>{...base};
    extra['linked'] = linkedToJson(item.kind, item.args);
    if (item.reminderBody == null) {
      extra.remove('reminderBody');
    } else {
      extra['reminderBody'] = item.reminderBody;
    }
    return extra;
  }

  String _title(DatedItem item) =>
      linkedTitle(LinkedInfo(item.kind, item.args), _l);

  CalendarEvent _withOwned(
    CalendarEvent e,
    DatedItem item, {
    required bool retitle,
  }) => e.copyWith(
    title: retitle ? _title(item) : null,
    start: item.date,
    rrule: item.repeat?.format(),
    clearRrule: item.repeat == null,
    owner: EventOwner(
      subsystem: item.owner.subsystem,
      noteUuid: item.owner.noteUuid,
      extraFields: e.owner?.extraFields ?? const {},
    ),
    extraFields: _extra(e.extraFields, item),
  );

  CalendarEvent _fresh(DatedItem item) => CalendarEvent(
    id: item.eventId,
    title: _title(item),
    start: item.date,
    rrule: item.repeat?.format(),
    reminders: defaultLinkedReminders(item.kind),
    owner: item.owner,
    source: EventSource.subsystem,
    timeSensitive: true,
    updatedAt: DateTime.now(),
    extraFields: _extra(const {}, item),
  );
}
