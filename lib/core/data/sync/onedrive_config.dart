/// Configuration for the OneDrive OAuth flow. Values are read from
/// `--dart-define` so the client ID can differ per build (dev / prod) without
/// being committed to the repo.
///
/// Registration steps: `docs/cloud_storage_setup.md` §1.
///
/// Example build command:
/// ```
/// flutter run --dart-define=ONEDRIVE_CLIENT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
/// ```
class OneDriveConfig {
  const OneDriveConfig._();

  /// Entra ID / Azure AD app registration "Application (client) ID".
  ///
  /// Safe to commit: public-client IDs for OAuth/PKCE flows are not secrets
  /// (Microsoft docs confirm). Override per-build with
  /// `--dart-define=ONEDRIVE_CLIENT_ID=<id>` if you ever need a separate
  /// dev/staging app registration.
  static const String clientId = String.fromEnvironment(
    'ONEDRIVE_CLIENT_ID',
    defaultValue: '3056e225-6965-4c36-8542-db02f614e084',
  );

  /// OpenID Connect discovery endpoint for consumer + work Microsoft accounts.
  static const String discoveryUrl =
      'https://login.microsoftonline.com/common/v2.0/.well-known/openid-configuration';

  /// Custom URL scheme registered in Info.plist / AndroidManifest.
  /// Must match `docs/cloud_storage_setup.md` §1.2.
  static const String redirectUri = 'com.homemademessage.hmm://auth';

  static const List<String> scopes = [
    'Files.ReadWrite.AppFolder',
    'User.Read',
    'offline_access',
  ];

  static bool get isConfigured => clientId.isNotEmpty;
}
