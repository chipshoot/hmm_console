import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/features/auth/data/data.dart';

abstract class AuthStateUseCase {
  Stream<bool> isUserAuthenticated();
}

class _RegisterUseCase implements AuthStateUseCase {
  _RegisterUseCase(this._authRepository);

  final AuthRepository _authRepository;

  @override
  isUserAuthenticated() {
    return _authRepository.isUserAuthenticated();
  }
}

final authStateUseCaseProvider = Provider<AuthStateUseCase>(
  (ref) => _RegisterUseCase(ref.watch(authRepositoryProvider)),
);
