import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/features/auth/data/data.dart';

abstract interface class SignOutUseCase {
  Future<void> signOut();
}

class _SignOutUseCase implements SignOutUseCase {
  _SignOutUseCase(this.authRepository);

  final AuthRepository authRepository;

  @override
  Future<void> signOut() async {
    return authRepository.signOut();
  }
}

final signOutUseCaseProvider = Provider<_SignOutUseCase>(
  (ref) => _SignOutUseCase(ref.watch(authRepositoryProvider)),
);
