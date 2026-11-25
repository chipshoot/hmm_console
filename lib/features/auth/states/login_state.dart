import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/features/auth/providers/current_user_provider.dart';
import 'package:hmm_console/features/auth/usecases/login_usecase.dart';

class LoginState extends AsyncNotifier<bool> {
  @override
  bool build() => false;

  Future<void> loginWithEmailPassword(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = await ref
          .watch(loginUserCaseProvider)
          .loginWithEmailPassword(email: email, password: password);
      ref.read(currentUserProvider.notifier).setUser(user);

      // Tell the OS the autofill context is complete so iCloud Keychain /
      // Google Password Manager prompts to save the credential. Without
      // this iOS in particular never shows the "Save Password?" sheet.
      TextInput.finishAutofillContext();

      return true;
    });
  }
}

final loginStateProvider = AsyncNotifierProvider<LoginState, bool>(() {
  return LoginState();
});
