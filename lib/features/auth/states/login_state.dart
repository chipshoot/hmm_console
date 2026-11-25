import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/core/auth/owner_id.dart';
import 'package:hmm_console/features/auth/providers/current_user_provider.dart';
import 'package:hmm_console/features/auth/usecases/login_usecase.dart';
import 'package:hmm_console/features/auth/usecases/signout_usecase.dart';

/// Thrown when a different Hmm account signs in on a device already linked
/// to another one. The new session has been signed out again.
class OtherHmmAccountException implements Exception {
  const OtherHmmAccountException(this.linkedAccount);
  final String linkedAccount;

  @override
  String toString() => 'OtherHmmAccountException($linkedAccount)';
}

class LoginState extends AsyncNotifier<bool> {
  @override
  bool build() => false;

  Future<void> loginWithEmailPassword(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = await ref
          .watch(loginUserCaseProvider)
          .loginWithEmailPassword(email: email, password: password);

      final store = await ref.read(ownerIdStoreProvider.future);
      final linked = store.linkedHmmSub;
      if (linked == null) {
        await store.setLink(user.uid, user.email);
      } else if (linked != user.uid) {
        await ref.read(signOutUseCaseProvider).signOut();
        throw OtherHmmAccountException(store.linkedHmmEmail ?? '\u2014');
      }
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
