import 'package:hmm_console/features/auth/data/models/current_user.dart';

abstract interface class AuthRepository {
  Future<CurrentUserDataModel> loginWithEmailPassword({
    required String email,
    required String password,
  });
  Future<CurrentUserDataModel> registerWithEmailPassword({
    required String email,
    required String password,
  });
  Future<CurrentUserDataModel> loginWithGoogle();
  Future<void> signOut();
  Stream<bool> isUserAuthenticated();
}
