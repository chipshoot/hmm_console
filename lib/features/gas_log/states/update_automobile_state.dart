import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/automobile.dart';
import '../states/automobiles_state.dart';
import '../usecases/update_automobile_usecase.dart';

class UpdateAutomobileState extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<void> updateAutomobile(int id, Automobile automobile) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(updateAutomobileUseCaseProvider).call(id, automobile);
      ref.read(automobilesStateProvider.notifier).refresh();
    });
  }
}

final updateAutomobileStateProvider =
    AsyncNotifierProvider<UpdateAutomobileState, void>(
  () => UpdateAutomobileState(),
);
