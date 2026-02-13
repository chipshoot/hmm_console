import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/core/network/idp_token_service.dart';
import 'package:hmm_console/features/auth/data/data.dart';

abstract interface class LoginUseCase {
  Future<bool> loginWithEmailPassword({
    required String email,
    required String password,
  });

  Future<bool> loginWithGoogle();
}

class _LoginUseCase implements LoginUseCase {
  _LoginUseCase(this._authRepository, this._idpTokenService);

  final AuthRepository _authRepository;
  final IdpTokenService _idpTokenService;

  @override
  Future<bool> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    await _authRepository.loginWithEmailPassword(
      email: email,
      password: password,
    );

    await _idpTokenService.authorize(email, password);
    return true;
  }

  @override
  Future<bool> loginWithGoogle() async {
    // TODO: Google flow needs a separate IDP strategy (token exchange)
    await _authRepository.loginWithGoogle();
    return true;
  }
}

final loginUserCaseProvider = Provider<_LoginUseCase>(
  (ref) => _LoginUseCase(
    ref.watch(authRepositoryProvider),
    ref.watch(idpTokenServiceProvider),
  ),
);
