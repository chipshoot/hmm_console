import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thin wrapper around the OneDrive OAuth flow. Real implementation lands with
/// `flutter_appauth` + `flutter_secure_storage`; for now this is a stub so the
/// sync engine skeleton compiles.
///
/// Registration instructions: `docs/cloud_storage_setup.md` §1.
class OneDriveAuth {
  const OneDriveAuth();

  Future<bool> hasToken() async => false;

  Future<void> signIn() async {
    throw UnimplementedError(
      'OneDrive OAuth is not yet wired. Register the app in Entra ID per '
      'docs/cloud_storage_setup.md §1, then add flutter_appauth + '
      'flutter_secure_storage and implement this method.',
    );
  }

  Future<void> signOut() async {
    throw UnimplementedError('OneDrive sign-out not yet wired.');
  }

  /// Returns a fresh access token (auto-refreshing when needed).
  Future<String?> getAccessToken() async => null;
}

final oneDriveAuthProvider =
    Provider<OneDriveAuth>((ref) => const OneDriveAuth());
