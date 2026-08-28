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
  String get catalogGeneral => 'General';

  @override
  String get catalogGasLog => 'Gas Log';

  @override
  String get catalogAutomobile => 'Automobile';

  @override
  String get catalogInsurance => 'Insurance';

  @override
  String get catalogScheduledService => 'Scheduled Service';

  @override
  String get catalogServiceRecord => 'Service Record';

  @override
  String get catalogNote => 'Note';

  @override
  String get domainAutomobile => 'Automobile';

  @override
  String get domainGeneral => 'General';

  @override
  String get domainOther => 'Other';

  @override
  String get notesTitle => 'Notes';

  @override
  String get notesSearchHint => 'Search subjects';

  @override
  String notesLoadFailed(String error) {
    return 'Failed to load notes: $error';
  }

  @override
  String get notesFilter => 'FILTER';

  @override
  String get notesAll => 'All';

  @override
  String get notesAllNotes => 'All notes';

  @override
  String notesAllInDomain(String domain) {
    return 'All $domain';
  }

  @override
  String notesNoteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes',
      one: '1 note',
    );
    return '$_temp0';
  }

  @override
  String get notesSelectNote => 'Select a note';

  @override
  String get notesNone => 'None';

  @override
  String get notesEmpty => 'No notes yet';

  @override
  String get notesNoUnattached => 'No unattached notes';

  @override
  String get notesNoMatches => 'No notes';

  @override
  String get notesSearchNotes => 'Search notes';

  @override
  String get notesLinkedUnavailable => 'Linked note unavailable';

  @override
  String notesGenericFailure(String error) {
    return 'Failed: $error';
  }

  @override
  String get notesSubjectRequired => 'Subject is required';

  @override
  String get notesTitleHint => 'Title';

  @override
  String get notesBodyHint => 'Start writing…';

  @override
  String get notesDone => 'Done';

  @override
  String get notesRemoveStoredImagesTitle => 'Remove stored images?';

  @override
  String get notesKeepAttached => 'Keep attached';

  @override
  String get notesEditAction => 'Edit';

  @override
  String get notesViewRaw => 'View raw content';

  @override
  String get notesRawContentTitle => 'Raw content';

  @override
  String get notesSubsystemsTitle => 'Subsystems';

  @override
  String get notesSubsystemAutomobile => 'Automobile';

  @override
  String get notesRecordMicPermission =>
      'Microphone permission needed to record';

  @override
  String get notesRecordStartFailed => 'Could not start recording';

  @override
  String get notesRecordTooLong =>
      'Recording is too long; please record a shorter one';

  @override
  String notesRecording(String time) {
    return 'Recording…  $time';
  }

  @override
  String get notesRecordStop => 'Stop';

  @override
  String get notesVaultSetUpPrompt =>
      'Set up Secure Vault in Settings to view this image.';

  @override
  String get cheatsheetWalletTitle => 'Cheatsheets';

  @override
  String get cheatsheetNew => 'New cheatsheet';

  @override
  String cheatsheetLoadFailed(String error) {
    return 'Could not load your cheatsheets.\n$error';
  }

  @override
  String get cheatsheetEmpty => 'No cheatsheets yet. Tap + to make one.';

  @override
  String get cheatsheetSearchHint => 'Search cheatsheets';

  @override
  String get cheatsheetNoMatches => 'Nothing matches that search.';

  @override
  String get cheatsheetGone => 'That cheatsheet no longer exists.';

  @override
  String cheatsheetSaveFailed(String error) {
    return 'Could not save this cheatsheet: $error';
  }

  @override
  String cheatsheetDeleteFailed(String error) {
    return 'Could not delete this cheatsheet: $error';
  }

  @override
  String get cheatsheetDeleteTitle => 'Delete this cheatsheet?';

  @override
  String get cheatsheetEditTooltip => 'Edit cheatsheet';

  @override
  String get cheatsheetDeleteTooltip => 'Delete cheatsheet';

  @override
  String get cheatsheetOpenSource => 'Open source';

  @override
  String get cheatsheetOpenSourceTooltip => 'Open the source note';

  @override
  String get cheatsheetOpenFailed => 'Could not open that.';

  @override
  String get cheatsheetTitleLabel => 'Title';

  @override
  String get cheatsheetWalletGroupLabel => 'Wallet group';

  @override
  String get cheatsheetNewRow => 'New row';

  @override
  String get cheatsheetAddRow => 'Add row';

  @override
  String get cheatsheetRemoveRow => 'Remove this row';

  @override
  String cheatsheetSourceLoadFailed(String error) {
    return 'Could not load notes: $error';
  }

  @override
  String get cheatsheetSourceEmpty => 'No notes to reference yet.';

  @override
  String get cheatsheetSourceNoMatches => 'No notes match that search.';

  @override
  String get cheatsheetSourceBack => 'Back to the note list';

  @override
  String get cheatsheetWholeNote => 'The whole note';

  @override
  String get cheatsheetSourceSearchHint => 'Search notes';

  @override
  String get cheatsheetSourceOther => 'Other notes';

  @override
  String get cheatsheetSourceDomainVehicle => 'Vehicle';

  @override
  String get cheatsheetGroupVehicle => 'Vehicle';

  @override
  String get cheatsheetGroupHealth => 'Health';

  @override
  String get cheatsheetGroupReference => 'Reference';

  @override
  String get cheatsheetGroupUngrouped => 'Ungrouped';

  @override
  String get cheatsheetTemplateAccidentClaim => 'Accident Claim';

  @override
  String get cheatsheetTemplateHealthInfo => 'Health Info';

  @override
  String get cheatsheetTemplateDocument => 'Document';

  @override
  String get cheatsheetTemplateBlank => 'Blank';

  @override
  String get cheatsheetRowPlate => 'Plate';

  @override
  String get cheatsheetRowVin => 'VIN';

  @override
  String get cheatsheetRowInsurer => 'Insurer';

  @override
  String get cheatsheetRowPolicyNumber => 'Policy #';

  @override
  String get cheatsheetRowDriver => 'Driver';

  @override
  String get cheatsheetRowPhone => 'Phone';

  @override
  String get cheatsheetRowAddress => 'Address';

  @override
  String get cheatsheetRowPerson => 'Person';

  @override
  String get cheatsheetRowFamilyDoctor => 'Family doctor';

  @override
  String get cheatsheetRowDoctorPhone => 'Doctor phone';

  @override
  String get cheatsheetRowPharmacy => 'Pharmacy';

  @override
  String get cheatsheetRowPharmacyPhone => 'Pharmacy phone';

  @override
  String get cheatsheetRowSection1 => 'Section 1';

  @override
  String get launcherTitle => 'Launcher';

  @override
  String get launcherPinned => 'Pinned (drag to reorder)';

  @override
  String get launcherFavorites => 'Favorites';

  @override
  String get launcherAliases => 'Aliases';

  @override
  String get launcherNewAlias => 'New alias (e.g. cs)';

  @override
  String get launcherDestination => 'Destination';

  @override
  String get launcherAddAlias => 'Add alias';

  @override
  String get launcherNoMatches => 'No matching features';

  @override
  String get launcherTypeSlash => 'Type / to jump to a feature';

  @override
  String get launcherRecent => 'Recent';

  @override
  String get launcherAssistantStub =>
      'Ask the assistant — coming soon.\nType / to jump to a feature.';

  @override
  String get launcherSearchHint => 'Type / for features · ask AI (soon)';

  @override
  String launcherAliasMapping(String alias, String destination) {
    return '\"$alias\"  →  $destination';
  }

  @override
  String get launcherDestVehicles => 'Vehicles';

  @override
  String get launcherDestGasLog => 'Gas Log';

  @override
  String get launcherDestServiceLog => 'Service Log';

  @override
  String get launcherDestScheduledServices => 'Scheduled Services';

  @override
  String get launcherDestInsurance => 'Insurance';

  @override
  String get launcherDestVehicleNotes => 'Vehicle Notes';

  @override
  String get launcherDestNotes => 'Notes';

  @override
  String get launcherDestGasStations => 'Gas Stations';

  @override
  String get launcherDestCheatsheets => 'Cheatsheets';

  @override
  String get launcherDestSettings => 'Settings';

  @override
  String get authLogin => 'Login';

  @override
  String get authSignUp => 'Sign Up';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authConfirmPassword => 'Confirm Password';

  @override
  String get authUsername => 'Username';

  @override
  String get authForgotPasswordPrompt => 'Forgot your password?';

  @override
  String get authForgotPassword => 'Forgot Password';

  @override
  String get authResendEmail => 'Resend email';

  @override
  String get authGoogle => 'Google';

  @override
  String get authApple => 'Apple';

  @override
  String get dashboardSettings => 'Settings';

  @override
  String get dashboardSignOut => 'Sign out';

  @override
  String dashboardComingSoon(String feature) {
    return '$feature coming soon...';
  }

  @override
  String get dashboardLooksGood => 'Looks good';

  @override
  String get dashboardOpenSettings => 'Open settings';

  @override
  String get dashboardDataStorage => 'Data storage';

  @override
  String get dashboardDistance => 'Distance';

  @override
  String get dashboardFuelVolume => 'Fuel volume';

  @override
  String get dashboardCurrency => 'Currency';

  @override
  String get dashboardWelcome => 'Welcome — quick start';

  @override
  String get dashboardDefaultsBlurb =>
      'We picked these defaults for you. Change them in Settings if anything looks off.';

  @override
  String get onboardingWelcome => 'Welcome';

  @override
  String get onboardingNewUser => 'New to Hmm';

  @override
  String get onboardingNewUserSubtitle =>
      'Start fresh on this device. Your data stays local until you turn on cloud sync in Settings.';

  @override
  String get onboardingMigrating => 'I already use Hmm on another device';

  @override
  String get onboardingMigratingSubtitle =>
      'Sign in to OneDrive and pull your existing data + settings down to this device.';

  @override
  String get onboardingContinue => 'Continue';

  @override
  String get onboardingSkip => 'Skip for now';

  @override
  String get receiptCloudAiTitle => 'Use Cloud AI for receipts?';

  @override
  String get receiptCloudAiBody =>
      'Your receipt photo or PDF will be uploaded to the Hmm server, which uses AI to read it and fill in the fields. On-device extraction keeps everything on your phone but can\'t read PDFs and won\'t itemize as accurately.';

  @override
  String get receiptEnableCloudAi => 'Enable Cloud AI';

  @override
  String get receiptOnDevice => 'On-device (private)';

  @override
  String get receiptCloudAi => 'Cloud AI (more accurate)';

  @override
  String get receiptOnDeviceSubtitle =>
      'Reads photos on your phone. Nothing is uploaded. Can\'t read PDFs.';

  @override
  String get receiptCloudAiSubtitle =>
      'Uploads the receipt for AI extraction. Reads PDFs and itemizes.';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonEdit => 'Edit';

  @override
  String commonError(String error) {
    return 'Error: $error';
  }

  @override
  String get gasLogTitle => 'Gas Logs';

  @override
  String get gasLogLoadFailed => 'Failed to load gas logs';

  @override
  String get gasLogEmpty => 'No gas logs yet';

  @override
  String get gasLogLoadMore => 'Load More';

  @override
  String get gasLogDeleteTitle => 'Delete Gas Log';

  @override
  String get gasLogDeleteBody =>
      'Are you sure you want to delete this gas log?';

  @override
  String gasLogDeleteFailed(String error) {
    return 'Delete failed: $error';
  }

  @override
  String get gasLogCreated => 'Gas log created';

  @override
  String get gasLogUpdated => 'Gas log updated';

  @override
  String gasLogOdometer(String unit) {
    return 'Odometer ($unit)';
  }

  @override
  String gasLogDistance(String unit) {
    return 'Distance ($unit)';
  }

  @override
  String gasLogFuel(String unit) {
    return 'Fuel ($unit)';
  }

  @override
  String gasLogUnitPrice(String currency, String unit) {
    return 'Unit Price ($currency/$unit)';
  }

  @override
  String gasLogTotalPrice(String currency) {
    return 'Total Price ($currency)';
  }

  @override
  String get gasLogFullTank => 'Full Tank';

  @override
  String get gasLogComment => 'Comment (optional)';

  @override
  String get gasLogSelectStation => 'Please select or enter a gas station';

  @override
  String get vehicleNewTitle => 'New Vehicle';

  @override
  String get vehicleCreated => 'Vehicle created';

  @override
  String get vehicleUpdated => 'Vehicle updated';

  @override
  String get vehicleNotFound => 'Vehicle not found';

  @override
  String get vehicleInformation => 'Vehicle Information';

  @override
  String get vehicleManageTitle => 'Manage Vehicles';

  @override
  String get vehicleSelectTitle => 'Select Vehicle';

  @override
  String get vehicleManage => 'Manage';

  @override
  String get vehicleManageVehicles => 'Manage Vehicles';

  @override
  String get vehicleLoadFailed => 'Failed to load vehicles';

  @override
  String get vehicleEmpty => 'No vehicles yet';

  @override
  String get vehicleEmptyHint => 'Tap + to add your first vehicle.';

  @override
  String get vehicleNoneFound => 'No vehicles found';

  @override
  String get vehicleNoneFoundHint => 'Add a vehicle to get started.';

  @override
  String get vehicleStatusUpdated => 'Vehicle status updated';

  @override
  String vehicleActiveCount(int count) {
    return 'Active ($count)';
  }

  @override
  String vehicleInactiveCount(int count) {
    return 'Inactive ($count)';
  }

  @override
  String get vehicleVin => 'VIN (17 characters)';

  @override
  String get vehicleMaker => 'Maker';

  @override
  String get vehicleBrand => 'Brand';

  @override
  String get vehicleModel => 'Model';

  @override
  String get vehicleTrim => 'Trim (optional)';

  @override
  String get vehicleYear => 'Year';

  @override
  String get vehicleColor => 'Color';

  @override
  String get vehicleColorOptional => 'Color (optional)';

  @override
  String get vehiclePlate => 'Plate';

  @override
  String get vehicleTankCapacity => 'Tank Capacity (optional)';

  @override
  String get vehicleCityMpg => 'City MPG';

  @override
  String get vehicleHwyMpg => 'Hwy MPG';

  @override
  String get vehicleCombinedMpg => 'Combined';

  @override
  String vehicleMeterReading(String unit) {
    return 'Meter Reading ($unit)';
  }

  @override
  String vehiclePurchasePrice(String currency) {
    return 'Purchase Price ($currency)';
  }

  @override
  String get vehicleNotes => 'Notes';

  @override
  String get vehicleNotesOptional => 'Notes (optional)';

  @override
  String get vehicleMileage => 'Mileage';

  @override
  String get vehicleRegistration => 'Registration';

  @override
  String get vehicleRegistrationExpiry => 'Registration Expiry';

  @override
  String get vehicleInvalidMeterReading => 'Enter a valid meter reading';

  @override
  String get vehiclePhotoUnavailable => 'Photo unavailable';

  @override
  String vehiclePhotoPickFailed(String error) {
    return 'Could not pick photo: $error';
  }

  @override
  String get vehicleEditIdentityTitle => 'Edit vehicle identity?';

  @override
  String vehicleActionConfirm(String action) {
    return '$action vehicle?';
  }

  @override
  String get vehicleDeactivate => 'Deactivate';

  @override
  String get vehicleReactivate => 'Reactivate';

  @override
  String get vehicleDeactivateTitle => 'Deactivate vehicle?';

  @override
  String get vehicleReactivateTitle => 'Reactivate vehicle?';

  @override
  String vehicleDeactivateBody(String vehicle) {
    return 'Are you sure you want to deactivate $vehicle?';
  }

  @override
  String vehicleReactivateBody(String vehicle) {
    return 'Are you sure you want to reactivate $vehicle?';
  }

  @override
  String stationDeactivateBody(String station) {
    return 'Are you sure you want to deactivate \"$station\"?';
  }

  @override
  String stationReactivateBody(String station) {
    return 'Are you sure you want to reactivate \"$station\"?';
  }

  @override
  String get stationDeactivateTitle => 'Deactivate station?';

  @override
  String get stationReactivateTitle => 'Reactivate station?';

  @override
  String get stationTitle => 'Gas Stations';

  @override
  String get stationLoadFailed => 'Failed to load gas stations';

  @override
  String get stationEmpty => 'No gas stations yet';

  @override
  String get stationEmptyHint => 'Tap + to add your first gas station.';

  @override
  String stationActionConfirm(String action) {
    return '$action station?';
  }

  @override
  String get stationName => 'Station Name';

  @override
  String get stationHintCreate => 'Type to create new station';

  @override
  String get stationHintSelect => 'Select or type new station';

  @override
  String get stationNameRequired => 'Station Name *';

  @override
  String get stationAddress => 'Address';

  @override
  String get stationCityRequired => 'City *';

  @override
  String get stationStateProvince => 'State/Province';

  @override
  String get stationCountryRequired => 'Country *';

  @override
  String get stationPostalCode => 'Zip/Postal Code';

  @override
  String get stationDescription => 'Description';

  @override
  String stationCreateFailed(String error) {
    return 'Failed to create station: $error';
  }

  @override
  String stationUpdateFailed(String error) {
    return 'Failed to update station: $error';
  }

  @override
  String get stationLocationCaptured => 'Location and address captured';

  @override
  String get stationLocationNoAddress =>
      'Location captured (address lookup unavailable)';

  @override
  String get stationLocationDenied =>
      'Could not get location. Check permissions.';

  @override
  String stationLocationError(String error) {
    return 'Location error: $error';
  }

  @override
  String stationSaveFailed(String action, String error) {
    return 'Failed to $action station: $error';
  }

  @override
  String get sectionIdentity => 'Identity';

  @override
  String get sectionAppearance => 'Appearance';

  @override
  String get sectionEngine => 'Engine';

  @override
  String get sectionOwnership => 'Ownership';

  @override
  String get sectionNotes => 'Notes';

  @override
  String get sectionChangeHistory => 'Change history';

  @override
  String get fieldDate => 'Date';

  @override
  String get fuelTypeLabel => 'Fuel Type';

  @override
  String get fuelGradeLabel => 'Fuel Grade';

  @override
  String get engineTypeLabel => 'Engine Type';

  @override
  String get ownershipStatusLabel => 'Ownership Status';

  @override
  String get optionRegular => 'Regular';

  @override
  String get optionMidGrade => 'Mid-Grade';

  @override
  String get optionPremium => 'Premium';

  @override
  String get optionDiesel => 'Diesel';

  @override
  String get optionE85 => 'E85';

  @override
  String get optionElectric => 'Electric';

  @override
  String get optionOther => 'Other';

  @override
  String get optionGasoline => 'Gasoline';

  @override
  String get optionHybrid => 'Hybrid';

  @override
  String get optionPlugInHybrid => 'Plug-in Hybrid';

  @override
  String get optionHydrogen => 'Hydrogen';

  @override
  String get optionCng => 'CNG';

  @override
  String get optionOwned => 'Owned';

  @override
  String get optionFinanced => 'Financed';

  @override
  String get optionLeased => 'Leased';

  @override
  String get optionCompany => 'Company';

  @override
  String get validationVinRequired => 'VIN is required';

  @override
  String get validationVinLength => 'VIN must be exactly 17 characters';

  @override
  String get validationMakerRequired => 'Maker is required';

  @override
  String get validationMakerTooLong => 'Maker must be 50 characters or less';

  @override
  String get validationBrandRequired => 'Brand is required';

  @override
  String get validationBrandTooLong => 'Brand must be 50 characters or less';

  @override
  String get validationModelRequired => 'Model is required';

  @override
  String get validationModelTooLong => 'Model must be 50 characters or less';

  @override
  String get validationPlateRequired => 'Plate is required';

  @override
  String get validationPlateTooLong => 'Plate must be 20 characters or less';

  @override
  String get validationYearRequired => 'Year is required';

  @override
  String validationYearRange(int min, int max) {
    return 'Enter a year between $min and $max';
  }

  @override
  String get validationOdometerRequired => 'Odometer is required';

  @override
  String get validationOdometerInvalid => 'Enter a valid odometer reading';

  @override
  String get validationFuelRequired => 'Fuel amount is required';

  @override
  String get validationFuelInvalid => 'Enter a valid fuel amount';

  @override
  String get validationPriceRequired => 'Price is required';

  @override
  String get validationPriceInvalid => 'Enter a valid price';

  @override
  String get validationDistanceInvalid => 'Enter a valid distance';

  @override
  String validationOdometerBelowCurrent(String current) {
    return 'Odometer cannot be less than current reading ($current)';
  }

  @override
  String validationOdometerLargeGap(String gap, String expected) {
    return 'Large gap: odometer is $gap from expected ($expected)';
  }

  @override
  String get recordsAddPolicy => 'Add policy';

  @override
  String get recordsNoPolicies => 'No insurance policies yet';

  @override
  String get recordsNoPoliciesHint => 'Tap + to record this vehicle\'s policy.';

  @override
  String get recordsPoliciesLoadFailed => 'Failed to load policies';

  @override
  String get recordsDeletePolicyTitle => 'Delete policy?';

  @override
  String recordsDeletePolicyBody(String number, String provider) {
    return 'Delete policy $number from $provider?';
  }

  @override
  String recordsPolicyNumber(String number) {
    return 'Policy $number';
  }

  @override
  String get recordsProvider => 'Provider';

  @override
  String get recordsPolicyNumberLabel => 'Policy number';

  @override
  String get recordsEffectiveDate => 'Effective date';

  @override
  String get recordsExpiryDate => 'Expiry date';

  @override
  String get recordsPremium => 'Premium';

  @override
  String get recordsCurrencyShort => 'CCY';

  @override
  String get recordsDeductible => 'Deductible (optional)';

  @override
  String get recordsActive => 'Active';

  @override
  String get recordsNotes => 'Notes';

  @override
  String get recordsDatesRequired => 'Effective and expiry dates are required';

  @override
  String get recordsDateOrderInvalid =>
      'Effective date must be before expiry date';

  @override
  String get recordsAddSchedule => 'Add schedule';

  @override
  String get recordsNoSchedules => 'No scheduled services yet';

  @override
  String get recordsNoSchedulesHint => 'Tap + to set up a recurring reminder.';

  @override
  String get recordsSchedulesLoadFailed => 'Failed to load schedules';

  @override
  String get recordsDeleteScheduleTitle => 'Delete schedule?';

  @override
  String recordsDeleteScheduleBody(String name) {
    return 'Delete schedule \"$name\"?';
  }

  @override
  String recordsNextDueDate(String date) {
    return 'Next due $date';
  }

  @override
  String recordsNextDueMileage(String mileage, String unit) {
    return 'Next due $mileage $unit';
  }

  @override
  String get recordsScheduleName => 'Name';

  @override
  String get recordsEveryNDays => 'Every N days';

  @override
  String get recordsEveryNMiles => 'Every N miles';

  @override
  String get recordsNextDueDateLabel => 'Next due date';

  @override
  String get recordsNextDueMileageLabel => 'Next due mileage';

  @override
  String get recordsIntervalRequired =>
      'Set at least one interval (days or mileage)';

  @override
  String get recordsAddRecord => 'Add record';

  @override
  String get recordsNoServiceRecords => 'No service records yet';

  @override
  String get recordsNoServiceRecordsHint =>
      'Tap + to log this vehicle\'s first service.';

  @override
  String get recordsServiceLoadFailed => 'Failed to load service records';

  @override
  String get recordsDeleteServiceTitle => 'Delete service record?';

  @override
  String recordsServiceDateMileage(String date, String mileage, String unit) {
    return '$date • $mileage $unit';
  }

  @override
  String recordsItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String recordsRecordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records on file',
      one: '1 record on file',
    );
    return '$_temp0';
  }

  @override
  String recordsActiveSchedules(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active schedules',
      one: '1 active schedule',
    );
    return '$_temp0';
  }

  @override
  String get recordsServiceName => 'Service name';

  @override
  String get recordsReference => 'Reference # (optional)';

  @override
  String get recordsServiceDate => 'Service date';

  @override
  String get recordsMileage => 'Mileage';

  @override
  String get recordsServiceTypes => 'Service types';

  @override
  String get recordsDescription => 'Description';

  @override
  String get recordsShopName => 'Shop name (optional)';

  @override
  String get recordsMarkdownHint => 'Supports markdown';

  @override
  String get recordsPreview => 'Preview';

  @override
  String get recordsTakePhoto => 'Take a photo';

  @override
  String get recordsChoosePhoto => 'Choose a photo';

  @override
  String get recordsChoosePdf => 'Choose a PDF';

  @override
  String get recordsNeedsCloudAi => 'Needs Cloud AI (change in Settings)';

  @override
  String get recordsScanReceipt => 'Scan a receipt';

  @override
  String get recordsCompleteFields =>
      'Please complete the highlighted fields (e.g. Mileage).';

  @override
  String get recordsServiceDateRequired => 'Service date is required';

  @override
  String get recordsLineItemNameRequired => 'Each line item needs a name';

  @override
  String get recordsRemoveStoredImagesTitle => 'Remove stored images?';

  @override
  String get recordsKeepAttached => 'Keep attached';

  @override
  String get recordsLineItems => 'Line items';

  @override
  String get recordsAddItem => 'Add item';

  @override
  String get recordsTax => 'Tax';

  @override
  String get recordsItemHint => 'Item';

  @override
  String get recordsQtyHint => 'Qty';

  @override
  String get recordsUnitHint => 'Unit';

  @override
  String get recordsAmountHint => '0.00';

  @override
  String get recordsVehicleNotes => 'Vehicle Notes';

  @override
  String get serviceTypeOilChange => 'Oil change';

  @override
  String get serviceTypeTireRotation => 'Tire rotation';

  @override
  String get serviceTypeBrake => 'Brake';

  @override
  String get serviceTypeInspection => 'Inspection';

  @override
  String get serviceTypeRepair => 'Repair';

  @override
  String get serviceTypeOther => 'Other';

  @override
  String get lineItemLabour => 'Labour';

  @override
  String get lineItemPart => 'Part';

  @override
  String get lineItemFee => 'Fee';

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

  @override
  String get contactBlockTitle => 'Contact';

  @override
  String get contactBlockAdd => 'Add contact';

  @override
  String get contactBlockRemove => 'Remove contact';

  @override
  String get contactFieldRole => 'Role';

  @override
  String get contactFieldName => 'Name';

  @override
  String get contactFieldOrganization => 'Organization';

  @override
  String get contactFieldPhone => 'Phone';

  @override
  String get contactFieldEmail => 'Email';

  @override
  String get contactFieldAddress => 'Address';

  @override
  String get contactFieldNotes => 'Notes';

  @override
  String get contactRoleAgent => 'Agent';

  @override
  String get contactRoleDoctor => 'Doctor';

  @override
  String get contactRoleHospital => 'Hospital';

  @override
  String get contactRolePharmacy => 'Pharmacy';

  @override
  String get contactRoleEmergency => 'Emergency';

  @override
  String get contactRoleFriend => 'Friend';

  @override
  String get contactRoleFamily => 'Family';

  @override
  String get contactRoleOther => 'Other';

  @override
  String get vehicleRegistrationSection => 'Registration';

  @override
  String get vehicleRegistrationNumber => 'Registration number';

  @override
  String get vehicleRegistrationJurisdiction => 'Province / State';

  @override
  String get vehicleRegistrationIssued => 'Issued';

  @override
  String get vehicleValueNotSet => 'Not set';
}
