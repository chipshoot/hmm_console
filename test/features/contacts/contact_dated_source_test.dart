import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/calendar/contract/dated_note.dart';
import 'package:hmm_console/features/calendar/domain/calendar_event.dart';
import 'package:hmm_console/features/contacts/data/contact_birthday_calendar.dart';
import 'package:hmm_console/features/contacts/data/contact_dated_source.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact_birthday.dart';

import 'data/contact_repository_fakes.dart';

const _bday = ContactBirthday(
  calendar: BirthdayCalendar.lunar,
  month: 4,
  day: 5,
  year: 1985,
);

Contact _c({
  bool remind = true,
  bool active = true,
  ContactBirthday? b = _bday,
}) => Contact(
  id: 'c-1',
  contactType: ContactType.person,
  firstName: 'Ada',
  lastName: 'Lovelace',
  birthday: b,
  remindBirthday: remind,
  isActivated: active,
);

void main() {
  late InMemoryContactRepository repo;
  late ContactDatedSource source;
  setUp(() {
    repo = InMemoryContactRepository();
    source = ContactDatedSource(() => repo);
  });

  test('Remind me off -> nothing', () async {
    repo.seed(_c(remind: false));
    expect(await source.datedNotes(), isEmpty);
  });

  test('deactivated contact -> nothing', () async {
    repo.seed(_c(active: false));
    expect(await source.datedNotes(), isEmpty);
    expect(
      await source.locationOf(
        const EventOwner(subsystem: kLinkedSubsystemContacts, noteUuid: 'c-1'),
      ),
      isNull,
    );
  });

  test(
    'item carries name, birthYear and calendar args and the birthday rule',
    () async {
      repo.seed(_c());
      final notes = await source.datedNotes();
      final item = notes.single.dates.single;
      expect(item.key, 'contact:c-1:birthday');
      expect(item.kind, LinkedKind.birthday);
      expect(item.args, {
        'name': _c().displayName,
        'birthYear': 1985,
        'calendar': 'lunar',
      });
      expect(item.repeat!.format(), birthdayRule(_bday).format());
      expect(item.date, birthdaySeriesStart(_bday)!);
      expect(item.owner.noteUuid, 'c-1');
      expect(await source.locationOf(item.owner), '/contacts/c-1');
    },
  );

  test('locationOf is null for a missing contact', () async {
    expect(
      await source.locationOf(
        const EventOwner(subsystem: kLinkedSubsystemContacts, noteUuid: 'nope'),
      ),
      isNull,
    );
  });

  test(
    'lunar 2099 month 12 day 30 yields an item starting 2100-02-08',
    () async {
      repo.seed(
        _c(
          b: const ContactBirthday(
            calendar: BirthdayCalendar.lunar,
            month: 12,
            day: 30,
            year: 2099,
          ),
        ),
      );
      final item = (await source.datedNotes()).single.dates.single;
      expect((item.date.year, item.date.month, item.date.day), (2100, 2, 8));
    },
  );

  test('an unresolvable lunar birthday emits no item', () async {
    repo.seed(
      _c(
        b: const ContactBirthday(
          calendar: BirthdayCalendar.lunar,
          month: 13,
          day: 1,
        ),
      ),
    );
    final notes = await source.datedNotes();
    expect([for (final n in notes) ...n.dates], isEmpty);
  });
}
