import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/features/auth/data/data.dart';

abstract interface class LoginUseCase {
  Future<CurrentUserDataModel> loginWithEmailPassword({
    required String email,
    required String password,
    Future<void> Function(CurrentUserDataModel user)? beforeAccept,
  });
}

class _LoginUseCase implements LoginUseCase {
  _LoginUseCase(this._authRepository);

  final AuthRepository _authRepository;

  @override
  Future<CurrentUserDataModel> loginWithEmailPassword({
    required String email,
    required String password,
    Future<void> Function(CurrentUserDataModel user)? beforeAccept,
  }) {
    return _authRepository.loginWithEmailPassword(
      email: email,
      password: password,
      beforeAccept: beforeAccept,
    );
  }
}

final loginUserCaseProvider = Provider<_LoginUseCase>(
  (ref) => _LoginUseCase(ref.watch(authRepositoryProvider)),
);
