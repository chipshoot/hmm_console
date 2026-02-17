import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/core/network/idp_token_service.dart';
import 'package:hmm_console/core/network/token_storage.dart';
import 'package:hmm_console/features/auth/data/interfaces/auth_interface.dart';
import 'package:hmm_console/features/auth/data/models/current_user.dart';

class _AuthRemoteDataSource implements AuthRepository {
  _AuthRemoteDataSource(this._idpTokenService, this._tokenStorage);

  final IdpTokenService _idpTokenService;
  final TokenStorage _tokenStorage;
  final StreamController<bool> _authStateController =
      StreamController<bool>.broadcast();

  @override
  Future<CurrentUserDataModel> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final claims = await _idpTokenService.authorize(email, password);
    _authStateController.add(true);

    return CurrentUserDataModel(
      uid: claims['sub'] as String? ?? '',
      email: claims['email'] as String?,
      displayName: claims['name'] as String?,
      photoUrl: claims['picture'] as String?,
    );
  }

  @override
  Future<CurrentUserDataModel> registerWithEmailPassword({
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    final result = await _idpTokenService.register(
      username: username,
      email: email,
      password: password,
      confirmPassword: confirmPassword,
    );

    return CurrentUserDataModel(
      uid: result['userId'] as String? ?? '',
      email: result['email'] as String?,
      displayName: result['username'] as String?,
    );
  }

  @override
  Future<void> signOut() async {
    await _idpTokenService.clearTokens();
    _authStateController.add(false);
  }

  @override
  Stream<bool> isUserAuthenticated() async* {
    yield await _tokenStorage.hasValidToken();
    yield* _authStateController.stream;
  }
}

final authRemoteDataSource = Provider<_AuthRemoteDataSource>(
  (ref) => _AuthRemoteDataSource(
    ref.watch(idpTokenServiceProvider),
    ref.watch(tokenStorageProvider),
  ),
);
