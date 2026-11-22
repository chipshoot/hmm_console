import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/navigation/route_names.dart';
import 'package:hmm_console/features/activity/data/activity_codec.dart';
import 'package:hmm_console/features/activity/domain/activity.dart';
import 'package:hmm_console/features/activity/domain/activity_kind.dart';
import 'package:hmm_console/features/activity/domain/builtin_activity_kinds.dart';
import 'package:hmm_console/features/activity/domain/offset_date_time.dart';
import 'package:hmm_console/features/activity/presentation/activity_note_display.dart';
import 'package:hmm_console/features/activity/presentation/activity_summary.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/rendering/note_display.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

final _reg = ActivityKindRegistry(builtinActivityKinds);
final _l = lookupAppLocalizations(const Locale('en'));

Activity _a(
  String kind,
  int minutes, {
  ActivityIntensity? intensity,
  List<ActivityMeasurement> measurements = const [],
  String? notes,
}) => Activity(
  id: 'a1',
  kind: kind,
  start: OffsetDateTime(
    DateTime.utc(2026, 11, 21, 23, 40),
    const Duration(hours: -5),
  ),
  durationMinutes: minutes,
  intensity: intensity,
  measurements: measurements,
  notes: notes,
  updatedAt: DateTime.utc(2026, 11, 21),
);

HmmNote _note(String subject, String? content, {String uuid = 'u1'}) => HmmNote(
  id: 1,
  uuid: uuid,
  subject: subject,
  content: content,
  authorId: 1,
  createDate: DateTime.utc(2026),
);

void main() {
  group('activitySummary', () {
    test('walk with intensity and distance', () {
      expect(
        activitySummary(
          _a(
            'health.walk',
            30,
            intensity: ActivityIntensity.moderate,
            measurements: const [
              ActivityMeasurement(name: 'distance', value: 2.4, unit: 'km'),
            ],
          ),
          _reg,
          _l,
        ),
        'Walk · 30 min · moderate · 2.4 km',
      );
    });

    test('reading with a linked note title', () {
      expect(
        activitySummary(_a('reading.reading', 40), _reg, _l, noteTitle: 'Dune'),
        'Reading · 40 min · "Dune"',
      );
    });

    test('unknown kind', () {
      expect(
        activitySummary(_a('health.xyz', 30), _reg, _l),
        'Other (health.xyz) · 30 min',
      );
    });

    test('hours and minutes', () {
      expect(
        activitySummary(_a('health.gym', 80), _reg, _l),
        'Gym · 1 h 20 min',
      );
      expect(activitySummary(_a('health.gym', 60), _reg, _l), 'Gym · 1 h');
    });

    test('a whole distance drops the decimals', () {
      expect(
        activitySummary(
          _a(
            'health.run',
            30,
            measurements: const [
              ActivityMeasurement(name: 'distance', value: 5, unit: 'mi'),
            ],
          ),
          _reg,
          _l,
        ),
        'Run · 30 min · 5 mi',
      );
    });
  });

  group('ActivityNoteDisplay', () {
    const d = ActivityNoteDisplay();
    final good = _a('health.walk', 30, notes: '\nEvening loop\nsecond');
    final content = jsonEncode(ActivityCodec.encode(good));

    test('is registered for the activity catalog', () {
      expect(ActivityNoteDisplay.catalogName, 'Hmm.ActivityMan.Activity');
      // The const map in noteDisplayRegistryProvider holds the entry.
      final reg = const NoteDisplayRegistry({
        ActivityNoteDisplay.catalogName: ActivityNoteDisplay(),
      });
      expect(reg.hasEntry(ActivityNoteDisplay.catalogName), isTrue);
    });

    test('title is the summary, preview the first notes line', () {
      final n = _note('Activity:a1', content, uuid: 'a1');
      expect(d.title(n, _l), 'Walk · 30 min');
      expect(d.display(n, _l), (
        title: 'Walk · 30 min',
        preview: 'Evening loop',
      ));
    });

    test('target is activityEdit with the id from the subject', () {
      final n = _note('Activity:a1', content, uuid: 'other');
      final t = d.target(n)!;
      expect(t.route, RouterNames.activityEdit);
      expect(t.params, {'id': 'a1'});
    });

    test('target falls back to the note uuid', () {
      final n = _note('Something', content, uuid: 'a1');
      final t = d.target(n)!;
      expect(t.route, RouterNames.activityEdit);
      expect(t.params, {'id': 'a1'});
    });

    test('an undecodable note shows the fallback title', () {
      final n = _note('Activity:bad', '{bad', uuid: 'bad');
      expect(d.title(n, _l), 'Activity');
      expect(d.display(n, _l), (title: 'Activity', preview: ''));
    });
  });
}
