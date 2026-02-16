import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/automobile.dart';
import '../states/automobiles_state.dart';
import '../usecases/create_automobile_usecase.dart';

class CreateAutomobileState extends AsyncNotifier<Automobile?> {
  @override
  Automobile? build() => null;

  Future<void> create(Automobile automobile) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final created =
          await ref.read(createAutomobileUseCaseProvider).call(automobile);
      ref.read(automobilesStateProvider.notifier).refresh();
      return created;
    });
  }
}

final createAutomobileStateProvider =
    AsyncNotifierProvider<CreateAutomobileState, Automobile?>(
  () => CreateAutomobileState(),
);
