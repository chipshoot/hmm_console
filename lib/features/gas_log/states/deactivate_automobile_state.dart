import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../states/automobiles_state.dart';
import '../usecases/deactivate_automobile_usecase.dart';

class DeactivateAutomobileState extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<void> deactivate(int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(deactivateAutomobileUseCaseProvider).call(id);
      ref.read(automobilesStateProvider.notifier).refresh();
    });
  }
}

final deactivateAutomobileStateProvider =
    AsyncNotifierProvider<DeactivateAutomobileState, void>(
  () => DeactivateAutomobileState(),
);
