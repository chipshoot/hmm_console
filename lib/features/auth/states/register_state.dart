import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/features/auth/usecases/register_usecase.dart';

class RegisterState extends AsyncNotifier<bool> {
  @override
  bool build() => false;

  Future<void> registerWithEmailPassword(
    String username,
    String email,
    String password,
    String confirmPassword,
  ) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() {
      return ref.watch(registerUserCaseProvider).registerWithEmailPassword(
            username: username,
            email: email,
            password: password,
            confirmPassword: confirmPassword,
          );
    });
  }
}

final registerStateProvider = AsyncNotifierProvider<RegisterState, bool>(() {
  return RegisterState();
});
