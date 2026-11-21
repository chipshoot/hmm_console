import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/calendar/contract/dated_note.dart';
import 'package:hmm_console/features/calendar/domain/calendar_event.dart';
import 'package:hmm_console/features/calendar/domain/event_time.dart';
import 'package:hmm_console/features/driver_licence/data/i_driver_licence_repository.dart';
import 'package:hmm_console/features/driver_licence/data/licence_dated_source.dart';
import 'package:hmm_console/features/driver_licence/domain/driver_licence.dart';

class _Repo implements IDriverLicenceRepository {
  _Repo(this.licence);
  final DriverLicence? licence;
  @override
  Future<DriverLicence?> getLicence() async => licence;
  @override
  Future<DriverLicence> saveLicence(DriverLicence l) async => l;
  @override
  Future<int?> noteId() async => licence == null ? null : 1;
}

void main() {
  Future<List<DatedItem>> items(DriverLicence? l) async {
    final notes = await LicenceDatedSource(() => _Repo(l)).datedNotes();
    return [for (final n in notes) ...n.dates];
  }

  test('no licence -> nothing', () async {
    expect(await items(null), isEmpty);
  });

  test('no expiry -> no items', () async {
    expect(await items(const DriverLicence(number: 'X')), isEmpty);
  });

  test('expiry 2027-03-14 -> one item on AllDay(2027, 3, 14)', () async {
    final r = await items(DriverLicence(expiryDate: DateTime.utc(2027, 3, 14)));
    expect(r, hasLength(1));
    expect(r.single.key, 'licence:expiry');
    expect(r.single.kind, LinkedKind.licenceExpiry);
    expect(r.single.args, isEmpty);
    expect(r.single.date, const AllDay(2027, 3, 14));
    expect(r.single.owner.subsystem, kLinkedSubsystemLicence);
    expect(r.single.owner.noteUuid, 'self');
  });

  test('subsystems and location', () async {
    final withL = LicenceDatedSource(
        () => _Repo(DriverLicence(expiryDate: DateTime.utc(2027, 3, 14))));
    const owner = EventOwner(
        subsystem: kLinkedSubsystemLicence, noteUuid: 'self');
    expect(withL.subsystems, {kLinkedSubsystemLicence});
    expect(await withL.locationOf(owner), '/licence');
    expect(await LicenceDatedSource(() => _Repo(null)).locationOf(owner), isNull);
  });
}
