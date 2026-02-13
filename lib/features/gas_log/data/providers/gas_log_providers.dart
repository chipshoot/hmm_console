import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/gas_log_hive_repository.dart';
import '../repositories/i_gas_log_repository.dart';

final gasLogRepositoryProvider = Provider<IGasLogRepository>(
  (ref) => GasLogHiveRepository(),
);
