import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/gas_log/data/repositories/automobile_repository.dart';
import '../../features/gas_log/data/repositories/gas_log_api_repository.dart';
import '../../features/gas_log/data/repositories/gas_station_repository.dart';
import '../../features/gas_log/data/repositories/i_gas_log_repository.dart';
import 'data_mode.dart';
import 'local/local_attachment_repository.dart';
import 'local/local_automobile_repository.dart';
import 'local/local_author_repository.dart';
import 'local/local_gas_log_repository.dart';
import 'local/local_gas_station_repository.dart';
import 'local/local_note_catalog_repository.dart';
import 'local/local_note_repository.dart';
import 'local/local_tag_repository.dart';

// Local SQLite is the source of truth for both `local` and `cloudStorage`
// modes. CloudStorage layers a sync engine on top of the same local store; only
// `cloudApi` routes directly at the API repositories.
bool _useLocal(DataMode mode) =>
    mode == DataMode.local || mode == DataMode.cloudStorage;

final noteRepositoryProvider = Provider<INoteRepository>((ref) {
  final mode = ref.watch(dataModeProvider);
  if (_useLocal(mode)) return ref.watch(localNoteRepositoryProvider);
  throw UnimplementedError('API note repository not yet implemented');
});

final authorRepositoryProvider = Provider<IAuthorRepository>((ref) {
  final mode = ref.watch(dataModeProvider);
  if (_useLocal(mode)) return ref.watch(localAuthorRepositoryProvider);
  throw UnimplementedError('API author repository not yet implemented');
});

final tagRepositoryProvider = Provider<ITagRepository>((ref) {
  final mode = ref.watch(dataModeProvider);
  if (_useLocal(mode)) return ref.watch(localTagRepositoryProvider);
  throw UnimplementedError('API tag repository not yet implemented');
});

final noteCatalogRepositoryProvider = Provider<INoteCatalogRepository>((ref) {
  final mode = ref.watch(dataModeProvider);
  if (_useLocal(mode)) return ref.watch(localNoteCatalogRepositoryProvider);
  throw UnimplementedError('API note catalog repository not yet implemented');
});

final attachmentRepositoryProvider = Provider<IAttachmentRepository>((ref) {
  final mode = ref.watch(dataModeProvider);
  if (_useLocal(mode)) return ref.watch(localAttachmentRepositoryProvider);
  throw UnimplementedError('API attachment repository not yet implemented');
});

final gasLogRepositoryModeProvider = Provider<IGasLogRepository>((ref) {
  final mode = ref.watch(dataModeProvider);
  return _useLocal(mode)
      ? ref.watch(localGasLogRepositoryProvider)
      : ref.watch(gasLogRepositoryProvider);
});

final automobileRepositoryModeProvider = Provider<IAutomobileRepository>((ref) {
  final mode = ref.watch(dataModeProvider);
  return _useLocal(mode)
      ? ref.watch(localAutomobileRepositoryProvider)
      : ref.watch(automobileRepositoryProvider);
});

final gasStationRepositoryModeProvider = Provider<IGasStationRepository>((ref) {
  final mode = ref.watch(dataModeProvider);
  return _useLocal(mode)
      ? ref.watch(localGasStationRepositoryProvider)
      : ref.watch(gasStationRepositoryProvider);
});
