import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/features/auth/usecases/register_usecase.dart';

class RegisterState extends AsyncNotifier<bool> {
  @override
  bool build() => false;

  Future<void> registerWithEmailPassword(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() {
      return ref
          .watch(registerUserCaseProvider)
          .registerWithEmailPassword(email: email, password: password);
    });
  }
}

final registerStateProvider = AsyncNotifierProvider<RegisterState, bool>(() {
  return RegisterState();
});
