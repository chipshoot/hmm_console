import 'package:hmm_console/features/auth/data/models/current_user.dart';

abstract interface class AuthRepository {
  Future<CurrentUserDataModel> registerWithEmailPassword({
    required String email,
    required String password,
  });
}
