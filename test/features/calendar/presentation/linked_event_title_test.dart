import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/i18n/app_localizations_now.dart';
import 'package:hmm_console/core/i18n/locale_provider.dart';
import 'package:hmm_console/features/calendar/contract/dated_note.dart';
import 'package:hmm_console/features/calendar/domain/calendar_event.dart';
import 'package:hmm_console/features/calendar/domain/event_time.dart';
import 'package:hmm_console/features/calendar/domain/linked_event.dart';
import 'package:hmm_console/features/calendar/domain/occurrence.dart';
import 'package:hmm_console/features/calendar/notifications/reminder_sync.dart';
import 'package:hmm_console/features/calendar/presentation/linked_event_title.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

CalendarEvent event({
  Map<String, Object?> extra = const {},
  String title = 'T',
}) => CalendarEvent(
  id: 'e',
  title: title,
  start: const AllDay(2026, 2, 10),
  updatedAt: DateTime.utc(2026),
  extraFields: extra,
);

Map<String, Object?> linked(String kind, Map<String, Object?> args) => {
  'linked': {'kind': kind, 'args': args},
};

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final zh = lookupAppLocalizations(const Locale('zh'));

  test('linked birthday title follows the language', () {
    final e = event(extra: linked('birthday', {'name': 'Mum'}), title: 'Mum生日');
    expect(eventTitle(e, null, en), "Mum's birthday");
    expect(eventTitle(e, null, zh), 'Mum生日');
  });

  test('every kind renders in both languages', () {
    String t(String k, Map<String, Object?> a, AppLocalizations l) =>
        eventTitle(event(extra: linked(k, a)), null, l);
    expect(t('licenceExpiry', {}, en), "Driver's licence expires");
    expect(t('licenceExpiry', {}, zh), '驾照到期');
    expect(
      t('registrationExpiry', {'vehicle': 'Civic'}, en),
      'Civic registration expires',
    );
    expect(t('insuranceExpiry', {'vehicle': 'Civic'}, zh), 'Civic 保险到期');
    expect(
      t('serviceDue', {'vehicle': 'Civic', 'service': 'Oil'}, en),
      'Civic: Oil due',
    );
    expect(
      t('serviceDue', {'vehicle': 'Civic', 'service': 'Oil'}, zh),
      'Civic：Oil 到期',
    );
  });

  test('unknown kind falls back to the stored title', () {
    final e = event(extra: linked('passport', {}), title: 'Stored');
    expect(linkedInfoOf(e), isNull);
    expect(eventTitle(e, null, en), 'Stored');
  });

  test('malformed linked field is ignored', () {
    expect(linkedInfoOf(event(extra: {'linked': 'x'})), isNull);
    expect(
      linkedInfoOf(
        event(
          extra: {
            'linked': {'args': {}},
          },
        ),
      ),
      isNull,
    );
  });

  test('an occurrence title override wins', () {
    final e = event(extra: linked('birthday', {'name': 'Mum'}));
    final o = Occurrence(
      eventId: 'e',
      originalStart: e.start,
      start: DateTime.utc(2026, 2, 10),
      titleOverride: 'Party',
    );
    expect(eventTitle(e, o, en), 'Party');
  });

  test('linkedToJson sorts args; linkedInfoOf accepts any order', () {
    final j = linkedToJson(LinkedKind.serviceDue, {
      'vehicle': 'V',
      'service': 'S',
    });
    expect((j['args'] as Map).keys.toList(), ['service', 'vehicle']);
    expect(j['kind'], 'serviceDue');
    final info = linkedInfoOf(event(extra: {'linked': j}))!;
    expect(info.kind, LinkedKind.serviceDue);
    expect(info.args['vehicle'], 'V');
  });

  test('gregorian age', () {
    final info = LinkedInfo(LinkedKind.birthday, {
      'birthYear': 1990,
      'calendar': 'gregorian',
    });
    expect(birthdayAgeAt(info, DateTime(2026, 5, 1)), 36);
    expect(
      birthdayAgeAt(const LinkedInfo(LinkedKind.birthday, {}), DateTime(2026)),
      isNull,
    );
    expect(
      birthdayAgeAt(
        const LinkedInfo(LinkedKind.licenceExpiry, {'birthYear': 1990}),
        DateTime(2026),
      ),
      isNull,
    );
  });

  test('lunar age counts lunar years', () {
    final info = LinkedInfo(LinkedKind.birthday, {
      'birthYear': 1956,
      'calendar': 'lunar',
    });
    // 2026-02-10 is still lunar year 2025 (new year is 2026-02-17).
    expect(birthdayAgeAt(info, DateTime(2026, 2, 10)), 69);
  });

  test('age suffix shown for birthdays with a year only', () {
    final e = event(
      extra: linked('birthday', {
        'name': 'Mum',
        'birthYear': 1956,
        'calendar': 'gregorian',
      }),
    );
    expect(birthdayAgeSuffix(e, DateTime(2026, 2, 10), en), ' · turns 70');
    expect(birthdayAgeSuffix(e, DateTime(2026, 2, 10), zh), ' · 70岁');
    expect(birthdayAgeSuffix(event(), DateTime(2026), en), '');
  });

  test('notification title uses the linked title', () async {
    SharedPreferences.setMockInitialValues({'app_locale': 'en'});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(localeProvider);
    await pumpEventQueue();
    expect(c.read(appLocalizationsNowProvider).localeName, 'en');
    final e = event(extra: linked('licenceExpiry', {}));
    final o = Occurrence(
      eventId: 'e',
      originalStart: e.start,
      start: DateTime.utc(2026, 2, 9, 16),
      allDay: true,
    );
    expect(
      c.read(reminderTitleFormatProvider)(e, o),
      "All day · Driver's licence expires",
    );
  });
}
