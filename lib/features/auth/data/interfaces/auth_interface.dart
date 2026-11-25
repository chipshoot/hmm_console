import 'package:hmm_console/features/auth/data/models/current_user.dart';

abstract interface class AuthRepository {
  /// [beforeAccept] sees the signed-in user before any token is stored or the
  /// auth state emits; throwing from it refuses the login.
  Future<CurrentUserDataModel> loginWithEmailPassword({
    required String email,
    required String password,
    Future<void> Function(CurrentUserDataModel user)? beforeAccept,
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
