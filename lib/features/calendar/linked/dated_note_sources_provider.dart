import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/repository_providers.dart';
import '../../automobile_records/data/automobile_dated_source.dart';
import '../../driver_licence/data/licence_dated_source.dart';
import '../contract/dated_note.dart';

/// Every subsystem that supplies dates to the linked-dates matcher. Each
/// subsystem adds its source here.
final datedNoteSourcesProvider = Provider<List<DatedNoteSource>>(
  (ref) => [
    // Read lazily: the repository provider throws in Cloud API mode.
    LicenceDatedSource(() => ref.read(driverLicenceRepositoryModeProvider)),
    AutomobileDatedSource(
      automobiles: () => ref.read(automobileRepositoryModeProvider),
      insurance: () => ref.read(insuranceRepositoryModeProvider),
      schedules: () => ref.read(scheduledServiceRepositoryModeProvider),
      notes: () => ref.read(hmmNoteRepositoryProvider),
    ),
  ],
);
