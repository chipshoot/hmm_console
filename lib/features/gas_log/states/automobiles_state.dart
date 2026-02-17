import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/automobile.dart';
import '../usecases/get_automobiles_usecase.dart';

class AutomobilesState extends AsyncNotifier<List<Automobile>> {
  @override
  Future<List<Automobile>> build() {
    return ref.watch(getAutomobilesUseCaseProvider).call();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(getAutomobilesUseCaseProvider).call(),
    );
  }
}

final automobilesStateProvider =
    AsyncNotifierProvider<AutomobilesState, List<Automobile>>(
  () => AutomobilesState(),
);
