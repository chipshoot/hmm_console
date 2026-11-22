import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/data_mode.dart';
import '../../../core/data/local/local_hmm_note_repository.dart';
import '../../../core/data/local/local_note_catalog_repository.dart';
import '../contract/glucose_errors.dart';
import '../contract/i_glucose_repository.dart';
import '../data/local_glucose_repository.dart';

final localGlucoseRepositoryProvider = Provider<IGlucoseRepository>((ref) {
  return LocalGlucoseRepository(
    ref.watch(localHmmNoteRepositoryProvider),
    ref.watch(localNoteCatalogRepositoryProvider),
  );
});

/// local and cloudStorage use the local store; cloudApi throws
/// [GlucoseCloudApiUnavailable] (no fallback).
final glucoseRepositoryProvider = Provider<IGlucoseRepository>((ref) {
  final mode = ref.watch(dataModeProvider);
  if (mode == DataMode.cloudApi) throw GlucoseCloudApiUnavailable();
  return ref.watch(localGlucoseRepositoryProvider);
});
