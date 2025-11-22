import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/features/auth/data/data.dart';

abstract interface class RegisterUseCase {
  Future<bool> registerWithEmailPassword({
    required String email,
    required String password,
  });
}

class _RegisterUseCase implements RegisterUseCase {
  _RegisterUseCase(this.authRepository);

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

final registerUserCaseProvider = Provider<_RegisterUseCase>(
  (ref) => _RegisterUseCase(ref.watch(authRepositoryProvider)),
);
