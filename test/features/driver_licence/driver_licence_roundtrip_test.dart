// Reproduction attempt: save a licence through the notifier, then read it back
// the way a fresh navigation does (rebuild the provider), against the REAL
// repository and a real database — not a fake.

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_driver_licence_repository.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/driver_licence/domain/driver_licence.dart';
import 'package:hmm_console/features/driver_licence/states/driver_licence_state.dart';

void main() {
  late HmmDatabase db;
  late LocalDriverLicenceRepository repo;

  setUp(() async {
    db = HmmDatabase(NativeDatabase.memory());
    final aid = await db.into(db.authors).insert(
          AuthorsCompanion.insert(accountName: 'licence-roundtrip'),
        );
    final author =
        await (db.select(db.authors)..where((a) => a.id.equals(aid))).getSingle();
    repo = LocalDriverLicenceRepository(
      LocalHmmNoteRepository(db, () async => author),
      LocalNoteCatalogRepository(db),
    );
  });

  tearDown(() async => db.close());

  test('a licence saved through the notifier is there on the next read',
      () async {
    final container = ProviderContainer(overrides: [
      driverLicenceRepositoryModeProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    expect(await container.read(driverLicenceStateProvider.future), isNull);

    await container.read(driverLicenceStateProvider.notifier).save(
          const DriverLicence(
            number: 'D1234-56789',
            licenceClass: 'G',
            jurisdiction: 'Ontario',
          ),
        );

    expect(container.read(driverLicenceStateProvider).hasError, isFalse,
        reason: container.read(driverLicenceStateProvider).error?.toString());

    container.invalidate(driverLicenceStateProvider);
    final reread = await container.read(driverLicenceStateProvider.future);

    expect(reread, isNotNull, reason: 'the licence did not survive a re-read');
    expect(reread!.number, 'D1234-56789');
  });

  test('and it is there when a brand-new repository instance reads it',
      () async {
    await repo.saveLicence(const DriverLicence(number: 'D1'));

    final author = await db.select(db.authors).getSingle();
    final fresh = LocalDriverLicenceRepository(
      LocalHmmNoteRepository(db, () async => author),
      LocalNoteCatalogRepository(db),
    );

    expect((await fresh.getLicence())?.number, 'D1');
  });
}
