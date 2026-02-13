import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/core/network/idp_token_service.dart';
import 'package:hmm_console/features/auth/data/data.dart';

abstract interface class SignOutUseCase {
  Future<void> signOut();
}

class _SignOutUseCase implements SignOutUseCase {
  _SignOutUseCase(this._authRepository, this._idpTokenService);

  final AuthRepository _authRepository;
  final IdpTokenService _idpTokenService;

  @override
  Future<void> signOut() async {
    await _idpTokenService.clearTokens();
    await _authRepository.signOut();
  }
}

final signOutUseCaseProvider = Provider<_SignOutUseCase>(
  (ref) => _SignOutUseCase(
    ref.watch(authRepositoryProvider),
    ref.watch(idpTokenServiceProvider),
  ),
);
