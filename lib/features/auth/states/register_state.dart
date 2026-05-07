import 'package:flutter/services.dart';
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
    state = await AsyncValue.guard(() async {
      final result =
          await ref.watch(registerUserCaseProvider).registerWithEmailPassword(
                username: username,
                email: email,
                password: password,
                confirmPassword: confirmPassword,
              );

      // Commit the autofill context so iCloud Keychain / Google Password
      // Manager prompts to save the new credential. Done only after the
      // API confirms the account; saving a password the server rejected
      // would be misleading.
      TextInput.finishAutofillContext();

      return result;
    });
  }
}

final registerStateProvider = AsyncNotifierProvider<RegisterState, bool>(() {
  return RegisterState();
});
