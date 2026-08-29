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

  /// No description provided for @catalogGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get catalogGeneral;

  /// No description provided for @catalogGasLog.
  ///
  /// In en, this message translates to:
  /// **'Gas Log'**
  String get catalogGasLog;

  /// No description provided for @catalogAutomobile.
  ///
  /// In en, this message translates to:
  /// **'Automobile'**
  String get catalogAutomobile;

  /// No description provided for @catalogInsurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get catalogInsurance;

  /// No description provided for @catalogScheduledService.
  ///
  /// In en, this message translates to:
  /// **'Scheduled Service'**
  String get catalogScheduledService;

  /// No description provided for @catalogServiceRecord.
  ///
  /// In en, this message translates to:
  /// **'Service Record'**
  String get catalogServiceRecord;

  /// No description provided for @catalogNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get catalogNote;

  /// No description provided for @domainAutomobile.
  ///
  /// In en, this message translates to:
  /// **'Automobile'**
  String get domainAutomobile;

  /// No description provided for @domainGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get domainGeneral;

  /// No description provided for @domainOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get domainOther;

  /// No description provided for @notesTitle.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesTitle;

  /// No description provided for @notesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search subjects'**
  String get notesSearchHint;

  /// No description provided for @notesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load notes: {error}'**
  String notesLoadFailed(String error);

  /// No description provided for @notesFilter.
  ///
  /// In en, this message translates to:
  /// **'FILTER'**
  String get notesFilter;

  /// No description provided for @notesAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get notesAll;

  /// No description provided for @notesAllNotes.
  ///
  /// In en, this message translates to:
  /// **'All notes'**
  String get notesAllNotes;

  /// No description provided for @notesAllInDomain.
  ///
  /// In en, this message translates to:
  /// **'All {domain}'**
  String notesAllInDomain(String domain);

  /// No description provided for @notesNoteCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 note} other{{count} notes}}'**
  String notesNoteCount(int count);

  /// No description provided for @notesSelectNote.
  ///
  /// In en, this message translates to:
  /// **'Select a note'**
  String get notesSelectNote;

  /// No description provided for @notesNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get notesNone;

  /// No description provided for @notesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notes yet'**
  String get notesEmpty;

  /// No description provided for @notesNoUnattached.
  ///
  /// In en, this message translates to:
  /// **'No unattached notes'**
  String get notesNoUnattached;

  /// No description provided for @notesNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No notes'**
  String get notesNoMatches;

  /// No description provided for @notesSearchNotes.
  ///
  /// In en, this message translates to:
  /// **'Search notes'**
  String get notesSearchNotes;

  /// No description provided for @notesLinkedUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Linked note unavailable'**
  String get notesLinkedUnavailable;

  /// No description provided for @notesGenericFailure.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String notesGenericFailure(String error);

  /// No description provided for @notesSubjectRequired.
  ///
  /// In en, this message translates to:
  /// **'Subject is required'**
  String get notesSubjectRequired;

  /// No description provided for @notesTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get notesTitleHint;

  /// No description provided for @notesBodyHint.
  ///
  /// In en, this message translates to:
  /// **'Start writing…'**
  String get notesBodyHint;

  /// No description provided for @notesDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get notesDone;

  /// No description provided for @notesRemoveStoredImagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove stored images?'**
  String get notesRemoveStoredImagesTitle;

  /// No description provided for @notesKeepAttached.
  ///
  /// In en, this message translates to:
  /// **'Keep attached'**
  String get notesKeepAttached;

  /// No description provided for @notesEditAction.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get notesEditAction;

  /// No description provided for @notesViewRaw.
  ///
  /// In en, this message translates to:
  /// **'View raw content'**
  String get notesViewRaw;

  /// No description provided for @notesRawContentTitle.
  ///
  /// In en, this message translates to:
  /// **'Raw content'**
  String get notesRawContentTitle;

  /// No description provided for @notesSubsystemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Subsystems'**
  String get notesSubsystemsTitle;

  /// Display label for the Automobile subsystem anchor. The anchor note's stored SUBJECT stays the English literal 'Automobile' (see features/notes/data/subsystem_anchor.dart) — only this label is translated.
  ///
  /// In en, this message translates to:
  /// **'Automobile'**
  String get notesSubsystemAutomobile;

  /// No description provided for @notesRecordMicPermission.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission needed to record'**
  String get notesRecordMicPermission;

  /// No description provided for @notesRecordStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start recording'**
  String get notesRecordStartFailed;

  /// No description provided for @notesRecordTooLong.
  ///
  /// In en, this message translates to:
  /// **'Recording is too long; please record a shorter one'**
  String get notesRecordTooLong;

  /// No description provided for @notesRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording…  {time}'**
  String notesRecording(String time);

  /// No description provided for @notesRecordStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get notesRecordStop;

  /// No description provided for @notesVaultSetUpPrompt.
  ///
  /// In en, this message translates to:
  /// **'Set up Secure Vault in Settings to view this image.'**
  String get notesVaultSetUpPrompt;

  /// No description provided for @cheatsheetWalletTitle.
  ///
  /// In en, this message translates to:
  /// **'Cheatsheets'**
  String get cheatsheetWalletTitle;

  /// No description provided for @cheatsheetNew.
  ///
  /// In en, this message translates to:
  /// **'New cheatsheet'**
  String get cheatsheetNew;

  /// No description provided for @cheatsheetLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load your cheatsheets.\n{error}'**
  String cheatsheetLoadFailed(String error);

  /// No description provided for @cheatsheetEmpty.
  ///
  /// In en, this message translates to:
  /// **'No cheatsheets yet. Tap + to make one.'**
  String get cheatsheetEmpty;

  /// No description provided for @cheatsheetSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search cheatsheets'**
  String get cheatsheetSearchHint;

  /// No description provided for @cheatsheetNoMatches.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches that search.'**
  String get cheatsheetNoMatches;

  /// No description provided for @cheatsheetGone.
  ///
  /// In en, this message translates to:
  /// **'That cheatsheet no longer exists.'**
  String get cheatsheetGone;

  /// No description provided for @cheatsheetSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save this cheatsheet: {error}'**
  String cheatsheetSaveFailed(String error);

  /// No description provided for @cheatsheetDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete this cheatsheet: {error}'**
  String cheatsheetDeleteFailed(String error);

  /// No description provided for @cheatsheetDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this cheatsheet?'**
  String get cheatsheetDeleteTitle;

  /// No description provided for @cheatsheetEditTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit cheatsheet'**
  String get cheatsheetEditTooltip;

  /// No description provided for @cheatsheetDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete cheatsheet'**
  String get cheatsheetDeleteTooltip;

  /// No description provided for @cheatsheetOpenSource.
  ///
  /// In en, this message translates to:
  /// **'Open source'**
  String get cheatsheetOpenSource;

  /// No description provided for @cheatsheetOpenSourceTooltip.
  ///
  /// In en, this message translates to:
  /// **'Open the source note'**
  String get cheatsheetOpenSourceTooltip;

  /// No description provided for @cheatsheetOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open that.'**
  String get cheatsheetOpenFailed;

  /// No description provided for @cheatsheetTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get cheatsheetTitleLabel;

  /// No description provided for @cheatsheetWalletGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Wallet group'**
  String get cheatsheetWalletGroupLabel;

  /// No description provided for @cheatsheetNewRow.
  ///
  /// In en, this message translates to:
  /// **'New row'**
  String get cheatsheetNewRow;

  /// No description provided for @cheatsheetAddRow.
  ///
  /// In en, this message translates to:
  /// **'Add row'**
  String get cheatsheetAddRow;

  /// No description provided for @cheatsheetRemoveRow.
  ///
  /// In en, this message translates to:
  /// **'Remove this row'**
  String get cheatsheetRemoveRow;

  /// No description provided for @cheatsheetSourceLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load notes: {error}'**
  String cheatsheetSourceLoadFailed(String error);

  /// No description provided for @cheatsheetSourceEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notes to reference yet.'**
  String get cheatsheetSourceEmpty;

  /// No description provided for @cheatsheetSourceNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No notes match that search.'**
  String get cheatsheetSourceNoMatches;

  /// No description provided for @cheatsheetSourceBack.
  ///
  /// In en, this message translates to:
  /// **'Back to the note list'**
  String get cheatsheetSourceBack;

  /// No description provided for @cheatsheetWholeNote.
  ///
  /// In en, this message translates to:
  /// **'The whole note'**
  String get cheatsheetWholeNote;

  /// No description provided for @cheatsheetSourceSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search notes'**
  String get cheatsheetSourceSearchHint;

  /// No description provided for @cheatsheetSourceOther.
  ///
  /// In en, this message translates to:
  /// **'Other notes'**
  String get cheatsheetSourceOther;

  /// Heading over the notes ranked first for a vehicle-domain card. SourceDomain carries an id, not this copy.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get cheatsheetSourceDomainVehicle;

  /// No description provided for @cheatsheetGroupVehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get cheatsheetGroupVehicle;

  /// No description provided for @cheatsheetGroupHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get cheatsheetGroupHealth;

  /// No description provided for @cheatsheetGroupReference.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get cheatsheetGroupReference;

  /// No description provided for @cheatsheetGroupUngrouped.
  ///
  /// In en, this message translates to:
  /// **'Ungrouped'**
  String get cheatsheetGroupUngrouped;

  /// No description provided for @cheatsheetTemplateAccidentClaim.
  ///
  /// In en, this message translates to:
  /// **'Accident Claim'**
  String get cheatsheetTemplateAccidentClaim;

  /// No description provided for @cheatsheetTemplateHealthInfo.
  ///
  /// In en, this message translates to:
  /// **'Health Info'**
  String get cheatsheetTemplateHealthInfo;

  /// No description provided for @cheatsheetTemplateDocument.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get cheatsheetTemplateDocument;

  /// No description provided for @cheatsheetTemplateBlank.
  ///
  /// In en, this message translates to:
  /// **'Blank'**
  String get cheatsheetTemplateBlank;

  /// No description provided for @cheatsheetRowPlate.
  ///
  /// In en, this message translates to:
  /// **'Plate'**
  String get cheatsheetRowPlate;

  /// No description provided for @cheatsheetRowVin.
  ///
  /// In en, this message translates to:
  /// **'VIN'**
  String get cheatsheetRowVin;

  /// No description provided for @cheatsheetRowInsurer.
  ///
  /// In en, this message translates to:
  /// **'Insurer'**
  String get cheatsheetRowInsurer;

  /// No description provided for @cheatsheetRowPolicyNumber.
  ///
  /// In en, this message translates to:
  /// **'Policy #'**
  String get cheatsheetRowPolicyNumber;

  /// No description provided for @cheatsheetRowDriver.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get cheatsheetRowDriver;

  /// No description provided for @cheatsheetRowPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get cheatsheetRowPhone;

  /// No description provided for @cheatsheetRowAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get cheatsheetRowAddress;

  /// No description provided for @cheatsheetRowPerson.
  ///
  /// In en, this message translates to:
  /// **'Person'**
  String get cheatsheetRowPerson;

  /// No description provided for @cheatsheetRowFamilyDoctor.
  ///
  /// In en, this message translates to:
  /// **'Family doctor'**
  String get cheatsheetRowFamilyDoctor;

  /// No description provided for @cheatsheetRowDoctorPhone.
  ///
  /// In en, this message translates to:
  /// **'Doctor phone'**
  String get cheatsheetRowDoctorPhone;

  /// No description provided for @cheatsheetRowPharmacy.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy'**
  String get cheatsheetRowPharmacy;

  /// No description provided for @cheatsheetRowPharmacyPhone.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy phone'**
  String get cheatsheetRowPharmacyPhone;

  /// No description provided for @cheatsheetRowSection1.
  ///
  /// In en, this message translates to:
  /// **'Section 1'**
  String get cheatsheetRowSection1;

  /// No description provided for @launcherTitle.
  ///
  /// In en, this message translates to:
  /// **'Launcher'**
  String get launcherTitle;

  /// No description provided for @launcherPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned (drag to reorder)'**
  String get launcherPinned;

  /// No description provided for @launcherFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get launcherFavorites;

  /// No description provided for @launcherAliases.
  ///
  /// In en, this message translates to:
  /// **'Aliases'**
  String get launcherAliases;

  /// No description provided for @launcherNewAlias.
  ///
  /// In en, this message translates to:
  /// **'New alias (e.g. cs)'**
  String get launcherNewAlias;

  /// No description provided for @launcherDestination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get launcherDestination;

  /// No description provided for @launcherAddAlias.
  ///
  /// In en, this message translates to:
  /// **'Add alias'**
  String get launcherAddAlias;

  /// No description provided for @launcherNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching features'**
  String get launcherNoMatches;

  /// No description provided for @launcherTypeSlash.
  ///
  /// In en, this message translates to:
  /// **'Type / to jump to a feature'**
  String get launcherTypeSlash;

  /// No description provided for @launcherRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get launcherRecent;

  /// No description provided for @launcherAssistantStub.
  ///
  /// In en, this message translates to:
  /// **'Ask the assistant — coming soon.\nType / to jump to a feature.'**
  String get launcherAssistantStub;

  /// No description provided for @launcherSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Type / for features · ask AI (soon)'**
  String get launcherSearchHint;

  /// No description provided for @launcherAliasMapping.
  ///
  /// In en, this message translates to:
  /// **'\"{alias}\"  →  {destination}'**
  String launcherAliasMapping(String alias, String destination);

  /// No description provided for @launcherDestVehicles.
  ///
  /// In en, this message translates to:
  /// **'Vehicles'**
  String get launcherDestVehicles;

  /// No description provided for @launcherDestGasLog.
  ///
  /// In en, this message translates to:
  /// **'Gas Log'**
  String get launcherDestGasLog;

  /// No description provided for @launcherDestServiceLog.
  ///
  /// In en, this message translates to:
  /// **'Service Log'**
  String get launcherDestServiceLog;

  /// No description provided for @launcherDestScheduledServices.
  ///
  /// In en, this message translates to:
  /// **'Scheduled Services'**
  String get launcherDestScheduledServices;

  /// No description provided for @launcherDestInsurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get launcherDestInsurance;

  /// No description provided for @launcherDestVehicleNotes.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Notes'**
  String get launcherDestVehicleNotes;

  /// No description provided for @launcherDestNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get launcherDestNotes;

  /// No description provided for @launcherDestGasStations.
  ///
  /// In en, this message translates to:
  /// **'Gas Stations'**
  String get launcherDestGasStations;

  /// No description provided for @launcherDestCheatsheets.
  ///
  /// In en, this message translates to:
  /// **'Cheatsheets'**
  String get launcherDestCheatsheets;

  /// No description provided for @launcherDestSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get launcherDestSettings;

  /// No description provided for @authLogin.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get authLogin;

  /// No description provided for @authSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get authSignUp;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get authConfirmPassword;

  /// No description provided for @authUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get authUsername;

  /// No description provided for @authForgotPasswordPrompt.
  ///
  /// In en, this message translates to:
  /// **'Forgot your password?'**
  String get authForgotPasswordPrompt;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get authForgotPassword;

  /// No description provided for @authResendEmail.
  ///
  /// In en, this message translates to:
  /// **'Resend email'**
  String get authResendEmail;

  /// No description provided for @authGoogle.
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get authGoogle;

  /// No description provided for @authApple.
  ///
  /// In en, this message translates to:
  /// **'Apple'**
  String get authApple;

  /// No description provided for @dashboardSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get dashboardSettings;

  /// No description provided for @dashboardSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get dashboardSignOut;

  /// No description provided for @dashboardComingSoon.
  ///
  /// In en, this message translates to:
  /// **'{feature} coming soon...'**
  String dashboardComingSoon(String feature);

  /// No description provided for @dashboardLooksGood.
  ///
  /// In en, this message translates to:
  /// **'Looks good'**
  String get dashboardLooksGood;

  /// No description provided for @dashboardOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get dashboardOpenSettings;

  /// No description provided for @dashboardDataStorage.
  ///
  /// In en, this message translates to:
  /// **'Data storage'**
  String get dashboardDataStorage;

  /// No description provided for @dashboardDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get dashboardDistance;

  /// No description provided for @dashboardFuelVolume.
  ///
  /// In en, this message translates to:
  /// **'Fuel volume'**
  String get dashboardFuelVolume;

  /// No description provided for @dashboardCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get dashboardCurrency;

  /// No description provided for @dashboardWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome — quick start'**
  String get dashboardWelcome;

  /// No description provided for @dashboardDefaultsBlurb.
  ///
  /// In en, this message translates to:
  /// **'We picked these defaults for you. Change them in Settings if anything looks off.'**
  String get dashboardDefaultsBlurb;

  /// No description provided for @onboardingWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get onboardingWelcome;

  /// No description provided for @onboardingNewUser.
  ///
  /// In en, this message translates to:
  /// **'New to Hmm'**
  String get onboardingNewUser;

  /// No description provided for @onboardingNewUserSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start fresh on this device. Your data stays local until you turn on cloud sync in Settings.'**
  String get onboardingNewUserSubtitle;

  /// No description provided for @onboardingMigrating.
  ///
  /// In en, this message translates to:
  /// **'I already use Hmm on another device'**
  String get onboardingMigrating;

  /// No description provided for @onboardingMigratingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to OneDrive and pull your existing data + settings down to this device.'**
  String get onboardingMigratingSubtitle;

  /// No description provided for @onboardingContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onboardingContinue;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get onboardingSkip;

  /// No description provided for @receiptCloudAiTitle.
  ///
  /// In en, this message translates to:
  /// **'Use Cloud AI for receipts?'**
  String get receiptCloudAiTitle;

  /// No description provided for @receiptCloudAiBody.
  ///
  /// In en, this message translates to:
  /// **'Your receipt photo or PDF will be uploaded to the Hmm server, which uses AI to read it and fill in the fields. On-device extraction keeps everything on your phone but can\'t read PDFs and won\'t itemize as accurately.'**
  String get receiptCloudAiBody;

  /// No description provided for @receiptEnableCloudAi.
  ///
  /// In en, this message translates to:
  /// **'Enable Cloud AI'**
  String get receiptEnableCloudAi;

  /// No description provided for @receiptOnDevice.
  ///
  /// In en, this message translates to:
  /// **'On-device (private)'**
  String get receiptOnDevice;

  /// No description provided for @receiptCloudAi.
  ///
  /// In en, this message translates to:
  /// **'Cloud AI (more accurate)'**
  String get receiptCloudAi;

  /// No description provided for @receiptOnDeviceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reads photos on your phone. Nothing is uploaded. Can\'t read PDFs.'**
  String get receiptOnDeviceSubtitle;

  /// No description provided for @receiptCloudAiSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Uploads the receipt for AI extraction. Reads PDFs and itemizes.'**
  String get receiptCloudAiSubtitle;

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

  /// No description provided for @recordsAddPolicy.
  ///
  /// In en, this message translates to:
  /// **'Add policy'**
  String get recordsAddPolicy;

  /// No description provided for @recordsNoPolicies.
  ///
  /// In en, this message translates to:
  /// **'No insurance policies yet'**
  String get recordsNoPolicies;

  /// No description provided for @recordsNoPoliciesHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + to record this vehicle\'s policy.'**
  String get recordsNoPoliciesHint;

  /// No description provided for @recordsPoliciesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load policies'**
  String get recordsPoliciesLoadFailed;

  /// No description provided for @recordsDeletePolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete policy?'**
  String get recordsDeletePolicyTitle;

  /// No description provided for @recordsDeletePolicyBody.
  ///
  /// In en, this message translates to:
  /// **'Delete policy {number} from {provider}?'**
  String recordsDeletePolicyBody(String number, String provider);

  /// No description provided for @recordsPolicyNumber.
  ///
  /// In en, this message translates to:
  /// **'Policy {number}'**
  String recordsPolicyNumber(String number);

  /// No description provided for @recordsProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get recordsProvider;

  /// No description provided for @recordsPolicyNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Policy number'**
  String get recordsPolicyNumberLabel;

  /// No description provided for @recordsEffectiveDate.
  ///
  /// In en, this message translates to:
  /// **'Effective date'**
  String get recordsEffectiveDate;

  /// No description provided for @recordsExpiryDate.
  ///
  /// In en, this message translates to:
  /// **'Expiry date'**
  String get recordsExpiryDate;

  /// No description provided for @recordsPremium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get recordsPremium;

  /// Very short column label for a currency code next to an amount field.
  ///
  /// In en, this message translates to:
  /// **'CCY'**
  String get recordsCurrencyShort;

  /// No description provided for @recordsDeductible.
  ///
  /// In en, this message translates to:
  /// **'Deductible (optional)'**
  String get recordsDeductible;

  /// No description provided for @recordsActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get recordsActive;

  /// No description provided for @recordsNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get recordsNotes;

  /// No description provided for @recordsDatesRequired.
  ///
  /// In en, this message translates to:
  /// **'Effective and expiry dates are required'**
  String get recordsDatesRequired;

  /// No description provided for @recordsDateOrderInvalid.
  ///
  /// In en, this message translates to:
  /// **'Effective date must be before expiry date'**
  String get recordsDateOrderInvalid;

  /// No description provided for @recordsAddSchedule.
  ///
  /// In en, this message translates to:
  /// **'Add schedule'**
  String get recordsAddSchedule;

  /// No description provided for @recordsNoSchedules.
  ///
  /// In en, this message translates to:
  /// **'No scheduled services yet'**
  String get recordsNoSchedules;

  /// No description provided for @recordsNoSchedulesHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + to set up a recurring reminder.'**
  String get recordsNoSchedulesHint;

  /// No description provided for @recordsSchedulesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load schedules'**
  String get recordsSchedulesLoadFailed;

  /// No description provided for @recordsDeleteScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete schedule?'**
  String get recordsDeleteScheduleTitle;

  /// No description provided for @recordsDeleteScheduleBody.
  ///
  /// In en, this message translates to:
  /// **'Delete schedule \"{name}\"?'**
  String recordsDeleteScheduleBody(String name);

  /// No description provided for @recordsNextDueDate.
  ///
  /// In en, this message translates to:
  /// **'Next due {date}'**
  String recordsNextDueDate(String date);

  /// {unit} is a unit symbol such as mi or km and is never translated.
  ///
  /// In en, this message translates to:
  /// **'Next due {mileage} {unit}'**
  String recordsNextDueMileage(String mileage, String unit);

  /// No description provided for @recordsScheduleName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get recordsScheduleName;

  /// No description provided for @recordsEveryNDays.
  ///
  /// In en, this message translates to:
  /// **'Every N days'**
  String get recordsEveryNDays;

  /// No description provided for @recordsEveryNMiles.
  ///
  /// In en, this message translates to:
  /// **'Every N miles'**
  String get recordsEveryNMiles;

  /// No description provided for @recordsNextDueDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Next due date'**
  String get recordsNextDueDateLabel;

  /// No description provided for @recordsNextDueMileageLabel.
  ///
  /// In en, this message translates to:
  /// **'Next due mileage'**
  String get recordsNextDueMileageLabel;

  /// No description provided for @recordsIntervalRequired.
  ///
  /// In en, this message translates to:
  /// **'Set at least one interval (days or mileage)'**
  String get recordsIntervalRequired;

  /// No description provided for @recordsAddRecord.
  ///
  /// In en, this message translates to:
  /// **'Add record'**
  String get recordsAddRecord;

  /// No description provided for @recordsNoServiceRecords.
  ///
  /// In en, this message translates to:
  /// **'No service records yet'**
  String get recordsNoServiceRecords;

  /// No description provided for @recordsNoServiceRecordsHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + to log this vehicle\'s first service.'**
  String get recordsNoServiceRecordsHint;

  /// No description provided for @recordsServiceLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load service records'**
  String get recordsServiceLoadFailed;

  /// No description provided for @recordsDeleteServiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete service record?'**
  String get recordsDeleteServiceTitle;

  /// No description provided for @recordsServiceDateMileage.
  ///
  /// In en, this message translates to:
  /// **'{date} • {mileage} {unit}'**
  String recordsServiceDateMileage(String date, String mileage, String unit);

  /// No description provided for @recordsItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String recordsItemCount(int count);

  /// No description provided for @recordsRecordCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 record on file} other{{count} records on file}}'**
  String recordsRecordCount(int count);

  /// No description provided for @recordsActiveSchedules.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 active schedule} other{{count} active schedules}}'**
  String recordsActiveSchedules(int count);

  /// No description provided for @recordsServiceName.
  ///
  /// In en, this message translates to:
  /// **'Service name'**
  String get recordsServiceName;

  /// No description provided for @recordsReference.
  ///
  /// In en, this message translates to:
  /// **'Reference # (optional)'**
  String get recordsReference;

  /// No description provided for @recordsServiceDate.
  ///
  /// In en, this message translates to:
  /// **'Service date'**
  String get recordsServiceDate;

  /// No description provided for @recordsMileage.
  ///
  /// In en, this message translates to:
  /// **'Mileage'**
  String get recordsMileage;

  /// No description provided for @recordsServiceTypes.
  ///
  /// In en, this message translates to:
  /// **'Service types'**
  String get recordsServiceTypes;

  /// No description provided for @recordsDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get recordsDescription;

  /// No description provided for @recordsShopName.
  ///
  /// In en, this message translates to:
  /// **'Shop name (optional)'**
  String get recordsShopName;

  /// No description provided for @recordsMarkdownHint.
  ///
  /// In en, this message translates to:
  /// **'Supports markdown'**
  String get recordsMarkdownHint;

  /// No description provided for @recordsPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get recordsPreview;

  /// No description provided for @recordsTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get recordsTakePhoto;

  /// No description provided for @recordsChoosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo'**
  String get recordsChoosePhoto;

  /// No description provided for @recordsChoosePdf.
  ///
  /// In en, this message translates to:
  /// **'Choose a PDF'**
  String get recordsChoosePdf;

  /// No description provided for @recordsNeedsCloudAi.
  ///
  /// In en, this message translates to:
  /// **'Needs Cloud AI (change in Settings)'**
  String get recordsNeedsCloudAi;

  /// No description provided for @recordsScanReceipt.
  ///
  /// In en, this message translates to:
  /// **'Scan a receipt'**
  String get recordsScanReceipt;

  /// No description provided for @recordsCompleteFields.
  ///
  /// In en, this message translates to:
  /// **'Please complete the highlighted fields (e.g. Mileage).'**
  String get recordsCompleteFields;

  /// No description provided for @recordsServiceDateRequired.
  ///
  /// In en, this message translates to:
  /// **'Service date is required'**
  String get recordsServiceDateRequired;

  /// No description provided for @recordsLineItemNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Each line item needs a name'**
  String get recordsLineItemNameRequired;

  /// No description provided for @recordsRemoveStoredImagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove stored images?'**
  String get recordsRemoveStoredImagesTitle;

  /// No description provided for @recordsKeepAttached.
  ///
  /// In en, this message translates to:
  /// **'Keep attached'**
  String get recordsKeepAttached;

  /// No description provided for @recordsLineItems.
  ///
  /// In en, this message translates to:
  /// **'Line items'**
  String get recordsLineItems;

  /// No description provided for @recordsAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get recordsAddItem;

  /// No description provided for @recordsTax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get recordsTax;

  /// No description provided for @recordsItemHint.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get recordsItemHint;

  /// No description provided for @recordsQtyHint.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get recordsQtyHint;

  /// No description provided for @recordsUnitHint.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get recordsUnitHint;

  /// No description provided for @recordsAmountHint.
  ///
  /// In en, this message translates to:
  /// **'0.00'**
  String get recordsAmountHint;

  /// No description provided for @recordsVehicleNotes.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Notes'**
  String get recordsVehicleNotes;

  /// No description provided for @serviceTypeOilChange.
  ///
  /// In en, this message translates to:
  /// **'Oil change'**
  String get serviceTypeOilChange;

  /// No description provided for @serviceTypeTireRotation.
  ///
  /// In en, this message translates to:
  /// **'Tire rotation'**
  String get serviceTypeTireRotation;

  /// No description provided for @serviceTypeBrake.
  ///
  /// In en, this message translates to:
  /// **'Brake'**
  String get serviceTypeBrake;

  /// No description provided for @serviceTypeInspection.
  ///
  /// In en, this message translates to:
  /// **'Inspection'**
  String get serviceTypeInspection;

  /// No description provided for @serviceTypeRepair.
  ///
  /// In en, this message translates to:
  /// **'Repair'**
  String get serviceTypeRepair;

  /// No description provided for @serviceTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get serviceTypeOther;

  /// No description provided for @lineItemLabour.
  ///
  /// In en, this message translates to:
  /// **'Labour'**
  String get lineItemLabour;

  /// No description provided for @lineItemPart.
  ///
  /// In en, this message translates to:
  /// **'Part'**
  String get lineItemPart;

  /// No description provided for @lineItemFee.
  ///
  /// In en, this message translates to:
  /// **'Fee'**
  String get lineItemFee;

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

  /// No description provided for @contactBlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contactBlockTitle;

  /// No description provided for @contactBlockAdd.
  ///
  /// In en, this message translates to:
  /// **'Add contact'**
  String get contactBlockAdd;

  /// No description provided for @contactBlockRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove contact'**
  String get contactBlockRemove;

  /// No description provided for @contactFieldRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get contactFieldRole;

  /// No description provided for @contactFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get contactFieldName;

  /// No description provided for @contactFieldOrganization.
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get contactFieldOrganization;

  /// No description provided for @contactFieldPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get contactFieldPhone;

  /// No description provided for @contactFieldMobile.
  ///
  /// In en, this message translates to:
  /// **'Cell'**
  String get contactFieldMobile;

  /// No description provided for @contactFieldFax.
  ///
  /// In en, this message translates to:
  /// **'Fax'**
  String get contactFieldFax;

  /// No description provided for @contactFieldEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get contactFieldEmail;

  /// No description provided for @contactFieldAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get contactFieldAddress;

  /// No description provided for @contactFieldStreet.
  ///
  /// In en, this message translates to:
  /// **'Street address'**
  String get contactFieldStreet;

  /// No description provided for @contactFieldCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get contactFieldCity;

  /// No description provided for @contactFieldRegion.
  ///
  /// In en, this message translates to:
  /// **'Province / State'**
  String get contactFieldRegion;

  /// No description provided for @contactFieldPostalCode.
  ///
  /// In en, this message translates to:
  /// **'Postal code'**
  String get contactFieldPostalCode;

  /// No description provided for @contactFieldCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get contactFieldCountry;

  /// No description provided for @contactFieldNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get contactFieldNotes;

  /// No description provided for @contactRoleAgent.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get contactRoleAgent;

  /// No description provided for @contactRoleDoctor.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get contactRoleDoctor;

  /// No description provided for @contactRoleHospital.
  ///
  /// In en, this message translates to:
  /// **'Hospital'**
  String get contactRoleHospital;

  /// No description provided for @contactRolePharmacy.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy'**
  String get contactRolePharmacy;

  /// No description provided for @contactRoleEmergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get contactRoleEmergency;

  /// No description provided for @contactRoleFriend.
  ///
  /// In en, this message translates to:
  /// **'Friend'**
  String get contactRoleFriend;

  /// No description provided for @contactRoleFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get contactRoleFamily;

  /// No description provided for @contactRoleOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get contactRoleOther;

  /// No description provided for @vehicleRegistrationSection.
  ///
  /// In en, this message translates to:
  /// **'Registration'**
  String get vehicleRegistrationSection;

  /// No description provided for @vehicleRegistrationNumber.
  ///
  /// In en, this message translates to:
  /// **'Registration number'**
  String get vehicleRegistrationNumber;

  /// No description provided for @vehicleRegistrationJurisdiction.
  ///
  /// In en, this message translates to:
  /// **'Province / State'**
  String get vehicleRegistrationJurisdiction;

  /// No description provided for @vehicleRegistrationIssued.
  ///
  /// In en, this message translates to:
  /// **'Issued'**
  String get vehicleRegistrationIssued;

  /// No description provided for @vehicleValueNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get vehicleValueNotSet;
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
