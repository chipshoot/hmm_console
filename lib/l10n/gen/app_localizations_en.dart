// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Hmm Console';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageFollowSystem => 'Follow system';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageChinese => '中文';

  @override
  String get settingsDataStorage => 'Data Storage';

  @override
  String get settingsStorageMode => 'Storage Mode';

  @override
  String get settingsCloudProvider => 'Cloud Provider';

  @override
  String get settingsSignInOneDrive => 'Sign in to OneDrive';

  @override
  String get settingsSignOutOneDrive => 'Sign out of OneDrive';

  @override
  String get settingsSyncNow => 'Sync now';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get settingsLauncher => 'Launcher';

  @override
  String get settingsLauncherSubtitle => 'Pin favorites and set search aliases';

  @override
  String get settingsGeoCapture => 'Add location to new notes';

  @override
  String get settingsGeoCaptureSubtitle =>
      'Capture your location when you create a note';

  @override
  String get settingsQuickPanel => 'Quick access panel';

  @override
  String get settingsQuickPanelSubtitle =>
      'Long-press the bottom-right corner for Home & quick Sync';

  @override
  String get settingsQuickPanelReplay => 'Show me how';

  @override
  String get settingsQuickPanelReplaySubtitle => 'Replay the quick-access hint';

  @override
  String settingsSwitchedToMode(String mode) {
    return 'Switched to $mode. Restart app to apply.';
  }

  @override
  String get settingsOneDriveClientIdMissing =>
      'OneDrive client ID not set. Rebuild with --dart-define=ONEDRIVE_CLIENT_ID=<app-id> (see docs/cloud_storage_setup.md §1).';

  @override
  String settingsAuthStateError(String error) {
    return 'Auth state error: $error';
  }

  @override
  String get settingsDatabaseLocation => 'Database Location';

  @override
  String get settingsChangeLocation => 'Change Location';

  @override
  String get settingsResetToDefault => 'Reset to Default';

  @override
  String get settingsChooseDatabaseFolder => 'Choose database folder';

  @override
  String settingsDatabaseLocationSet(String path) {
    return 'Database location set to $path. Restart app to apply.';
  }

  @override
  String get settingsDatabaseLocationReset =>
      'Reset to default location. Restart app to apply.';

  @override
  String settingsGenericError(String error) {
    return 'Error: $error';
  }

  @override
  String get settingsChooseVaultFolder =>
      'Choose vault folder (e.g. inside your OneDrive)';

  @override
  String settingsVaultFolderSet(String path) {
    return 'Vault folder set to $path/vault. New photos will land there.';
  }

  @override
  String get settingsVaultFolderReset =>
      'Vault folder reset to default (app docs). cloudStorage byte sync will not work until you choose a folder.';

  @override
  String get settingsVaultFolderLabel => 'Vault folder (for photos)';

  @override
  String get settingsVaultFolderHelper =>
      'Point this inside your OneDrive folder so vehicle photos sync across devices automatically.';

  @override
  String get settingsVaultFolderDefault =>
      'Default (app sandbox — no cross-device sync)';

  @override
  String settingsVaultPathError(String error) {
    return 'Vault path error: $error';
  }

  @override
  String get settingsChooseFolder => 'Choose Folder';

  @override
  String get settingsCleanUpPhotos => 'Clean up unused photos';

  @override
  String get settingsCleanUpNone => 'No unused photo files to clean up.';

  @override
  String get settingsCleanUpTitle => 'Clean up unused photos?';

  @override
  String settingsCleanUpBody(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unused files',
      one: '1 unused file',
    );
    return 'Found $_temp0 ($size) left behind by cancelled or replaced photo picks. These are not referenced by any vehicle and can be safely deleted.';
  }

  @override
  String settingsCleanUpDone(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return 'Reclaimed $_temp0 ($size).';
  }

  @override
  String settingsCleanUpFailed(String error) {
    return 'Clean-up failed: $error';
  }

  @override
  String get settingsSignedInOneDrive => 'Signed in to OneDrive';

  @override
  String settingsSignInOneDriveFailed(String error) {
    return 'OneDrive sign-in failed: $error';
  }

  @override
  String get settingsSignedOutOneDrive => 'Signed out of OneDrive';

  @override
  String get settingsSyncing => 'Syncing…';

  @override
  String settingsSyncSucceeded(int pushed, int pulled) {
    return 'Synced — pushed $pushed / pulled $pulled notes';
  }

  @override
  String settingsSyncFailed(String error) {
    return 'Sync failed: $error';
  }

  @override
  String get settingsSyncOver => 'Sync over';

  @override
  String get settingsSyncWifiOnly => 'WiFi only';

  @override
  String get settingsSyncWifiOnlySubtitle =>
      'Auto-sync waits for WiFi. Manual \"Sync now\" asks first when you\'re on cellular.';

  @override
  String get settingsSyncAnyNetwork => 'Any network';

  @override
  String get settingsSyncAnyNetworkSubtitle =>
      'Auto-sync may use cellular data. You pay for any overage.';

  @override
  String get settingsVehicleInformation => 'Vehicle Information';

  @override
  String get settingsShowRegistration => 'Show Registration card';

  @override
  String get settingsShowRegistrationSubtitle =>
      'Turn off if your jurisdiction no longer requires periodic vehicle-registration renewal (e.g. Ontario retired the renewal sticker in 2022).';

  @override
  String get settingsGasLogDefaults => 'Gas Log Defaults';

  @override
  String get settingsDistanceUnit => 'Distance Unit';

  @override
  String get settingsFuelUnit => 'Fuel Unit';

  @override
  String get settingsCurrency => 'Currency';

  @override
  String get unitMile => 'Mile';

  @override
  String get unitKilometer => 'Kilometer';

  @override
  String get unitGallon => 'Gallon';

  @override
  String get unitLiter => 'Liter';

  @override
  String get dataModeLocal => 'Local (Offline)';

  @override
  String get dataModeLocalDescription =>
      'Your data stays on this device. No sync, no account needed.';

  @override
  String get dataModeCloudStorage => 'Cloud Storage';

  @override
  String get dataModeCloudStorageDescription =>
      'Data is stored locally and synced to your personal cloud account (OneDrive).';

  @override
  String get dataModeCloudApi => 'Cloud (API)';

  @override
  String get dataModeCloudApiDescription =>
      'Data is stored locally and synced with the Hmm backend API.';

  @override
  String get vaultSectionTitle => 'Secure Vault';

  @override
  String get vaultSetUpTitle => 'Set up Secure Vault';

  @override
  String get vaultSetUpSubtitle =>
      'Encrypt sensitive attachments (e.g. registration, VIN photos) with a passphrase';

  @override
  String get vaultLockedTitle => 'Secure Vault — locked';

  @override
  String get vaultLockedSubtitle =>
      'Unlock to view or add sensitive attachments';

  @override
  String get vaultUnlock => 'Unlock';

  @override
  String get vaultOnTitle => 'Secure Vault — on';

  @override
  String get vaultOnSubtitle =>
      'Sensitive attachments are unlocked on this device';

  @override
  String get vaultLockNow => 'Lock now';

  @override
  String get vaultNeedsResetTitle => 'Secure Vault — needs reset';

  @override
  String get vaultNeedsResetSubtitle =>
      'The vault configuration could not be read and must be reset';

  @override
  String get vaultResetTitle => 'Reset Secure Vault';

  @override
  String get vaultResetSubtitle =>
      'Forgot your passphrase? Reset erases the vault';

  @override
  String get vaultIncorrectPassphrase => 'Incorrect passphrase.';

  @override
  String get vaultPassphrase => 'Passphrase';

  @override
  String get vaultConfirmPassphrase => 'Confirm passphrase';

  @override
  String get vaultForgotWarning =>
      'If you forget this passphrase, these files cannot be recovered.';

  @override
  String get vaultPassphrasesDoNotMatch => 'Passphrases do not match.';

  @override
  String get vaultSetUpAction => 'Set Up';

  @override
  String get vaultUnlockDialogTitle => 'Unlock Secure Vault';

  @override
  String vaultResetWarning(String token) {
    return 'This permanently deletes every file in the Secure Vault. This can\'t be undone. Type $token to confirm.';
  }

  @override
  String vaultResetTypeToken(String token) {
    return 'Type $token';
  }

  @override
  String get syncStatusSyncing => 'Syncing now…';

  @override
  String syncStatusFailing(int count) {
    return 'Sync failing — last $count attempts';
  }

  @override
  String get syncStatusWaitingWifi => 'Waiting for WiFi to sync';

  @override
  String get syncStatusLastFailed => 'Last sync failed';

  @override
  String syncStatusSynced(String when) {
    return 'Synced $when';
  }

  @override
  String get syncStatusNever => 'Not synced yet';

  @override
  String get syncRelativeJustNow => 'just now';

  @override
  String syncRelativeMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String syncRelativeHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String syncRelativeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get syncCellularTitle => 'Sync over cellular?';

  @override
  String get syncCellularBody =>
      'Your network policy is set to \"WiFi only\", but you tapped Sync now. Proceeding will use cellular data.';

  @override
  String get syncAnyway => 'Sync anyway';

  @override
  String get automobileRecordsInsurance => 'Insurance';

  @override
  String get automobileRecordsServiceHistory => 'Service history';

  @override
  String get automobileRecordsScheduledService => 'Scheduled service';

  @override
  String get automobileRecordsManage => 'Manage';

  @override
  String get automobileRecordsViewHistory => 'View history';

  @override
  String get automobileRecordsNoActivePolicy => 'No active policy on file';

  @override
  String get automobileRecordsNoServiceRecords => 'No service records yet';

  @override
  String get automobileRecordsNoSchedules => 'No schedules set up';
}
