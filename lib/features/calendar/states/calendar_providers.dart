import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/data_mode.dart';
import '../../../core/data/local/local_hmm_note_repository.dart';
import '../../../core/data/local/local_note_catalog_repository.dart';
import '../contract/calendar_errors.dart';
import '../contract/calendar_service.dart';
import '../contract/i_calendar_repository.dart';
import '../data/default_calendar_service.dart';
import '../data/local_calendar_repository.dart';

final localCalendarRepositoryProvider = Provider<ICalendarRepository>((ref) {
  return LocalCalendarRepository(
    ref.watch(localHmmNoteRepositoryProvider),
    ref.watch(localNoteCatalogRepositoryProvider),
  );
});

/// local and cloudStorage use the local store; cloudApi has no calendar
/// repository yet and throws [CalendarCloudApiUnavailable] (no fallback).
final calendarRepositoryProvider = Provider<ICalendarRepository>((ref) {
  final mode = ref.watch(dataModeProvider);
  if (mode == DataMode.cloudApi) throw CalendarCloudApiUnavailable();
  return ref.watch(localCalendarRepositoryProvider);
});

/// The only calendar API other subsystems use. Wraps
/// [calendarRepositoryProvider], so cloudApi mode throws the same error.
final calendarServiceProvider = Provider<CalendarService>((ref) {
  return DefaultCalendarService(ref.watch(calendarRepositoryProvider));
});
