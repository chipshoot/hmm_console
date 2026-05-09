import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the automobile ID currently being viewed in any of the
/// insurance / service / scheduled-service screens. Set by each screen
/// in initState so the underlying AsyncNotifiers can reactively load
/// the correct vehicle's data. Mirrors the existing
/// `selectedAutomobileIdProvider` pattern used by the gas_log feature.
class RecordsAutomobileIdNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int? autoId) => state = autoId;
}

final recordsAutomobileIdProvider =
    NotifierProvider<RecordsAutomobileIdNotifier, int?>(
  () => RecordsAutomobileIdNotifier(),
);
