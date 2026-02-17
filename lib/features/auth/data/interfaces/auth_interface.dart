import 'package:hmm_console/features/auth/data/models/current_user.dart';

abstract interface class AuthRepository {
  Future<CurrentUserDataModel> loginWithEmailPassword({
    required String email,
    required String password,
  });
  Future<CurrentUserDataModel> registerWithEmailPassword({
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
  });
  Future<void> signOut();
  Stream<bool> isUserAuthenticated();
}
