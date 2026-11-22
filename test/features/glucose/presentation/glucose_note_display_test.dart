import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/activity/domain/offset_date_time.dart';
import 'package:hmm_console/features/glucose/data/glucose_codec.dart';
import 'package:hmm_console/features/glucose/domain/glucose_reading.dart';
import 'package:hmm_console/features/glucose/domain/glucose_units.dart';
import 'package:hmm_console/features/glucose/presentation/glucose_note_display.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/l10n/gen/app_localizations_en.dart';

void main() {
  final l = AppLocalizationsEn();
  const display = GlucoseNoteDisplay();

  HmmNote note(String? content) => HmmNote(
    id: 1,
    uuid: 'abc',
    subject: 'Glucose:abc',
    content: content,
    authorId: 1,
    catalogId: 1,
    createDate: DateTime.utc(2026),
  );

  final content = GlucoseCodec.encode(
    GlucoseReading(
      id: 'abc',
      takenAt: OffsetDateTime.fromLocal(DateTime(2026, 11, 22, 8)),
      glucose: const GlucoseValue(6.2, GlucoseUnit.mmoll),
      updatedAt: DateTime.utc(2026, 11, 22),
    ),
  );

  test('title reads Glucose and the value', () {
    expect(display.title(note(content), l), 'Glucose 6.2 mmol/L');
  });

  test('unreadable content falls back to the plain title', () {
    expect(display.title(note('not json'), l), 'Glucose');
    expect(display.title(note(null), l), 'Glucose');
  });

  test('target opens the reading by its id', () {
    expect(display.target(note(content))!.params, {'id': 'abc'});
  });
}
