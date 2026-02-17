import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/features/auth/data/data.dart';

abstract interface class LoginUseCase {
  Future<CurrentUserDataModel> loginWithEmailPassword({
    required String email,
    required String password,
  });
}

class _LoginUseCase implements LoginUseCase {
  _LoginUseCase(this._authRepository);

  final AuthRepository _authRepository;

  @override
  Future<CurrentUserDataModel> loginWithEmailPassword({
    required String email,
    required String password,
  }) {
    return _authRepository.loginWithEmailPassword(
      email: email,
      password: password,
    );
  }
}

final loginUserCaseProvider = Provider<_LoginUseCase>(
  (ref) => _LoginUseCase(
    ref.watch(authRepositoryProvider),
  ),
);
