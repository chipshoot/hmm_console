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

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String commonError(String error);

  /// No description provided for @gasLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Gas Logs'**
  String get gasLogTitle;

  /// No description provided for @gasLogLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load gas logs'**
  String get gasLogLoadFailed;

  /// No description provided for @gasLogEmpty.
  ///
  /// In en, this message translates to:
  /// **'No gas logs yet'**
  String get gasLogEmpty;

  /// No description provided for @gasLogLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load More'**
  String get gasLogLoadMore;

  /// No description provided for @gasLogDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Gas Log'**
  String get gasLogDeleteTitle;

  /// No description provided for @gasLogDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this gas log?'**
  String get gasLogDeleteBody;

  /// No description provided for @gasLogDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String gasLogDeleteFailed(String error);

  /// No description provided for @gasLogCreated.
  ///
  /// In en, this message translates to:
  /// **'Gas log created'**
  String get gasLogCreated;

  /// No description provided for @gasLogUpdated.
  ///
  /// In en, this message translates to:
  /// **'Gas log updated'**
  String get gasLogUpdated;

  /// {unit} is a unit symbol like mi or km — never translated, it comes from DistanceUnit.label
  ///
  /// In en, this message translates to:
  /// **'Odometer ({unit})'**
  String gasLogOdometer(String unit);

  /// No description provided for @gasLogDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance ({unit})'**
  String gasLogDistance(String unit);

  /// No description provided for @gasLogFuel.
  ///
  /// In en, this message translates to:
  /// **'Fuel ({unit})'**
  String gasLogFuel(String unit);

  /// No description provided for @gasLogUnitPrice.
  ///
  /// In en, this message translates to:
  /// **'Unit Price ({currency}/{unit})'**
  String gasLogUnitPrice(String currency, String unit);

  /// No description provided for @gasLogTotalPrice.
  ///
  /// In en, this message translates to:
  /// **'Total Price ({currency})'**
  String gasLogTotalPrice(String currency);

  /// No description provided for @gasLogFullTank.
  ///
  /// In en, this message translates to:
  /// **'Full Tank'**
  String get gasLogFullTank;

  /// No description provided for @gasLogComment.
  ///
  /// In en, this message translates to:
  /// **'Comment (optional)'**
  String get gasLogComment;

  /// No description provided for @gasLogSelectStation.
  ///
  /// In en, this message translates to:
  /// **'Please select or enter a gas station'**
  String get gasLogSelectStation;

  /// No description provided for @vehicleNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New Vehicle'**
  String get vehicleNewTitle;

  /// No description provided for @vehicleCreated.
  ///
  /// In en, this message translates to:
  /// **'Vehicle created'**
  String get vehicleCreated;

  /// No description provided for @vehicleUpdated.
  ///
  /// In en, this message translates to:
  /// **'Vehicle updated'**
  String get vehicleUpdated;

  /// No description provided for @vehicleNotFound.
  ///
  /// In en, this message translates to:
  /// **'Vehicle not found'**
  String get vehicleNotFound;

  /// No description provided for @vehicleInformation.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Information'**
  String get vehicleInformation;

  /// No description provided for @vehicleManageTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage Vehicles'**
  String get vehicleManageTitle;

  /// No description provided for @vehicleSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Vehicle'**
  String get vehicleSelectTitle;

  /// No description provided for @vehicleManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get vehicleManage;

  /// No description provided for @vehicleManageVehicles.
  ///
  /// In en, this message translates to:
  /// **'Manage Vehicles'**
  String get vehicleManageVehicles;

  /// No description provided for @vehicleLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load vehicles'**
  String get vehicleLoadFailed;

  /// No description provided for @vehicleEmpty.
  ///
  /// In en, this message translates to:
  /// **'No vehicles yet'**
  String get vehicleEmpty;

  /// No description provided for @vehicleEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add your first vehicle.'**
  String get vehicleEmptyHint;

  /// No description provided for @vehicleNoneFound.
  ///
  /// In en, this message translates to:
  /// **'No vehicles found'**
  String get vehicleNoneFound;

  /// No description provided for @vehicleNoneFoundHint.
  ///
  /// In en, this message translates to:
  /// **'Add a vehicle to get started.'**
  String get vehicleNoneFoundHint;

  /// No description provided for @vehicleStatusUpdated.
  ///
  /// In en, this message translates to:
  /// **'Vehicle status updated'**
  String get vehicleStatusUpdated;

  /// No description provided for @vehicleActiveCount.
  ///
  /// In en, this message translates to:
  /// **'Active ({count})'**
  String vehicleActiveCount(int count);

  /// No description provided for @vehicleInactiveCount.
  ///
  /// In en, this message translates to:
  /// **'Inactive ({count})'**
  String vehicleInactiveCount(int count);

  /// No description provided for @vehicleVin.
  ///
  /// In en, this message translates to:
  /// **'VIN (17 characters)'**
  String get vehicleVin;

  /// No description provided for @vehicleMaker.
  ///
  /// In en, this message translates to:
  /// **'Maker'**
  String get vehicleMaker;

  /// No description provided for @vehicleBrand.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get vehicleBrand;

  /// No description provided for @vehicleModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get vehicleModel;

  /// No description provided for @vehicleTrim.
  ///
  /// In en, this message translates to:
  /// **'Trim (optional)'**
  String get vehicleTrim;

  /// No description provided for @vehicleYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get vehicleYear;

  /// No description provided for @vehicleColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get vehicleColor;

  /// No description provided for @vehicleColorOptional.
  ///
  /// In en, this message translates to:
  /// **'Color (optional)'**
  String get vehicleColorOptional;

  /// No description provided for @vehiclePlate.
  ///
  /// In en, this message translates to:
  /// **'Plate'**
  String get vehiclePlate;

  /// No description provided for @vehicleTankCapacity.
  ///
  /// In en, this message translates to:
  /// **'Tank Capacity (optional)'**
  String get vehicleTankCapacity;

  /// No description provided for @vehicleCityMpg.
  ///
  /// In en, this message translates to:
  /// **'City MPG'**
  String get vehicleCityMpg;

  /// No description provided for @vehicleHwyMpg.
  ///
  /// In en, this message translates to:
  /// **'Hwy MPG'**
  String get vehicleHwyMpg;

  /// No description provided for @vehicleCombinedMpg.
  ///
  /// In en, this message translates to:
  /// **'Combined'**
  String get vehicleCombinedMpg;

  /// No description provided for @vehicleMeterReading.
  ///
  /// In en, this message translates to:
  /// **'Meter Reading ({unit})'**
  String vehicleMeterReading(String unit);

  /// No description provided for @vehiclePurchasePrice.
  ///
  /// In en, this message translates to:
  /// **'Purchase Price ({currency})'**
  String vehiclePurchasePrice(String currency);

  /// No description provided for @vehicleNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get vehicleNotes;

  /// No description provided for @vehicleNotesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get vehicleNotesOptional;

  /// No description provided for @vehicleMileage.
  ///
  /// In en, this message translates to:
  /// **'Mileage'**
  String get vehicleMileage;

  /// No description provided for @vehicleRegistration.
  ///
  /// In en, this message translates to:
  /// **'Registration'**
  String get vehicleRegistration;

  /// No description provided for @vehicleRegistrationExpiry.
  ///
  /// In en, this message translates to:
  /// **'Registration Expiry'**
  String get vehicleRegistrationExpiry;

  /// No description provided for @vehicleInvalidMeterReading.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid meter reading'**
  String get vehicleInvalidMeterReading;

  /// No description provided for @vehiclePhotoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Photo unavailable'**
  String get vehiclePhotoUnavailable;

  /// No description provided for @vehiclePhotoPickFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not pick photo: {error}'**
  String vehiclePhotoPickFailed(String error);

  /// No description provided for @vehicleEditIdentityTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit vehicle identity?'**
  String get vehicleEditIdentityTitle;

  /// {action} is a localized verb such as Deactivate or Reactivate
  ///
  /// In en, this message translates to:
  /// **'{action} vehicle?'**
  String vehicleActionConfirm(String action);

  /// No description provided for @vehicleDeactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get vehicleDeactivate;

  /// No description provided for @vehicleReactivate.
  ///
  /// In en, this message translates to:
  /// **'Reactivate'**
  String get vehicleReactivate;

  /// No description provided for @vehicleDeactivateTitle.
  ///
  /// In en, this message translates to:
  /// **'Deactivate vehicle?'**
  String get vehicleDeactivateTitle;

  /// No description provided for @vehicleReactivateTitle.
  ///
  /// In en, this message translates to:
  /// **'Reactivate vehicle?'**
  String get vehicleReactivateTitle;

  /// Whole sentences per action rather than interpolating a verb — a verb slotted into a sentence does not survive translation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to deactivate {vehicle}?'**
  String vehicleDeactivateBody(String vehicle);

  /// No description provided for @vehicleReactivateBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reactivate {vehicle}?'**
  String vehicleReactivateBody(String vehicle);

  /// No description provided for @stationDeactivateBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to deactivate \"{station}\"?'**
  String stationDeactivateBody(String station);

  /// No description provided for @stationReactivateBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reactivate \"{station}\"?'**
  String stationReactivateBody(String station);

  /// No description provided for @stationDeactivateTitle.
  ///
  /// In en, this message translates to:
  /// **'Deactivate station?'**
  String get stationDeactivateTitle;

  /// No description provided for @stationReactivateTitle.
  ///
  /// In en, this message translates to:
  /// **'Reactivate station?'**
  String get stationReactivateTitle;

  /// No description provided for @stationTitle.
  ///
  /// In en, this message translates to:
  /// **'Gas Stations'**
  String get stationTitle;

  /// No description provided for @stationLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load gas stations'**
  String get stationLoadFailed;

  /// No description provided for @stationEmpty.
  ///
  /// In en, this message translates to:
  /// **'No gas stations yet'**
  String get stationEmpty;

  /// No description provided for @stationEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add your first gas station.'**
  String get stationEmptyHint;

  /// No description provided for @stationActionConfirm.
  ///
  /// In en, this message translates to:
  /// **'{action} station?'**
  String stationActionConfirm(String action);

  /// No description provided for @stationName.
  ///
  /// In en, this message translates to:
  /// **'Station Name'**
  String get stationName;

  /// No description provided for @stationHintCreate.
  ///
  /// In en, this message translates to:
  /// **'Type to create new station'**
  String get stationHintCreate;

  /// No description provided for @stationHintSelect.
  ///
  /// In en, this message translates to:
  /// **'Select or type new station'**
  String get stationHintSelect;

  /// No description provided for @stationNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Station Name *'**
  String get stationNameRequired;

  /// No description provided for @stationAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get stationAddress;

  /// No description provided for @stationCityRequired.
  ///
  /// In en, this message translates to:
  /// **'City *'**
  String get stationCityRequired;

  /// No description provided for @stationStateProvince.
  ///
  /// In en, this message translates to:
  /// **'State/Province'**
  String get stationStateProvince;

  /// No description provided for @stationCountryRequired.
  ///
  /// In en, this message translates to:
  /// **'Country *'**
  String get stationCountryRequired;

  /// No description provided for @stationPostalCode.
  ///
  /// In en, this message translates to:
  /// **'Zip/Postal Code'**
  String get stationPostalCode;

  /// No description provided for @stationDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get stationDescription;

  /// No description provided for @stationCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create station: {error}'**
  String stationCreateFailed(String error);

  /// No description provided for @stationUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update station: {error}'**
  String stationUpdateFailed(String error);

  /// No description provided for @stationLocationCaptured.
  ///
  /// In en, this message translates to:
  /// **'Location and address captured'**
  String get stationLocationCaptured;

  /// No description provided for @stationLocationNoAddress.
  ///
  /// In en, this message translates to:
  /// **'Location captured (address lookup unavailable)'**
  String get stationLocationNoAddress;

  /// No description provided for @stationLocationDenied.
  ///
  /// In en, this message translates to:
  /// **'Could not get location. Check permissions.'**
  String get stationLocationDenied;

  /// No description provided for @stationLocationError.
  ///
  /// In en, this message translates to:
  /// **'Location error: {error}'**
  String stationLocationError(String error);

  /// No description provided for @stationSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to {action} station: {error}'**
  String stationSaveFailed(String action, String error);

  /// No description provided for @sectionIdentity.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get sectionIdentity;

  /// No description provided for @sectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get sectionAppearance;

  /// No description provided for @sectionEngine.
  ///
  /// In en, this message translates to:
  /// **'Engine'**
  String get sectionEngine;

  /// No description provided for @sectionOwnership.
  ///
  /// In en, this message translates to:
  /// **'Ownership'**
  String get sectionOwnership;

  /// No description provided for @sectionNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get sectionNotes;

  /// No description provided for @sectionChangeHistory.
  ///
  /// In en, this message translates to:
  /// **'Change history'**
  String get sectionChangeHistory;

  /// No description provided for @fieldDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get fieldDate;

  /// No description provided for @fuelTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Fuel Type'**
  String get fuelTypeLabel;

  /// No description provided for @fuelGradeLabel.
  ///
  /// In en, this message translates to:
  /// **'Fuel Grade'**
  String get fuelGradeLabel;

  /// No description provided for @engineTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Engine Type'**
  String get engineTypeLabel;

  /// No description provided for @ownershipStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Ownership Status'**
  String get ownershipStatusLabel;

  /// No description provided for @optionRegular.
  ///
  /// In en, this message translates to:
  /// **'Regular'**
  String get optionRegular;

  /// No description provided for @optionMidGrade.
  ///
  /// In en, this message translates to:
  /// **'Mid-Grade'**
  String get optionMidGrade;

  /// No description provided for @optionPremium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get optionPremium;

  /// No description provided for @optionDiesel.
  ///
  /// In en, this message translates to:
  /// **'Diesel'**
  String get optionDiesel;

  /// No description provided for @optionE85.
  ///
  /// In en, this message translates to:
  /// **'E85'**
  String get optionE85;

  /// No description provided for @optionElectric.
  ///
  /// In en, this message translates to:
  /// **'Electric'**
  String get optionElectric;

  /// No description provided for @optionOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get optionOther;

  /// No description provided for @optionGasoline.
  ///
  /// In en, this message translates to:
  /// **'Gasoline'**
  String get optionGasoline;

  /// No description provided for @optionHybrid.
  ///
  /// In en, this message translates to:
  /// **'Hybrid'**
  String get optionHybrid;

  /// No description provided for @optionPlugInHybrid.
  ///
  /// In en, this message translates to:
  /// **'Plug-in Hybrid'**
  String get optionPlugInHybrid;

  /// No description provided for @optionHydrogen.
  ///
  /// In en, this message translates to:
  /// **'Hydrogen'**
  String get optionHydrogen;

  /// No description provided for @optionCng.
  ///
  /// In en, this message translates to:
  /// **'CNG'**
  String get optionCng;

  /// No description provided for @optionOwned.
  ///
  /// In en, this message translates to:
  /// **'Owned'**
  String get optionOwned;

  /// No description provided for @optionFinanced.
  ///
  /// In en, this message translates to:
  /// **'Financed'**
  String get optionFinanced;

  /// No description provided for @optionLeased.
  ///
  /// In en, this message translates to:
  /// **'Leased'**
  String get optionLeased;

  /// No description provided for @optionCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get optionCompany;

  /// No description provided for @validationVinRequired.
  ///
  /// In en, this message translates to:
  /// **'VIN is required'**
  String get validationVinRequired;

  /// No description provided for @validationVinLength.
  ///
  /// In en, this message translates to:
  /// **'VIN must be exactly 17 characters'**
  String get validationVinLength;

  /// No description provided for @validationMakerRequired.
  ///
  /// In en, this message translates to:
  /// **'Maker is required'**
  String get validationMakerRequired;

  /// No description provided for @validationMakerTooLong.
  ///
  /// In en, this message translates to:
  /// **'Maker must be 50 characters or less'**
  String get validationMakerTooLong;

  /// No description provided for @validationBrandRequired.
  ///
  /// In en, this message translates to:
  /// **'Brand is required'**
  String get validationBrandRequired;

  /// No description provided for @validationBrandTooLong.
  ///
  /// In en, this message translates to:
  /// **'Brand must be 50 characters or less'**
  String get validationBrandTooLong;

  /// No description provided for @validationModelRequired.
  ///
  /// In en, this message translates to:
  /// **'Model is required'**
  String get validationModelRequired;

  /// No description provided for @validationModelTooLong.
  ///
  /// In en, this message translates to:
  /// **'Model must be 50 characters or less'**
  String get validationModelTooLong;

  /// No description provided for @validationPlateRequired.
  ///
  /// In en, this message translates to:
  /// **'Plate is required'**
  String get validationPlateRequired;

  /// No description provided for @validationPlateTooLong.
  ///
  /// In en, this message translates to:
  /// **'Plate must be 20 characters or less'**
  String get validationPlateTooLong;

  /// No description provided for @validationYearRequired.
  ///
  /// In en, this message translates to:
  /// **'Year is required'**
  String get validationYearRequired;

  /// No description provided for @validationYearRange.
  ///
  /// In en, this message translates to:
  /// **'Enter a year between {min} and {max}'**
  String validationYearRange(int min, int max);

  /// No description provided for @validationOdometerRequired.
  ///
  /// In en, this message translates to:
  /// **'Odometer is required'**
  String get validationOdometerRequired;

  /// No description provided for @validationOdometerInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid odometer reading'**
  String get validationOdometerInvalid;

  /// No description provided for @validationFuelRequired.
  ///
  /// In en, this message translates to:
  /// **'Fuel amount is required'**
  String get validationFuelRequired;

  /// No description provided for @validationFuelInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid fuel amount'**
  String get validationFuelInvalid;

  /// No description provided for @validationPriceRequired.
  ///
  /// In en, this message translates to:
  /// **'Price is required'**
  String get validationPriceRequired;

  /// No description provided for @validationPriceInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid price'**
  String get validationPriceInvalid;

  /// No description provided for @validationDistanceInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid distance'**
  String get validationDistanceInvalid;

  /// No description provided for @validationOdometerBelowCurrent.
  ///
  /// In en, this message translates to:
  /// **'Odometer cannot be less than current reading ({current})'**
  String validationOdometerBelowCurrent(String current);

  /// No description provided for @validationOdometerLargeGap.
  ///
  /// In en, this message translates to:
  /// **'Large gap: odometer is {gap} from expected ({expected})'**
  String validationOdometerLargeGap(String gap, String expected);

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
