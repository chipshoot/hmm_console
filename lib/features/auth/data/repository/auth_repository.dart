import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/features/auth/data/data/auth_data_source.dart';
import 'package:hmm_console/features/auth/data/interfaces/auth_interface.dart';
import 'package:hmm_console/features/auth/data/models/current_user.dart';

class _AuthRepository implements AuthRepository {
  _AuthRepository(this.authDataSource);

  final AuthRepository authDataSource;

  @override
  Future<CurrentUserDataModel> loginWithEmailPassword({
    required String email,
    required String password,
  }) {
    return authDataSource.loginWithEmailPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<CurrentUserDataModel> registerWithEmailPassword({
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
  }) {
    return authDataSource.registerWithEmailPassword(
      username: username,
      email: email,
      password: password,
      confirmPassword: confirmPassword,
    );
  }

  @override
  Future<void> signOut() async {
    return authDataSource.signOut();
  }

  @override
  Stream<bool> isUserAuthenticated() {
    return authDataSource.isUserAuthenticated();
  }
}

final authRepositoryProvider = Provider<_AuthRepository>(
  (ref) => _AuthRepository(ref.watch(authRemoteDataSource)),
);
