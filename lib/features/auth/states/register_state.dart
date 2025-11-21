import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/domain/usercases/register_usercase.dart';

final registerStateProvider = AsyncNotifierProvider<RegisterState, bool>(() {
  return RegisterState();
});

class RegisterState extends AsyncNotifier<bool> {
  get _registerUserCase => ref.read(registerUserCaseProvider);

  @override
  bool build() => false;

  registerWithEmailPassword(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final isRegistered = await _registerUserCase.registerWithEmailPassword(
        email: email,
        password: password,
      );
      return isRegistered;
    });
  }
}
