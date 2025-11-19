import 'package:hmm_console/features/auth/data/interfaces/auth_interface.dart';

abstract interface class RegisterUseCase {
  Future<bool> registerWithEmailPassword({
    required String email,
    required String password,
  });
}

class _RegisterUserCase implements RegisterUseCase {
  _RegisterUserCase(this.authRepository);

  final AuthRepository authRepository;

  @override
  Future<bool> registerWithEmailPassword({
    required String email,
    required String password,
  }) async {
    return authRepository
        .registerWithEmailPassword(email: email, password: password)
        .then((value) => value != null);
  }
}
