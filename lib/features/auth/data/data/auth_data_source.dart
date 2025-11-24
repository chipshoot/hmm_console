import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hmm_console/core/exceptions/app_exceptions.dart';
import 'package:hmm_console/features/auth/data/interfaces/auth_interface.dart';
import 'package:hmm_console/features/auth/data/models/current_user.dart';

class _AuthRemoteDataSource implements AuthRepository {
  _AuthRemoteDataSource(this.firebaseAuth);

  final FirebaseAuth firebaseAuth;

  @override
  Future<CurrentUserDataModel> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential = await firebaseAuth
          .signInWithEmailAndPassword(email: email, password: password);

      return CurrentUserDataModel(
        uid: userCredential.user!.uid,
        email: userCredential.user!.email,
        displayName: userCredential.user!.displayName,
      );
    } on FirebaseAuthException catch (e) {
      throw AppFirebaseException(
        e.code,
        e.message ?? 'An error occurred during login',
      );
    } catch (e) {
      throw e.toString();
    }
  }

  @override
  Future<CurrentUserDataModel> registerWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential = await firebaseAuth
          .createUserWithEmailAndPassword(email: email, password: password);

      return CurrentUserDataModel(
        uid: userCredential.user!.uid,
        email: userCredential.user!.email,
        displayName: userCredential.user!.displayName,
      );
    } on FirebaseAuthException catch (e) {
      throw AppFirebaseException(
        e.code,
        e.message ?? 'An error occurred during registration',
      );
    } catch (e) {
      throw e.toString();
    }
  }

  @override
  Future<CurrentUserDataModel> loginWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        throw AppFirebaseException(
          'google_sign_in_cancelled',
          'Google sign-in was cancelled by user',
        );
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await firebaseAuth
          .signInWithCredential(credential);

      return CurrentUserDataModel(
        uid: userCredential.user!.uid,
        email: userCredential.user!.email,
        displayName: userCredential.user!.displayName,
      );
    } on FirebaseAuthException catch (e) {
      throw AppFirebaseException(
        e.code,
        e.message ?? 'An error occurred during Google sign-in',
      );
    } catch (e) {
      throw e.toString();
    }
  }

  @override
  Future<void> signOut() async {
    await firebaseAuth.signOut();
  }

  @override
  Stream<bool> isUserAuthenticated() {
    return firebaseAuth.authStateChanges().map((user) => user != null);
  }
}

final authRemoteDataSource = Provider<_AuthRemoteDataSource>(
  (ref) => _AuthRemoteDataSource(FirebaseAuth.instance),
);
