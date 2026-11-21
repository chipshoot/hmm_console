import '../../../core/data/local/local_hmm_note_repository.dart';
import '../../calendar/contract/dated_note.dart';
import '../../calendar/domain/calendar_event.dart';
import '../../calendar/domain/event_time.dart';
import '../../gas_log/data/repositories/automobile_repository.dart';
import '../domain/entities/auto_insurance_policy.dart';
import '../domain/entities/auto_scheduled_service.dart';
import 'repositories/insurance_repository.dart';
import 'repositories/scheduled_service_repository.dart';

/// A lapsed policy stays on the calendar this long, so a renewal reminder
/// that was missed is still visible.
const _kInsuranceGraceDays = 90;

/// One dated record (a vehicle, policy or schedule) for the linked-dates
/// matcher. Keeps the entities free of calendar types.
class AutomobileDatedNote implements DatedNote {
  const AutomobileDatedNote(this.dates);

  @override
  final List<DatedItem> dates;
}

/// Supplies vehicle registration expiry, insurance expiry and scheduled
/// service due dates. Repositories are read lazily because their providers
/// throw in Cloud API mode.
class AutomobileDatedSource implements DatedNoteSource {
  AutomobileDatedSource({
    required IAutomobileRepository Function() automobiles,
    required IInsuranceRepository Function() insurance,
    required IScheduledServiceRepository Function() schedules,
    required IHmmNoteRepository Function() notes,
    DateTime Function() now = DateTime.now,
  }) : _automobiles = automobiles,
       _insurance = insurance,
       _schedules = schedules,
       _notes = notes,
       _now = now;

  final IAutomobileRepository Function() _automobiles;
  final IInsuranceRepository Function() _insurance;
  final IScheduledServiceRepository Function() _schedules;
  final IHmmNoteRepository Function() _notes;
  final DateTime Function() _now;

  @override
  Set<String> get subsystems => const {
    kLinkedSubsystemAutomobile,
    kLinkedSubsystemInsurance,
    kLinkedSubsystemScheduledService,
  };

  // The record screens print the stored date's own year/month/day (no
  // toLocal), so those components are the calendar day here.
  static AllDay _day(DateTime d) => AllDay(d.year, d.month, d.day);

  Future<String?> _uuid(int id) async {
    final n = await _notes().getNoteById(id);
    return n == null || n.deletedAt != null ? null : n.uuid;
  }

  @override
  Future<List<DatedNote>> datedNotes() async {
    final now = _now();
    // Calendar-day comparison: today's local date minus the grace period.
    final cutoff = DateTime.utc(
      now.year,
      now.month,
      now.day - _kInsuranceGraceDays,
    );
    final out = <DatedNote>[];

    final autos = (await _automobiles().getAutomobiles())
        .where((a) => a.isActive)
        .toList();
    for (final car in autos) {
      final vehicle = car.displayName;
      final carUuid = await _uuid(car.id);

      final reg = car.registrationExpiryDate;
      if (carUuid != null && reg != null) {
        out.add(
          AutomobileDatedNote([
            DatedItem(
              key: 'vehicle:$carUuid:registration',
              kind: LinkedKind.registrationExpiry,
              args: {'vehicle': vehicle},
              date: _day(reg),
              owner: EventOwner(
                subsystem: kLinkedSubsystemAutomobile,
                noteUuid: carUuid,
              ),
            ),
          ]),
        );
      }

      for (final p in await _insurance().getPolicies(car.id)) {
        if (!p.isActive) continue;
        final e = p.expiryDate;
        if (DateTime.utc(e.year, e.month, e.day).isBefore(cutoff)) continue;
        final uuid = await _uuid(p.id);
        if (uuid == null) continue;
        out.add(AutomobileDatedNote([_policyItem(p, uuid, vehicle)]));
      }

      for (final s in await _schedules().getSchedules(car.id)) {
        final due = s.nextDueDate;
        if (!s.isActive || due == null) continue;
        final uuid = await _uuid(s.id);
        if (uuid == null) continue;
        out.add(AutomobileDatedNote([_serviceItem(s, due, uuid, vehicle)]));
      }
    }
    return out;
  }

  DatedItem _policyItem(AutoInsurancePolicy p, String uuid, String vehicle) =>
      DatedItem(
        key: 'insurance:$uuid:expiry',
        kind: LinkedKind.insuranceExpiry,
        args: {'vehicle': vehicle},
        date: _day(p.expiryDate),
        owner: EventOwner(subsystem: kLinkedSubsystemInsurance, noteUuid: uuid),
        reminderBody: p.provider.isEmpty ? null : p.provider,
      );

  DatedItem _serviceItem(
    AutoScheduledService s,
    DateTime due,
    String uuid,
    String vehicle,
  ) => DatedItem(
    key: 'service:$uuid:due',
    kind: LinkedKind.serviceDue,
    args: {'vehicle': vehicle, 'service': s.name},
    date: _day(due),
    owner: EventOwner(
      subsystem: kLinkedSubsystemScheduledService,
      noteUuid: uuid,
    ),
  );

  @override
  Future<String?> locationOf(EventOwner owner) async {
    final uuid = owner.noteUuid;
    if (uuid == null || !subsystems.contains(owner.subsystem)) return null;
    final note = await _notes().getNoteByUuid(uuid);
    if (note == null || note.deletedAt != null) return null;
    switch (owner.subsystem) {
      case kLinkedSubsystemAutomobile:
        return '/automobiles/manage/${note.id}/edit';
      case kLinkedSubsystemInsurance:
        final auto = note.parentNoteId;
        return auto == null
            ? null
            : '/automobiles/manage/$auto/insurance/${note.id}/edit';
      default:
        final auto = note.parentNoteId;
        return auto == null
            ? null
            : '/automobiles/manage/$auto/scheduled-services/${note.id}/edit';
    }
  }
}
