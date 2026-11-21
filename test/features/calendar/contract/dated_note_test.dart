import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/calendar/contract/dated_note.dart';
import 'package:hmm_console/features/calendar/domain/calendar_event.dart';
import 'package:hmm_console/features/calendar/domain/event_time.dart';
import 'package:hmm_console/features/calendar/domain/recurrence_rule.dart';

DatedItem item({String name = 'Mum', RecurrenceRule? repeat}) => DatedItem(
  key: 'contact:a:birthday',
  kind: LinkedKind.birthday,
  args: {
    'name': name,
    'nested': {'a': 1},
  },
  date: const AllDay(2000, 3, 4),
  repeat: repeat,
  owner: const EventOwner(subsystem: kLinkedSubsystemContacts, noteUuid: 'a'),
);

void main() {
  test('linkedEventId is stable and key-specific', () {
    expect(linkedEventId('licence:expiry'), linkedEventId('licence:expiry'));
    expect(
      linkedEventId('licence:expiry'),
      isNot(linkedEventId('contact:a:birthday')),
    );
    expect(linkedEventId('licence:expiry')[14], '5');
  });

  test('DatedItem equality compares args by value', () {
    expect(item(), item());
    expect(item().hashCode, item().hashCode);
    expect(item(), isNot(item(name: 'Dad')));
    expect(item().eventId, linkedEventId('contact:a:birthday'));
  });

  test('DatedItem compares repeat by format()', () {
    final a = item(repeat: RecurrenceRule.lunarYearly(month: 1, day: 2));
    final b = item(repeat: RecurrenceRule.lunarYearly(month: 1, day: 2));
    expect(a, b);
    expect(a, isNot(item()));
  });
}
