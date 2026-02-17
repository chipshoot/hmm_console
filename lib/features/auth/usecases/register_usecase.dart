import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/features/auth/data/data.dart';

abstract interface class RegisterUseCase {
  Future<bool> registerWithEmailPassword({
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
  });
}

class _RegisterUseCase implements RegisterUseCase {
  _RegisterUseCase(this.authRepository);

  final AuthRepository authRepository;

  @override
  Future<bool> registerWithEmailPassword({
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    await authRepository.registerWithEmailPassword(
      username: username,
      email: email,
      password: password,
      confirmPassword: confirmPassword,
    );
    return true;
  }
}

final registerUserCaseProvider = Provider<_RegisterUseCase>(
  (ref) => _RegisterUseCase(ref.watch(authRepositoryProvider)),
);
