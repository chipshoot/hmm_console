import '../../calendar/contract/dated_note.dart';
import '../../calendar/domain/calendar_event.dart';
import '../../calendar/domain/event_time.dart';
import '../domain/driver_licence.dart';
import 'i_driver_licence_repository.dart';

const _kLicenceKey = 'licence:expiry';
const _kLicenceSelf = 'self';

/// Adapter so the licence entity stays free of calendar types.
class LicenceDatedNote implements DatedNote {
  const LicenceDatedNote(this.licence);

  final DriverLicence licence;

  @override
  List<DatedItem> get dates {
    final e = licence.expiryDate;
    if (e == null) return const [];
    // The licence screens print the stored date's own year/month/day, so the
    // same components are the calendar day here.
    return [
      DatedItem(
        key: _kLicenceKey,
        kind: LinkedKind.licenceExpiry,
        args: const {},
        date: AllDay(e.year, e.month, e.day),
        owner: const EventOwner(
          subsystem: kLinkedSubsystemLicence,
          noteUuid: _kLicenceSelf,
        ),
      ),
    ];
  }
}

/// Supplies the driver licence expiry to the linked-dates matcher. The
/// repository is read lazily because it throws in Cloud API mode.
class LicenceDatedSource implements DatedNoteSource {
  LicenceDatedSource(this._repo);

  final IDriverLicenceRepository Function() _repo;

  @override
  Set<String> get subsystems => const {kLinkedSubsystemLicence};

  @override
  Future<List<DatedNote>> datedNotes() async {
    final licence = await _repo().getLicence();
    return licence == null ? const [] : [LicenceDatedNote(licence)];
  }

  @override
  Future<String?> locationOf(EventOwner owner) async {
    if (owner.subsystem != kLinkedSubsystemLicence) return null;
    return await _repo().getLicence() == null ? null : '/licence';
  }
}
