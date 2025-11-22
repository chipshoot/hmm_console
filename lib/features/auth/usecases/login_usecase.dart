import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/features/auth/data/data.dart';

abstract interface class LoginUseCase {
  Future<bool> loginWithEmailPassword({
    required String email,
    required String password,
  });
}

class _LoginUseCase implements LoginUseCase {
  _LoginUseCase(this._authRepository);

  final AuthRepository _authRepository;

  @override
  Future<bool> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    return _authRepository
        .loginWithEmailPassword(email: email, password: password)
        .then((value) => value != null);
  }
}

final loginUserCaseProvider = Provider<_LoginUseCase>(
  (ref) => _LoginUseCase(ref.watch(authRepositoryProvider)),
);
