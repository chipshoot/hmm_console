import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/gas_log/data/repositories/automobile_repository.dart';
import '../../features/gas_log/data/repositories/gas_log_api_repository.dart';
import '../../features/gas_log/data/repositories/gas_station_repository.dart';
import '../../features/gas_log/data/repositories/i_gas_log_repository.dart';
import 'data_mode.dart';
import 'local/local_automobile_repository.dart';
import 'local/local_author_repository.dart';
import 'local/local_gas_log_repository.dart';
import 'local/local_gas_station_repository.dart';
import 'local/local_note_catalog_repository.dart';
import 'local/local_note_repository.dart';
import 'local/local_tag_repository.dart';

final noteRepositoryProvider = Provider<INoteRepository>((ref) {
  final mode = ref.watch(dataModeProvider);
  if (mode == DataMode.local) {
    return ref.watch(localNoteRepositoryProvider);
  }
  throw UnimplementedError('API note repository not yet implemented');
});

final authorRepositoryProvider = Provider<IAuthorRepository>((ref) {
  final mode = ref.watch(dataModeProvider);
  if (mode == DataMode.local) {
    return ref.watch(localAuthorRepositoryProvider);
  }
  throw UnimplementedError('API author repository not yet implemented');
});

final tagRepositoryProvider = Provider<ITagRepository>((ref) {
  final mode = ref.watch(dataModeProvider);
  if (mode == DataMode.local) {
    return ref.watch(localTagRepositoryProvider);
  }
  throw UnimplementedError('API tag repository not yet implemented');
});

final noteCatalogRepositoryProvider = Provider<INoteCatalogRepository>((ref) {
  final mode = ref.watch(dataModeProvider);
  if (mode == DataMode.local) {
    return ref.watch(localNoteCatalogRepositoryProvider);
  }
  throw UnimplementedError('API note catalog repository not yet implemented');
});

final gasLogRepositoryModeProvider = Provider<IGasLogRepository>((ref) {
  final mode = ref.watch(dataModeProvider);
  if (mode == DataMode.local) {
    return ref.watch(localGasLogRepositoryProvider);
  }
  return ref.watch(gasLogRepositoryProvider);
});

final automobileRepositoryModeProvider = Provider<IAutomobileRepository>((ref) {
  final mode = ref.watch(dataModeProvider);
  if (mode == DataMode.local) {
    return ref.watch(localAutomobileRepositoryProvider);
  }
  return ref.watch(automobileRepositoryProvider);
});

final gasStationRepositoryModeProvider = Provider<IGasStationRepository>((ref) {
  final mode = ref.watch(dataModeProvider);
  if (mode == DataMode.local) {
    return ref.watch(localGasStationRepositoryProvider);
  }
  return ref.watch(gasStationRepositoryProvider);
});
