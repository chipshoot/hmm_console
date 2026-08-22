import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// Application name shown in MaterialApp title
  ///
  /// In en, this message translates to:
  /// **'Hmm Console'**
  String get appTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageFollowSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get settingsLanguageFollowSystem;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// Always rendered in the native script so Chinese users recognize it regardless of current locale
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get settingsLanguageChinese;

  /// No description provided for @settingsDataStorage.
  ///
  /// In en, this message translates to:
  /// **'Data Storage'**
  String get settingsDataStorage;

  /// No description provided for @settingsStorageMode.
  ///
  /// In en, this message translates to:
  /// **'Storage Mode'**
  String get settingsStorageMode;

  /// No description provided for @settingsCloudProvider.
  ///
  /// In en, this message translates to:
  /// **'Cloud Provider'**
  String get settingsCloudProvider;

  /// No description provided for @settingsSignInOneDrive.
  ///
  /// In en, this message translates to:
  /// **'Sign in to OneDrive'**
  String get settingsSignInOneDrive;

  /// No description provided for @settingsSignOutOneDrive.
  ///
  /// In en, this message translates to:
  /// **'Sign out of OneDrive'**
  String get settingsSignOutOneDrive;

  /// No description provided for @settingsSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get settingsSyncNow;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @settingsLauncher.
  ///
  /// In en, this message translates to:
  /// **'Launcher'**
  String get settingsLauncher;

  /// No description provided for @settingsLauncherSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pin favorites and set search aliases'**
  String get settingsLauncherSubtitle;

  /// No description provided for @settingsGeoCapture.
  ///
  /// In en, this message translates to:
  /// **'Add location to new notes'**
  String get settingsGeoCapture;

  /// No description provided for @settingsGeoCaptureSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Capture your location when you create a note'**
  String get settingsGeoCaptureSubtitle;

  /// No description provided for @settingsQuickPanel.
  ///
  /// In en, this message translates to:
  /// **'Quick access panel'**
  String get settingsQuickPanel;

  /// No description provided for @settingsQuickPanelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Long-press the bottom-right corner for Home & quick Sync'**
  String get settingsQuickPanelSubtitle;

  /// No description provided for @settingsQuickPanelReplay.
  ///
  /// In en, this message translates to:
  /// **'Show me how'**
  String get settingsQuickPanelReplay;

  /// No description provided for @settingsQuickPanelReplaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Replay the quick-access hint'**
  String get settingsQuickPanelReplaySubtitle;

  /// No description provided for @settingsSwitchedToMode.
  ///
  /// In en, this message translates to:
  /// **'Switched to {mode}. Restart app to apply.'**
  String settingsSwitchedToMode(String mode);

  /// Developer-facing build configuration error. The flag name and file path are literal and must not be translated.
  ///
  /// In en, this message translates to:
  /// **'OneDrive client ID not set. Rebuild with --dart-define=ONEDRIVE_CLIENT_ID=<app-id> (see docs/cloud_storage_setup.md §1).'**
  String get settingsOneDriveClientIdMissing;

  /// No description provided for @settingsAuthStateError.
  ///
  /// In en, this message translates to:
  /// **'Auth state error: {error}'**
  String settingsAuthStateError(String error);

  /// No description provided for @settingsDatabaseLocation.
  ///
  /// In en, this message translates to:
  /// **'Database Location'**
  String get settingsDatabaseLocation;

  /// No description provided for @settingsChangeLocation.
  ///
  /// In en, this message translates to:
  /// **'Change Location'**
  String get settingsChangeLocation;

  /// No description provided for @settingsResetToDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get settingsResetToDefault;

  /// No description provided for @settingsChooseDatabaseFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose database folder'**
  String get settingsChooseDatabaseFolder;

  /// No description provided for @settingsDatabaseLocationSet.
  ///
  /// In en, this message translates to:
  /// **'Database location set to {path}. Restart app to apply.'**
  String settingsDatabaseLocationSet(String path);

  /// No description provided for @settingsDatabaseLocationReset.
  ///
  /// In en, this message translates to:
  /// **'Reset to default location. Restart app to apply.'**
  String get settingsDatabaseLocationReset;

  /// No description provided for @settingsGenericError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String settingsGenericError(String error);

  /// No description provided for @settingsChooseVaultFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose vault folder (e.g. inside your OneDrive)'**
  String get settingsChooseVaultFolder;

  /// No description provided for @settingsVaultFolderSet.
  ///
  /// In en, this message translates to:
  /// **'Vault folder set to {path}/vault. New photos will land there.'**
  String settingsVaultFolderSet(String path);

  /// No description provided for @settingsVaultFolderReset.
  ///
  /// In en, this message translates to:
  /// **'Vault folder reset to default (app docs). cloudStorage byte sync will not work until you choose a folder.'**
  String get settingsVaultFolderReset;

  /// No description provided for @settingsVaultFolderLabel.
  ///
  /// In en, this message translates to:
  /// **'Vault folder (for photos)'**
  String get settingsVaultFolderLabel;

  /// No description provided for @settingsVaultFolderHelper.
  ///
  /// In en, this message translates to:
  /// **'Point this inside your OneDrive folder so vehicle photos sync across devices automatically.'**
  String get settingsVaultFolderHelper;

  /// No description provided for @settingsVaultFolderDefault.
  ///
  /// In en, this message translates to:
  /// **'Default (app sandbox — no cross-device sync)'**
  String get settingsVaultFolderDefault;

  /// No description provided for @settingsVaultPathError.
  ///
  /// In en, this message translates to:
  /// **'Vault path error: {error}'**
  String settingsVaultPathError(String error);

  /// No description provided for @settingsChooseFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose Folder'**
  String get settingsChooseFolder;

  /// No description provided for @settingsCleanUpPhotos.
  ///
  /// In en, this message translates to:
  /// **'Clean up unused photos'**
  String get settingsCleanUpPhotos;

  /// No description provided for @settingsCleanUpNone.
  ///
  /// In en, this message translates to:
  /// **'No unused photo files to clean up.'**
  String get settingsCleanUpNone;

  /// No description provided for @settingsCleanUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Clean up unused photos?'**
  String get settingsCleanUpTitle;

  /// No description provided for @settingsCleanUpBody.
  ///
  /// In en, this message translates to:
  /// **'Found {count, plural, =1{1 unused file} other{{count} unused files}} ({size}) left behind by cancelled or replaced photo picks. These are not referenced by any vehicle and can be safely deleted.'**
  String settingsCleanUpBody(int count, String size);

  /// No description provided for @settingsCleanUpDone.
  ///
  /// In en, this message translates to:
  /// **'Reclaimed {count, plural, =1{1 file} other{{count} files}} ({size}).'**
  String settingsCleanUpDone(int count, String size);

  /// No description provided for @settingsCleanUpFailed.
  ///
  /// In en, this message translates to:
  /// **'Clean-up failed: {error}'**
  String settingsCleanUpFailed(String error);

  /// No description provided for @settingsSignedInOneDrive.
  ///
  /// In en, this message translates to:
  /// **'Signed in to OneDrive'**
  String get settingsSignedInOneDrive;

  /// No description provided for @settingsSignInOneDriveFailed.
  ///
  /// In en, this message translates to:
  /// **'OneDrive sign-in failed: {error}'**
  String settingsSignInOneDriveFailed(String error);

  /// No description provided for @settingsSignedOutOneDrive.
  ///
  /// In en, this message translates to:
  /// **'Signed out of OneDrive'**
  String get settingsSignedOutOneDrive;

  /// No description provided for @settingsSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get settingsSyncing;

  /// No description provided for @settingsSyncSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Synced — pushed {pushed} / pulled {pulled} notes'**
  String settingsSyncSucceeded(int pushed, int pulled);

  /// No description provided for @settingsSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed: {error}'**
  String settingsSyncFailed(String error);

  /// No description provided for @settingsSyncOver.
  ///
  /// In en, this message translates to:
  /// **'Sync over'**
  String get settingsSyncOver;

  /// No description provided for @settingsSyncWifiOnly.
  ///
  /// In en, this message translates to:
  /// **'WiFi only'**
  String get settingsSyncWifiOnly;

  /// No description provided for @settingsSyncWifiOnlySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-sync waits for WiFi. Manual \"Sync now\" asks first when you\'re on cellular.'**
  String get settingsSyncWifiOnlySubtitle;

  /// No description provided for @settingsSyncAnyNetwork.
  ///
  /// In en, this message translates to:
  /// **'Any network'**
  String get settingsSyncAnyNetwork;

  /// No description provided for @settingsSyncAnyNetworkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-sync may use cellular data. You pay for any overage.'**
  String get settingsSyncAnyNetworkSubtitle;

  /// No description provided for @settingsVehicleInformation.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Information'**
  String get settingsVehicleInformation;

  /// No description provided for @settingsShowRegistration.
  ///
  /// In en, this message translates to:
  /// **'Show Registration card'**
  String get settingsShowRegistration;

  /// No description provided for @settingsShowRegistrationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Turn off if your jurisdiction no longer requires periodic vehicle-registration renewal (e.g. Ontario retired the renewal sticker in 2022).'**
  String get settingsShowRegistrationSubtitle;

  /// No description provided for @settingsGasLogDefaults.
  ///
  /// In en, this message translates to:
  /// **'Gas Log Defaults'**
  String get settingsGasLogDefaults;

  /// No description provided for @settingsDistanceUnit.
  ///
  /// In en, this message translates to:
  /// **'Distance Unit'**
  String get settingsDistanceUnit;

  /// No description provided for @settingsFuelUnit.
  ///
  /// In en, this message translates to:
  /// **'Fuel Unit'**
  String get settingsFuelUnit;

  /// No description provided for @settingsCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get settingsCurrency;

  /// No description provided for @unitMile.
  ///
  /// In en, this message translates to:
  /// **'Mile'**
  String get unitMile;

  /// Display name only. The persisted/API value stays the literal 'Kilometer' in DistanceUnit.apiValue and must never be translated.
  ///
  /// In en, this message translates to:
  /// **'Kilometer'**
  String get unitKilometer;

  /// No description provided for @unitGallon.
  ///
  /// In en, this message translates to:
  /// **'Gallon'**
  String get unitGallon;

  /// No description provided for @unitLiter.
  ///
  /// In en, this message translates to:
  /// **'Liter'**
  String get unitLiter;

  /// No description provided for @dataModeLocal.
  ///
  /// In en, this message translates to:
  /// **'Local (Offline)'**
  String get dataModeLocal;

  /// No description provided for @dataModeLocalDescription.
  ///
  /// In en, this message translates to:
  /// **'Your data stays on this device. No sync, no account needed.'**
  String get dataModeLocalDescription;

  /// No description provided for @dataModeCloudStorage.
  ///
  /// In en, this message translates to:
  /// **'Cloud Storage'**
  String get dataModeCloudStorage;

  /// No description provided for @dataModeCloudStorageDescription.
  ///
  /// In en, this message translates to:
  /// **'Data is stored locally and synced to your personal cloud account (OneDrive).'**
  String get dataModeCloudStorageDescription;

  /// No description provided for @dataModeCloudApi.
  ///
  /// In en, this message translates to:
  /// **'Cloud (API)'**
  String get dataModeCloudApi;

  /// No description provided for @dataModeCloudApiDescription.
  ///
  /// In en, this message translates to:
  /// **'Data is stored locally and synced with the Hmm backend API.'**
  String get dataModeCloudApiDescription;

  /// No description provided for @vaultSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Secure Vault'**
  String get vaultSectionTitle;

  /// No description provided for @vaultSetUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up Secure Vault'**
  String get vaultSetUpTitle;

  /// No description provided for @vaultSetUpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Encrypt sensitive attachments (e.g. registration, VIN photos) with a passphrase'**
  String get vaultSetUpSubtitle;

  /// No description provided for @vaultLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Secure Vault — locked'**
  String get vaultLockedTitle;

  /// No description provided for @vaultLockedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock to view or add sensitive attachments'**
  String get vaultLockedSubtitle;

  /// No description provided for @vaultUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get vaultUnlock;

  /// No description provided for @vaultOnTitle.
  ///
  /// In en, this message translates to:
  /// **'Secure Vault — on'**
  String get vaultOnTitle;

  /// No description provided for @vaultOnSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sensitive attachments are unlocked on this device'**
  String get vaultOnSubtitle;

  /// No description provided for @vaultLockNow.
  ///
  /// In en, this message translates to:
  /// **'Lock now'**
  String get vaultLockNow;

  /// No description provided for @vaultNeedsResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Secure Vault — needs reset'**
  String get vaultNeedsResetTitle;

  /// No description provided for @vaultNeedsResetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The vault configuration could not be read and must be reset'**
  String get vaultNeedsResetSubtitle;

  /// No description provided for @vaultResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Secure Vault'**
  String get vaultResetTitle;

  /// No description provided for @vaultResetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot your passphrase? Reset erases the vault'**
  String get vaultResetSubtitle;

  /// No description provided for @vaultIncorrectPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Incorrect passphrase.'**
  String get vaultIncorrectPassphrase;

  /// No description provided for @vaultPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Passphrase'**
  String get vaultPassphrase;

  /// No description provided for @vaultConfirmPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Confirm passphrase'**
  String get vaultConfirmPassphrase;

  /// No description provided for @vaultForgotWarning.
  ///
  /// In en, this message translates to:
  /// **'If you forget this passphrase, these files cannot be recovered.'**
  String get vaultForgotWarning;

  /// No description provided for @vaultPassphrasesDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passphrases do not match.'**
  String get vaultPassphrasesDoNotMatch;

  /// No description provided for @vaultSetUpAction.
  ///
  /// In en, this message translates to:
  /// **'Set Up'**
  String get vaultSetUpAction;

  /// No description provided for @vaultUnlockDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock Secure Vault'**
  String get vaultUnlockDialogTitle;

  /// {token} is the literal word the user must type. It stays untranslated in every locale so the typed value matches on any keyboard.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes every file in the Secure Vault. This can\'t be undone. Type {token} to confirm.'**
  String vaultResetWarning(String token);

  /// No description provided for @vaultResetTypeToken.
  ///
  /// In en, this message translates to:
  /// **'Type {token}'**
  String vaultResetTypeToken(String token);

  /// No description provided for @syncStatusSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing now…'**
  String get syncStatusSyncing;

  /// No description provided for @syncStatusFailing.
  ///
  /// In en, this message translates to:
  /// **'Sync failing — last {count} attempts'**
  String syncStatusFailing(int count);

  /// No description provided for @syncStatusWaitingWifi.
  ///
  /// In en, this message translates to:
  /// **'Waiting for WiFi to sync'**
  String get syncStatusWaitingWifi;

  /// No description provided for @syncStatusLastFailed.
  ///
  /// In en, this message translates to:
  /// **'Last sync failed'**
  String get syncStatusLastFailed;

  /// {when} is a relative time such as 'just now' or '5 minutes ago'
  ///
  /// In en, this message translates to:
  /// **'Synced {when}'**
  String syncStatusSynced(String when);

  /// No description provided for @syncStatusNever.
  ///
  /// In en, this message translates to:
  /// **'Not synced yet'**
  String get syncStatusNever;

  /// No description provided for @syncRelativeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get syncRelativeJustNow;

  /// No description provided for @syncRelativeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute ago} other{{count} minutes ago}}'**
  String syncRelativeMinutes(int count);

  /// No description provided for @syncRelativeHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String syncRelativeHours(int count);

  /// No description provided for @syncRelativeDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String syncRelativeDays(int count);

  /// No description provided for @syncCellularTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync over cellular?'**
  String get syncCellularTitle;

  /// No description provided for @syncCellularBody.
  ///
  /// In en, this message translates to:
  /// **'Your network policy is set to \"WiFi only\", but you tapped Sync now. Proceeding will use cellular data.'**
  String get syncCellularBody;

  /// No description provided for @syncAnyway.
  ///
  /// In en, this message translates to:
  /// **'Sync anyway'**
  String get syncAnyway;

  /// No description provided for @automobileRecordsInsurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get automobileRecordsInsurance;

  /// No description provided for @automobileRecordsServiceHistory.
  ///
  /// In en, this message translates to:
  /// **'Service history'**
  String get automobileRecordsServiceHistory;

  /// No description provided for @automobileRecordsScheduledService.
  ///
  /// In en, this message translates to:
  /// **'Scheduled service'**
  String get automobileRecordsScheduledService;

  /// No description provided for @automobileRecordsManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get automobileRecordsManage;

  /// No description provided for @automobileRecordsViewHistory.
  ///
  /// In en, this message translates to:
  /// **'View history'**
  String get automobileRecordsViewHistory;

  /// No description provided for @automobileRecordsNoActivePolicy.
  ///
  /// In en, this message translates to:
  /// **'No active policy on file'**
  String get automobileRecordsNoActivePolicy;

  /// No description provided for @automobileRecordsNoServiceRecords.
  ///
  /// In en, this message translates to:
  /// **'No service records yet'**
  String get automobileRecordsNoServiceRecords;

  /// No description provided for @automobileRecordsNoSchedules.
  ///
  /// In en, this message translates to:
  /// **'No schedules set up'**
  String get automobileRecordsNoSchedules;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
