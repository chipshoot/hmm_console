import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/data_mode.dart';
import '../../../core/data/local/local_hmm_note_repository.dart';
import '../../../core/data/local/local_note_catalog_repository.dart';
import '../contract/activity_errors.dart';
import '../contract/i_activity_repository.dart';
import '../data/local_activity_repository.dart';

final localActivityRepositoryProvider = Provider<IActivityRepository>((ref) {
  return LocalActivityRepository(
    ref.watch(localHmmNoteRepositoryProvider),
    ref.watch(localNoteCatalogRepositoryProvider),
  );
});

/// local and cloudStorage use the local store; cloudApi throws
/// [ActivityCloudApiUnavailable] (no fallback).
final activityRepositoryProvider = Provider<IActivityRepository>((ref) {
  final mode = ref.watch(dataModeProvider);
  if (mode == DataMode.cloudApi) throw ActivityCloudApiUnavailable();
  return ref.watch(localActivityRepositoryProvider);
});
