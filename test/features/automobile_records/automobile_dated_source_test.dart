import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/features/automobile_records/data/automobile_dated_source.dart';
import 'package:hmm_console/features/automobile_records/data/repositories/insurance_repository.dart';
import 'package:hmm_console/features/automobile_records/data/repositories/scheduled_service_repository.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/auto_insurance_policy.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/auto_scheduled_service.dart';
import 'package:hmm_console/features/calendar/contract/dated_note.dart';
import 'package:hmm_console/features/calendar/domain/calendar_event.dart';
import 'package:hmm_console/features/calendar/domain/event_time.dart';
import 'package:hmm_console/features/gas_log/data/repositories/automobile_repository.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';

class _Autos implements IAutomobileRepository {
  _Autos(this.list);
  final List<Automobile> list;
  @override
  Future<List<Automobile>> getAutomobiles() async => list;
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _Policies implements IInsuranceRepository {
  _Policies(this.byAuto);
  final Map<int, List<AutoInsurancePolicy>> byAuto;
  @override
  Future<List<AutoInsurancePolicy>> getPolicies(int autoId) async =>
      byAuto[autoId] ?? const [];
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _Schedules implements IScheduledServiceRepository {
  _Schedules(this.byAuto);
  final Map<int, List<AutoScheduledService>> byAuto;
  @override
  Future<List<AutoScheduledService>> getSchedules(int autoId) async =>
      byAuto[autoId] ?? const [];
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _Notes implements IHmmNoteRepository {
  _Notes(this.byId);
  final Map<int, HmmNote> byId;
  @override
  Future<HmmNote?> getNoteById(int id) async => byId[id];
  @override
  Future<HmmNote?> getNoteByUuid(String uuid) async {
    for (final n in byId.values) {
      if (n.uuid == uuid) return n;
    }
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

HmmNote _note(int id, {int? parent, DateTime? deletedAt}) => HmmNote(
  id: id,
  uuid: 'u$id',
  subject: 's',
  authorId: 1,
  createDate: DateTime.utc(2026),
  parentNoteId: parent,
  deletedAt: deletedAt,
);

Automobile _car(
  int id, {
  bool active = true,
  DateTime? reg,
  String maker = 'Honda',
}) => Automobile(
  id: id,
  year: 2020,
  meterReading: 0,
  maker: maker,
  model: 'Civic',
  isActive: active,
  registrationExpiryDate: reg,
);

AutoInsurancePolicy _pol(
  int id,
  int auto,
  DateTime expiry, {
  bool active = true,
  String provider = 'Intact',
}) => AutoInsurancePolicy(
  id: id,
  automobileId: auto,
  provider: provider,
  policyNumber: 'P',
  effectiveDate: DateTime.utc(2025),
  expiryDate: expiry,
  premium: 1,
  isActive: active,
);

AutoScheduledService _sched(
  int id,
  int auto, {
  DateTime? due,
  bool active = true,
}) => AutoScheduledService(
  id: id,
  automobileId: auto,
  name: 'Oil',
  nextDueDate: due,
  isActive: active,
);

void main() {
  final today = DateTime(2026, 11, 21, 15, 30);
  final notes = {
    1: _note(1),
    2: _note(2),
    10: _note(10, parent: 1),
    11: _note(11, parent: 1),
    20: _note(20, parent: 1),
    21: _note(21, parent: 1),
  };

  Future<List<DatedItem>> items({
    List<Automobile>? cars,
    Map<int, List<AutoInsurancePolicy>> policies = const {},
    Map<int, List<AutoScheduledService>> schedules = const {},
    Map<int, HmmNote>? noteMap,
  }) async {
    final src = AutomobileDatedSource(
      automobiles: () => _Autos(cars ?? [_car(1)]),
      insurance: () => _Policies(policies),
      schedules: () => _Schedules(schedules),
      notes: () => _Notes(noteMap ?? notes),
      now: () => today,
    );
    return [for (final n in await src.datedNotes()) ...n.dates];
  }

  test('registration item', () async {
    final r = await items(cars: [_car(1, reg: DateTime(2027, 2, 3))]);
    expect(r, hasLength(1));
    expect(r.single.key, 'vehicle:u1:registration');
    expect(r.single.kind, LinkedKind.registrationExpiry);
    expect(r.single.args, {'vehicle': '2020 Honda Civic'});
    expect(r.single.date, const AllDay(2027, 2, 3));
    expect(r.single.owner.subsystem, kLinkedSubsystemAutomobile);
    expect(r.single.owner.noteUuid, 'u1');
  });

  test('sold vehicle contributes nothing', () async {
    final r = await items(
      cars: [_car(1, active: false, reg: DateTime(2027, 2, 3))],
      policies: {
        1: [_pol(10, 1, DateTime(2027, 1, 1))],
      },
      schedules: {
        1: [_sched(20, 1, due: DateTime(2027, 1, 1))],
      },
    );
    expect(r, isEmpty);
  });

  test('policy expired 91 days ago is out, 90 days ago is in', () async {
    // today 2026-11-21: -90d = 2026-08-23, -91d = 2026-08-22.
    final r = await items(
      policies: {
        1: [
          _pol(10, 1, DateTime(2026, 8, 23).toUtc()),
          _pol(11, 1, DateTime(2026, 8, 22).toUtc()),
        ],
      },
    );
    expect(r.map((e) => e.key), ['insurance:u10:expiry']);
    expect(r.single.date, const AllDay(2026, 8, 23));
    expect(r.single.kind, LinkedKind.insuranceExpiry);
    expect(r.single.owner.subsystem, kLinkedSubsystemInsurance);
  });

  test('local-midnight dates stored as UTC keep their local day', () async {
    final r = await items(
      policies: {
        1: [_pol(10, 1, DateTime(2027, 3, 14).toUtc())],
      },
      schedules: {
        1: [_sched(20, 1, due: DateTime(2027, 3, 14).toUtc())],
      },
    );
    expect(r.map((e) => e.date), [
      const AllDay(2027, 3, 14),
      const AllDay(2027, 3, 14),
    ]);
  });

  test('inactive policy contributes nothing', () async {
    final r = await items(
      policies: {
        1: [_pol(10, 1, DateTime(2027, 1, 1).toUtc(), active: false)],
      },
    );
    expect(r, isEmpty);
  });

  test('inactive schedule or no due date contributes nothing', () async {
    final r = await items(
      schedules: {
        1: [
          _sched(20, 1, due: DateTime(2027, 1, 1).toUtc(), active: false),
          _sched(21, 1),
        ],
      },
    );
    expect(r, isEmpty);
  });

  test('service item', () async {
    final r = await items(
      schedules: {
        1: [_sched(20, 1, due: DateTime(2027, 1, 5).toUtc())],
      },
    );
    expect(r.single.key, 'service:u20:due');
    expect(r.single.kind, LinkedKind.serviceDue);
    expect(r.single.args, {'vehicle': '2020 Honda Civic', 'service': 'Oil'});
    expect(r.single.date, const AllDay(2027, 1, 5));
    expect(r.single.owner.subsystem, kLinkedSubsystemScheduledService);
  });

  test('insurer goes in reminderBody', () async {
    final r = await items(
      policies: {
        1: [
          _pol(10, 1, DateTime(2027, 1, 1).toUtc()),
          _pol(11, 1, DateTime(2027, 1, 1).toUtc(), provider: ''),
        ],
      },
    );
    expect(r[0].reminderBody, 'Intact');
    expect(r[1].reminderBody, isNull);
  });

  test(
    'a record whose uuid lookup fails is skipped, others still listed',
    () async {
      final r = await items(
        policies: {
          1: [
            _pol(10, 1, DateTime(2027, 1, 1).toUtc()),
            _pol(99, 1, DateTime(2027, 1, 1).toUtc()),
          ],
        },
        noteMap: {...notes}..remove(99),
      );
      expect(r.map((e) => e.key), ['insurance:u10:expiry']);
    },
  );

  test('a deleted note is skipped', () async {
    final r = await items(
      policies: {
        1: [_pol(10, 1, DateTime(2027, 1, 1).toUtc())],
      },
      noteMap: {
        ...notes,
        10: _note(10, parent: 1, deletedAt: DateTime.utc(2026)),
      },
    );
    expect(r, isEmpty);
  });

  group('locationOf', () {
    final src = AutomobileDatedSource(
      automobiles: () => _Autos([]),
      insurance: () => _Policies({}),
      schedules: () => _Schedules({}),
      notes: () => _Notes({
        ...notes,
        30: _note(30, parent: 1, deletedAt: DateTime.utc(2026)),
      }),
    );
    EventOwner o(String s, String? u) => EventOwner(subsystem: s, noteUuid: u);

    test('maps a policy owner to its edit route', () async {
      expect(
        await src.locationOf(o(kLinkedSubsystemInsurance, 'u10')),
        '/automobiles/manage/1/insurance/10/edit',
      );
    });
    test('vehicle and schedule routes', () async {
      expect(
        await src.locationOf(o(kLinkedSubsystemAutomobile, 'u2')),
        '/automobiles/manage/2/edit',
      );
      expect(
        await src.locationOf(o(kLinkedSubsystemScheduledService, 'u20')),
        '/automobiles/manage/1/scheduled-services/20/edit',
      );
    });
    test('null when missing, deleted or foreign', () async {
      expect(
        await src.locationOf(o(kLinkedSubsystemInsurance, 'nope')),
        isNull,
      );
      expect(await src.locationOf(o(kLinkedSubsystemInsurance, 'u30')), isNull);
      expect(await src.locationOf(o(kLinkedSubsystemInsurance, null)), isNull);
      expect(await src.locationOf(o('contacts', 'u1')), isNull);
    });
  });

  test('subsystems', () {
    final src = AutomobileDatedSource(
      automobiles: () => _Autos([]),
      insurance: () => _Policies({}),
      schedules: () => _Schedules({}),
      notes: () => _Notes({}),
    );
    expect(src.subsystems, {
      kLinkedSubsystemAutomobile,
      kLinkedSubsystemInsurance,
      kLinkedSubsystemScheduledService,
    });
  });
}
