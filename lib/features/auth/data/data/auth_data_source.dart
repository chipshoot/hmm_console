import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/features/auth/data/interfaces/auth_interface.dart';
import 'package:hmm_console/features/auth/data/models/current_user.dart';

class _AuthRemoteDataSource implements AuthRepository {
  _AuthRemoteDataSource(this.firebaseAuth);

  final FirebaseAuth firebaseAuth;

  @override
  Future<CurrentUserDataModel> registerWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final UserCredential userCredential = await firebaseAuth
        .createUserWithEmailAndPassword(email: email, password: password);

    return CurrentUserDataModel(
      uid: userCredential.user!.uid,
      email: userCredential.user!.email,
      displayName: userCredential.user!.displayName,
    );
  }
}

final authRemoteDataSource = Provider<_AuthRemoteDataSource>(
  (ref) => _AuthRemoteDataSource(FirebaseAuth.instance),
);
