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
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsAppearanceSystem => 'System';

  @override
  String get settingsAppearanceLight => 'Light';

  @override
  String get settingsAppearanceDark => 'Dark';

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
  String get oneDriveChooseFolderTitle => 'Choose your Hmm data in OneDrive';

  @override
  String oneDriveFolderModified(String date) {
    return 'Last changed $date';
  }

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
  String get commonCopy => 'Copy';

  @override
  String get commonClose => 'Close';

  @override
  String get syncErrorTitle => 'Sync error';

  @override
  String get syncErrorCopied => 'Copied';

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
  String syncSheetSignedInAs(String email) {
    return 'Signed in as $email';
  }

  @override
  String get syncSheetSignInAgain => 'Sign in again';

  @override
  String get syncSheetSyncNow => 'Sync now';

  @override
  String get syncSheetAuthExpired =>
      'Your Hmm sign-in has expired. Sign in again to resume syncing.';

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
  String get notesSearchHint => 'Search notes';

  @override
  String get notesLoadFailed => 'Couldn\'t load your notes';

  @override
  String get notesAll => 'All';

  @override
  String get notesPickTitle => 'Choose a note';

  @override
  String get notesSelectNote => 'Select a note';

  @override
  String get notesNone => 'None';

  @override
  String get notesEmpty => 'No notes yet';

  @override
  String get notesNoUnattached => 'No unattached notes';

  @override
  String notesNoMatches(String query) {
    return 'No notes match “$query”';
  }

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
  String get notesDeletedElsewhereTitle => 'Deleted on another device';

  @override
  String get notesDeletedElsewhereBody =>
      'This note was deleted on another device while you were editing it. Restore it with your changes, or discard your changes and leave it in Recently Deleted.';

  @override
  String get notesDeletedElsewhereRestore => 'Restore and save';

  @override
  String get notesDeletedElsewhereDiscard => 'Discard changes';

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
  String get attachmentPhotoLoadFailed => 'Could not load photo';

  @override
  String get cheatsheetWalletTitle => 'Cheatsheets';

  @override
  String get cheatsheetNew => 'New cheatsheet';

  @override
  String get cheatsheetLoadFailed => 'Could not load your cheatsheets.';

  @override
  String get cheatsheetEmpty => 'No cheatsheets yet. Tap + to make one.';

  @override
  String get cheatsheetSearchHint => 'Search cheatsheets';

  @override
  String get cheatsheetNoMatches => 'Nothing matches that search.';

  @override
  String get cheatsheetGone => 'That cheatsheet no longer exists.';

  @override
  String get cheatsheetSaveFailed => 'Could not save this cheatsheet.';

  @override
  String get cheatsheetDeleteFailed => 'Could not delete this cheatsheet.';

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
  String get cheatsheetTapToBind => 'Tap to bind';

  @override
  String get cheatsheetStartEmpty => 'Start empty';

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
  String get cheatsheetSourceImages => 'Photos';

  @override
  String get cheatsheetImageSummary => 'Photo';

  @override
  String get cheatsheetSourceSearchHint => 'Search notes';

  @override
  String get cheatsheetSourceOther => 'Other notes';

  @override
  String get cheatsheetSourceDomainVehicle => 'Vehicle';

  @override
  String get cheatsheetSourceDomainContacts => 'Contacts';

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
  String get cheatsheetRowLicencePhoto => 'Driver\'s licence';

  @override
  String get cheatsheetRowInsuranceCard => 'Insurance card';

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
  String cheatsheetTileSubtitle(String group, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows',
      one: '1 row',
    );
    return '$group · $_temp0';
  }

  @override
  String cheatsheetTileSemantics(String title, String group, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows',
      one: '1 row',
    );
    return '$title, $group, $_temp0';
  }

  @override
  String get cheatsheetChipAll => 'All';

  @override
  String get cheatsheetLookTitle => 'Look';

  @override
  String get cheatsheetLookTheme => 'Colour';

  @override
  String get cheatsheetLookPattern => 'Pattern';

  @override
  String get cheatsheetLookIcon => 'Icon';

  @override
  String get cheatsheetLookCover => 'Cover photo';

  @override
  String get cheatsheetLookLayout => 'Layout';

  @override
  String get cheatsheetLookReset => 'Reset look';

  @override
  String get cheatsheetLayoutFacts => 'Facts';

  @override
  String get cheatsheetLayoutKeyPoints => 'Key points';

  @override
  String get cheatsheetThemeBlue => 'Blue';

  @override
  String get cheatsheetThemeGreen => 'Green';

  @override
  String get cheatsheetThemeOrange => 'Orange';

  @override
  String get cheatsheetThemeRed => 'Red';

  @override
  String get cheatsheetThemePurple => 'Purple';

  @override
  String get cheatsheetThemeTeal => 'Teal';

  @override
  String get cheatsheetThemePink => 'Pink';

  @override
  String get cheatsheetThemeAmber => 'Amber';

  @override
  String get cheatsheetThemeSlate => 'Slate';

  @override
  String get cheatsheetThemeIndigo => 'Indigo';

  @override
  String get cheatsheetThemeBrown => 'Brown';

  @override
  String get cheatsheetThemeBlack => 'Black';

  @override
  String get cheatsheetPatternNone => 'Plain';

  @override
  String get cheatsheetPatternDots => 'Dots';

  @override
  String get cheatsheetPatternStripes => 'Stripes';

  @override
  String get cheatsheetPatternGrid => 'Grid';

  @override
  String get cheatsheetPatternWaves => 'Waves';

  @override
  String get cheatsheetIconChoose => 'Choose icon';

  @override
  String get cheatsheetCoverAdd => 'Add cover';

  @override
  String get cheatsheetCoverChange => 'Change cover';

  @override
  String get cheatsheetCoverRemove => 'Remove cover';

  @override
  String get cheatsheetCoverCamera => 'Take a photo';

  @override
  String get cheatsheetCoverLibrary => 'Choose from photos';

  @override
  String get cheatsheetCoverScan => 'Scan a document';

  @override
  String get cheatsheetCoverFailed => 'Could not add that photo.';

  @override
  String get cheatsheetEmojiPickerTitle => 'Choose an emoji';

  @override
  String get cheatsheetEmojiSearchHint => 'Search in English or Chinese';

  @override
  String get cheatsheetEmojiCustomLabel => 'Or type any emoji';

  @override
  String get cheatsheetEmojiUse => 'Use';

  @override
  String get cheatsheetEmojiInvalid => 'Enter one emoji.';

  @override
  String get cheatsheetEmojiClear => 'No emoji';

  @override
  String get cheatsheetEmojiNoMatches => 'No emoji match that search.';

  @override
  String get cheatsheetEmojiGroupVehicle => 'Vehicle';

  @override
  String get cheatsheetEmojiGroupHealth => 'Health';

  @override
  String get cheatsheetEmojiGroupHome => 'Home';

  @override
  String get cheatsheetEmojiGroupBooks => 'Books & learning';

  @override
  String get cheatsheetEmojiGroupWork => 'Work';

  @override
  String get cheatsheetEmojiGroupTravel => 'Travel';

  @override
  String get cheatsheetEmojiGroupMoney => 'Money';

  @override
  String get cheatsheetEmojiGroupMisc => 'Misc';

  @override
  String get cheatsheetRowEmojiTooltip => 'Row emoji';

  @override
  String get cheatsheetTileProtectedSemantics => ', protected';

  @override
  String get cheatsheetTileCoverLockedSemantics => ', cover locked';

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
  String get onboardingHmmCloud => 'Hmm cloud (server)';

  @override
  String get onboardingHmmCloudSubtitle =>
      'Sign in or register a Hmm account; your data lives on the Hmm server.';

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
  String get vehicleAdd => 'Add vehicle';

  @override
  String get automobileHubTitle => 'Automobile';

  @override
  String get automobileHubVehicles => 'Vehicles';

  @override
  String get automobileHubLicenceTitle => 'Driver\'s licence';

  @override
  String get automobileHubLicenceAdd => 'Add your driver\'s licence';

  @override
  String get automobileHubLicenceAddHint => 'Scan the card or type it in';

  @override
  String automobileHubLicenceExpires(String date) {
    return 'expires $date';
  }

  @override
  String get automobileHubNoVehicles => 'No vehicles yet';

  @override
  String get automobileHubNoVehiclesHint =>
      'Add a vehicle to keep its gas log, insurance and service records together.';

  @override
  String automobileHubGasLogFor(String name) {
    return 'Gas log for $name';
  }

  @override
  String automobileHubNotesFor(String name) {
    return 'Notes for $name';
  }

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
  String get stationAdd => 'Add station';

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
  String get recordsGasLog => 'Gas log';

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
  String get vehicleNotesNew => 'New note';

  @override
  String vehicleNotesDomainCaption(String name) {
    return 'Automobile · $name';
  }

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
  String get contactFieldName => 'Name';

  @override
  String get contactFieldOrganization => 'Organization';

  @override
  String get contactFieldPhone => 'Phone';

  @override
  String get contactCountryCodeTitle => 'Country code';

  @override
  String get contactCountryCodeSearchHint => 'Search by country or code';

  @override
  String get contactCountryCodePlaceholder => 'Code';

  @override
  String get contactCountryCodeNone => 'No country code';

  @override
  String get contactFieldMobile => 'Cell';

  @override
  String get contactFieldFax => 'Fax';

  @override
  String get contactFieldEmail => 'Email';

  @override
  String get contactFieldAddress => 'Address';

  @override
  String get contactFieldStreet => 'Street address';

  @override
  String get contactFieldCity => 'City';

  @override
  String get contactFieldRegion => 'Province / State';

  @override
  String get contactFieldPostalCode => 'Postal code';

  @override
  String get contactFieldCountry => 'Country';

  @override
  String get contactFieldNotes => 'Notes';

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

  @override
  String get launcherDestLicence => 'Driver\'s licence';

  @override
  String get licenceTitle => 'Driver\'s licence';

  @override
  String get licenceEmpty => 'No licence saved yet';

  @override
  String get licenceAdd => 'Add licence';

  @override
  String get licenceEdit => 'Edit licence';

  @override
  String get licenceNumber => 'Licence number';

  @override
  String get licenceClass => 'Class';

  @override
  String get licenceJurisdiction => 'Province / State';

  @override
  String get licenceIssued => 'Issued';

  @override
  String get licenceExpires => 'Expires';

  @override
  String get licenceFront => 'Front';

  @override
  String get licenceBack => 'Back';

  @override
  String get licenceCaptureFront => 'Capture front';

  @override
  String get licenceCaptureBack => 'Capture back';

  @override
  String get licenceShow => 'Show licence';

  @override
  String get licenceScan => 'Scan licence';

  @override
  String get licenceScanExtraPagesIgnored =>
      'Only the first two pages were used.';

  @override
  String get licenceSaved => 'Licence saved';

  @override
  String get licenceNoImages => 'No photo captured yet';

  @override
  String get helpButtonTooltip => 'Help';

  @override
  String get helpAutomobileHubTitle => 'Automobile';

  @override
  String get helpAutomobileHubSummary =>
      'Your driver\'s licence and your vehicles in one place.';

  @override
  String get helpAutomobileHubLicenceTitle => 'Driver\'s licence';

  @override
  String get helpAutomobileHubLicenceBody =>
      'Tap the card to view or add your licence. Not shown in Cloud API mode.';

  @override
  String get helpAutomobileHubVehicleTitle => 'A vehicle';

  @override
  String get helpAutomobileHubVehicleBody =>
      'Tap a vehicle\'s row to see and edit its details.';

  @override
  String get helpAutomobileHubNotesTitle => 'Notes';

  @override
  String get helpAutomobileHubNotesBody =>
      'Opens this car\'s notes. The number is how many notes it has.';

  @override
  String get helpAutomobileHubFuelTitle => 'Gas log';

  @override
  String get helpAutomobileHubFuelBody => 'Opens this car\'s fuel log.';

  @override
  String get helpAutomobileHubManageTitle => 'Manage';

  @override
  String get helpAutomobileHubManageBody =>
      'Add vehicles and choose which ones are active.';

  @override
  String get helpVehicleNotesTitle => 'Car notes';

  @override
  String get helpVehicleNotesSummary =>
      'Everything written about this car. These notes are listed under Automobile in your notes.';

  @override
  String get helpVehicleNotesNewTitle => 'New note';

  @override
  String get helpVehicleNotesNewBody =>
      'Writes a note that is already attached to this car.';

  @override
  String get helpVehicleNotesAttachTitle => 'Attach existing note';

  @override
  String get helpVehicleNotesAttachBody =>
      'Pick a General note that isn\'t attached to anything and attach it to this car.';

  @override
  String get helpVehicleNotesDetachTitle => 'Detach';

  @override
  String get helpVehicleNotesDetachBody =>
      'Unlinks the note from this car. The note is kept and moves to General; attach it again any time.';

  @override
  String get helpVehicleNotesOpenTitle => 'Open a note';

  @override
  String get helpVehicleNotesOpenBody => 'Tap a note to read or edit it.';

  @override
  String get undoAction => 'Undo';

  @override
  String get undoNoteDetached => 'Note moved to General';

  @override
  String get undoNoteDetachFailed => 'Couldn\'t detach the note';

  @override
  String get undoNoteRestored => 'Note is back';

  @override
  String get undoNoteRestoreFailed => 'Couldn\'t undo — the note is in General';

  @override
  String get notesAttachExistingTooltip => 'Attach existing note';

  @override
  String get notesAddTooltip => 'Add note';

  @override
  String get notesDetachTooltip => 'Detach note';

  @override
  String get contactsTitle => 'Contacts';

  @override
  String get contactBirthday => 'Birthday';

  @override
  String get contactBirthdayGregorian => 'Gregorian';

  @override
  String get contactBirthdayLunar => 'Lunar';

  @override
  String get contactBirthdayLeapMonth => 'Leap month';

  @override
  String get contactBirthdayYear => 'Year (optional)';

  @override
  String get contactBirthdayNoYear => 'No year';

  @override
  String get contactBirthdayClear => 'Clear';

  @override
  String contactBirthdayAge(int age) {
    return 'Age $age';
  }

  @override
  String contactBirthdayNext(String date) {
    return 'next $date';
  }

  @override
  String get contactBirthdayNotSet => 'Not set';

  @override
  String get contactRemind => 'Remind me';

  @override
  String get contactRemindHint => 'Show on the calendar and remind on the day';

  @override
  String get contactRemindOn => 'Birthday reminder on';

  @override
  String get contactRemindOff => 'Birthday reminder off';

  @override
  String get contactRemindFailed => 'Could not change the reminder';

  @override
  String get contactRemindUndone => 'Reminder change undone';

  @override
  String get contactRemindUndoFailed => 'Could not undo the reminder change';

  @override
  String get helpContactEditBirthdayTitle => 'Birthday';

  @override
  String get helpContactEditBirthdayBody =>
      'Set a Gregorian or lunar birthday, with or without the year. Clearing it also turns off the reminder.';

  @override
  String get helpContactDetailRemindTitle => 'Remind me';

  @override
  String get helpContactDetailRemindBody =>
      'Shows this birthday on the calendar and reminds you at 9:00 on the day. You can adjust the reminder in the calendar.';

  @override
  String get contactsEmpty => 'No contacts yet';

  @override
  String get contactsSearchHint => 'Search contacts';

  @override
  String get contactAdd => 'Add contact';

  @override
  String get contactEdit => 'Edit contact';

  @override
  String get contactDelete => 'Delete contact';

  @override
  String get contactTypePerson => 'Person';

  @override
  String get contactTypeOrganization => 'Organization';

  @override
  String get contactFirstName => 'Given name';

  @override
  String get contactLastName => 'Family name';

  @override
  String get contactOrganizationName => 'Organization name';

  @override
  String get contactPhones => 'Phones';

  @override
  String get contactEmails => 'Emails';

  @override
  String get contactAddresses => 'Addresses';

  @override
  String get contactNotes => 'Notes';

  @override
  String get contactIsSelf => 'This is me';

  @override
  String get contactIsSelfHint => 'Only one contact can be marked as you';

  @override
  String get contactRelationship => 'Relationship';

  @override
  String get contactAddPhone => 'Add phone';

  @override
  String get contactAddEmail => 'Add email';

  @override
  String get contactAddAddress => 'Add address';

  @override
  String get contactNameRequired => 'A contact needs a name';

  @override
  String get contactGroupFamily => 'Family';

  @override
  String get contactGroupProviders => 'Providers';

  @override
  String get contactGroupOther => 'Other';

  @override
  String get relationshipSelf => 'Me';

  @override
  String get relationshipSpouse => 'Spouse';

  @override
  String get relationshipParent => 'Parent';

  @override
  String get relationshipChild => 'Child';

  @override
  String get relationshipFamily => 'Family';

  @override
  String get relationshipFriend => 'Friend';

  @override
  String get relationshipDoctor => 'Doctor';

  @override
  String get relationshipPharmacy => 'Pharmacy';

  @override
  String get relationshipInsurer => 'Insurer';

  @override
  String get relationshipOther => 'Other';

  @override
  String get fieldLabelMobile => 'Mobile';

  @override
  String get fieldLabelHome => 'Home';

  @override
  String get fieldLabelWork => 'Work';

  @override
  String get fieldLabelPersonal => 'Personal';

  @override
  String get fieldLabelOther => 'Other';

  @override
  String get contactsCloudApiUnavailable =>
      'Contacts are available in Local and Cloud storage modes. Switch data mode in Settings to use them.';

  @override
  String get contactsLoadFailed => 'Could not load contacts';

  @override
  String get contactNotFound => 'This contact no longer exists';

  @override
  String get contactDeactivated => 'Contact removed';

  @override
  String get contactDeactivateFailed => 'Could not remove the contact';

  @override
  String get contactDeactivateUndone => 'Contact restored';

  @override
  String get contactDeactivateUndoFailed => 'Could not restore the contact';

  @override
  String get contactAddTooltip => 'Add contact';

  @override
  String get contactEditTooltip => 'Edit contact';

  @override
  String get contactRemoveTooltip => 'Remove contact';

  @override
  String get contactRemoveFieldTooltip => 'Remove this entry';

  @override
  String get contactAddressCountry => 'Country';

  @override
  String get contactAddressCountryUS => 'United States';

  @override
  String get contactAddressCountryCA => 'Canada';

  @override
  String get contactAddressCountryCN => 'China';

  @override
  String get contactAddressCountryOther => 'Other';

  @override
  String get contactAddressStreet => 'Street address';

  @override
  String get contactAddressUnit => 'Apt / Suite / Unit';

  @override
  String get contactAddressCity => 'City';

  @override
  String get contactAddressState => 'State';

  @override
  String get contactAddressProvinceTerritory => 'Province / Territory';

  @override
  String get contactAddressZip => 'ZIP code';

  @override
  String get contactAddressPostalCode => 'Postal code';

  @override
  String get contactAddressCnProvince => 'Province';

  @override
  String get contactAddressCnDistrict => 'District / County';

  @override
  String get contactAddressCnDetail => 'Detailed address';

  @override
  String get contactAddressRegionSelect => 'Select';

  @override
  String get contactAddressRegionSearchHint => 'Search by name or code';

  @override
  String get contactAddressInvalidZip =>
      'Enter a 5-digit ZIP code, or ZIP+4 (12345-6789)';

  @override
  String get contactAddressInvalidCaPostal =>
      'Enter a postal code like A1A 1A1';

  @override
  String get contactAddressInvalidCnPostal => 'Enter a 6-digit postal code';

  @override
  String get contactAddressFixPostal =>
      'Fix the highlighted postal code to save';

  @override
  String get helpContactsTitle => 'Contacts';

  @override
  String get helpContactsSummary =>
      'Your address book: people and organizations you keep in touch with.';

  @override
  String get helpContactsAddTitle => 'Add contact';

  @override
  String get helpContactsAddBody =>
      'Creates a new contact, either a person or an organization.';

  @override
  String get helpContactsSearchTitle => 'Search';

  @override
  String get helpContactsSearchBody =>
      'Type to filter contacts by name, phone or email. Chinese names also match their pinyin, written out (zhangwei) or as initials (zw).';

  @override
  String get helpContactsSelfTitle => 'Me';

  @override
  String get helpContactsSelfBody =>
      'The Me contact holds your own details and is marked with a Me badge. Switching on \"This is me\" in the edit form marks it and files it under the Me relationship. Tap it to view or edit them.';

  @override
  String get helpContactDetailTitle => 'Contact';

  @override
  String get helpContactDetailSummary => 'Everything saved about this contact.';

  @override
  String get helpContactDetailCallTitle => 'Call';

  @override
  String get helpContactDetailCallBody => 'Tap a phone number to call it.';

  @override
  String get helpContactDetailMapTitle => 'Open in maps';

  @override
  String get helpContactDetailMapBody =>
      'Tap an address to see it on a map. Addresses written in Chinese open in Google Maps (the app if installed), which finds Chinese addresses that Apple Maps can\'t.';

  @override
  String get helpContactDetailEditTitle => 'Edit';

  @override
  String get helpContactDetailEditBody =>
      'Change this contact\'s name, details or relationship.';

  @override
  String get helpContactDetailRemoveTitle => 'Remove';

  @override
  String get helpContactDetailRemoveBody =>
      'Removes this contact from your list. Tap Undo right after to bring it back.';

  @override
  String get contactEnglishName => 'English name';

  @override
  String get contactEnglishNameHint =>
      'Optional. For cheatsheets shown to English speakers.';

  @override
  String get helpContactEditEnglishNameTitle => 'English name';

  @override
  String get helpContactEditEnglishNameBody =>
      'Shown for a name written in Chinese. Add the English name this person or organization uses, such as Michael Wang. It doesn\'t change how the contact is shown or sorted in your list, but search finds it, and a cheatsheet row can show it (pick Contact.englishName) for a card meant for English speakers.';

  @override
  String get helpContactEditTitle => 'Edit contact';

  @override
  String get helpContactEditSummary =>
      'Enter the contact\'s name and details, then save.';

  @override
  String get helpContactEditTypeTitle => 'Person or organization';

  @override
  String get helpContactEditTypeBody =>
      'Choose whether this is a person or an organization. This decides which name fields you see.';

  @override
  String get contactPhotoChoose => 'Choose photo';

  @override
  String get contactPhotoTake => 'Take photo';

  @override
  String get contactPhotoRemove => 'Remove photo';

  @override
  String get contactPhotoChange => 'Change photo';

  @override
  String get contactPhotoPickFailed => 'Couldn\'t add the photo';

  @override
  String get helpContactEditPhotoTitle => 'Photo';

  @override
  String get helpContactEditPhotoBody =>
      'Tap the circle at the top to choose a photo, take one, or remove it. It shows on the contact and in the list.';

  @override
  String get helpContactEditFieldsTitle => 'Phones, emails and addresses';

  @override
  String get helpContactEditFieldsBody =>
      'Add as many as you need and label each one, such as Mobile or Work. For phones, tap the code beside the number to pick a country calling code, or paste a number that starts with +.';

  @override
  String get helpContactEditAddressTitle => 'Addresses';

  @override
  String get helpContactEditAddressBody =>
      'Pick the country for each address. United States, Canada and China get their own fields in that country\'s order: street, unit, city, state or province (pick from the list) and ZIP or postal code; for China, province, city, district, detailed address and postal code. A postal code in the wrong format is flagged and the contact will not save until it is fixed. Switching country keeps the street, city and postal code but clears the state or province and the district. Choose Other to type any address as free text over several lines. Switching to Other keeps what you entered as text.';

  @override
  String get helpContactEditRelationshipTitle => 'Relationship';

  @override
  String get helpContactEditRelationshipBody =>
      'How this contact relates to you. For example, a family doctor is a Doctor. Choose Other to describe it yourself.';

  @override
  String get helpContactEditSelfTitle => 'This is me';

  @override
  String get helpContactEditSelfBody =>
      'Marks this contact as yourself. Only one contact can be marked.';

  @override
  String get helpCheatsheetWalletTitle => 'Cheatsheets';

  @override
  String get helpCheatsheetWalletSummary =>
      'Your cards at a glance. Tap a card to open it; use search and the chips to narrow the wallet.';

  @override
  String get helpCheatsheetWalletTilesTitle => 'Cards';

  @override
  String get helpCheatsheetWalletTilesBody =>
      'Each card shows its colour or cover photo, its icon, its title, and its group with the number of rows. Tap a card to open it.';

  @override
  String get helpCheatsheetWalletGroupsTitle => 'Group chips';

  @override
  String get helpCheatsheetWalletGroupsBody =>
      'The first row of chips shows one wallet group at a time; All shows every card again. Search works within the chosen group.';

  @override
  String get helpCheatsheetWalletTagsTitle => 'Tag chips';

  @override
  String get helpCheatsheetWalletTagsBody =>
      'Tag chips narrow the wallet to cards that carry every tag you select. Tap a tag again to drop it.';

  @override
  String get helpCheatsheetWalletLockTitle => 'Lock badge';

  @override
  String get helpCheatsheetWalletLockBody =>
      'A lock marks a protected card. A 🔒 means its cover photo is locked in the vault: the card shows its colour instead, and opening the card lets you unlock the photo.';

  @override
  String get helpCheatsheetDetailTitle => 'Cheatsheet';

  @override
  String get helpCheatsheetDetailSummary =>
      'One card, its rows filled from your notes. Edit or delete it from the top bar.';

  @override
  String get helpCheatsheetDetailFactsTitle => 'Facts layout';

  @override
  String get helpCheatsheetDetailFactsBody =>
      'Each row shows its label with the value from your note underneath. A dash means the row is not linked yet; \"source removed\" means its note was deleted. Tap a phone number or an address to call or map it.';

  @override
  String get helpCheatsheetDetailKeyPointsTitle => 'Key points layout';

  @override
  String get helpCheatsheetDetailKeyPointsBody =>
      'Rows are numbered on the card\'s colour, each with its emoji if one was chosen, the label in bold and the value below. Values, actions and photos work as in Facts.';

  @override
  String get helpCheatsheetDetailOpenSourceTitle => 'Open the note';

  @override
  String get helpCheatsheetDetailOpenSourceBody =>
      'Tap the open button on a row to see where its value comes from. A contact opens on its contact screen; other notes open as notes. Long-press the row to see the raw note instead.';

  @override
  String get helpCheatsheetDetailHeaderTitle => 'Cover header';

  @override
  String get helpCheatsheetDetailHeaderBody =>
      'The top of the card shows its colour and pattern or its cover photo, its icon, its title, and its group with the number of rows. Change the look in the designer.';

  @override
  String get helpCheatsheetDetailLockTitle => 'Locked cover';

  @override
  String get helpCheatsheetDetailLockBody =>
      'When the cover photo is protected and the vault is locked, the header shows a lock tile instead. Tap it to unlock and see the photo.';

  @override
  String get helpCheatsheetDesignerTitle => 'Designing a cheatsheet';

  @override
  String get helpCheatsheetDesignerSummary =>
      'Name the card, choose how it looks, then point each row at a piece of a note.';

  @override
  String get helpCheatsheetDesignerLookTitle => 'Look';

  @override
  String get helpCheatsheetDesignerLookBody =>
      'Look holds the colour, pattern, icon, cover and layout. It starts open on a new card and folded on an existing one; tap its header to open or fold it. The small tile in the header previews the card as it will appear in the wallet.';

  @override
  String get helpCheatsheetDesignerIconTitle => 'Icon';

  @override
  String get helpCheatsheetDesignerIconBody =>
      'Choose an emoji for the card. Search in English or Chinese, or type any emoji yourself.';

  @override
  String get helpCheatsheetDesignerCoverTitle => 'Cover photo';

  @override
  String get helpCheatsheetDesignerCoverBody =>
      'Take a photo, choose one from your photos or scan a document to use as the card\'s background; a dark band behind the title keeps the text readable. Remove it any time and the colour comes back. Covers are available in Local and Cloud Storage modes.';

  @override
  String get helpCheatsheetDesignerLayoutTitle => 'Layout';

  @override
  String get helpCheatsheetDesignerLayoutBody =>
      'Facts shows each label beside its value. Key points numbers the rows and colours them with the card\'s theme, which suits books and documents.';

  @override
  String get helpCheatsheetDesignerSourceTitle => 'Choose a note for a row';

  @override
  String get helpCheatsheetDesignerSourceBody =>
      'Tap the link line under a row to choose where its value comes from. The Notes screen opens with its search, tags and filters; tap the note, then choose a field, a section, a photo or the whole note. Back from that step returns to the Notes screen.';

  @override
  String get helpCheatsheetDesignerRowEmojiTitle => 'Row emoji';

  @override
  String get helpCheatsheetDesignerRowEmojiBody =>
      'In Key points, each row can carry its own emoji. Switching to Facts hides them without deleting them.';

  @override
  String get helpCheatsheetDesignerResetTitle => 'Reset look';

  @override
  String get helpCheatsheetDesignerResetBody =>
      'Returns the colour, pattern, icon and layout to the template\'s defaults, removes the cover photo (in Cloud API mode the cover is kept) and clears every row emoji.';

  @override
  String get contactCustomRelationship => 'Describe the relationship';

  @override
  String get contactSaveFailed => 'Could not save the contact';

  @override
  String get settingsContactSortBy => 'Sort contacts by';

  @override
  String get settingsContactSortFamily => 'Family name';

  @override
  String get settingsContactSortGiven => 'Given name';

  @override
  String get helpContactsSortTitle => 'Sort order';

  @override
  String get helpContactsSortBody =>
      'Contacts are sorted by family name. To sort by given name instead, change Sort contacts by in Settings. Chinese names sort by their pinyin, next to Latin names.';

  @override
  String get contactNameOptions => 'More name options';

  @override
  String get contactNameOrder => 'Name order';

  @override
  String get contactNameOrderAuto => 'Auto';

  @override
  String get contactNameOrderGivenFirst => 'Given name first';

  @override
  String get contactNameOrderFamilyFirst => 'Family name first';

  @override
  String get contactPhoneticFamily => 'Family name phonetic';

  @override
  String get contactPhoneticGiven => 'Given name phonetic';

  @override
  String get contactPhoneticInvalid =>
      'Use Latin letters, spaces and apostrophes only';

  @override
  String get contactPhoneticFixToSave =>
      'Fix the highlighted phonetic name to save';

  @override
  String contactShownAs(String name) {
    return 'Shown as: $name';
  }

  @override
  String get helpContactEditNameOptionsTitle => 'More name options';

  @override
  String get helpContactEditNameOptionsBody =>
      'Chinese names are shown family name first (张伟), other names given name first (John Smith). Name order changes this for one contact. The phonetic fields set how the name is sorted and searched; left empty, the pinyin shown in grey is used. This section opens by itself for Chinese names.';

  @override
  String get notesContactTitleFallback => 'Contact';

  @override
  String get notesCalendarEventTitleFallback => 'Event';

  @override
  String get notesCheatsheetTitleFallback => 'Cheatsheet card';

  @override
  String notesCheatsheetPreview(String group, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows',
      one: '1 row',
    );
    return '$group · $_temp0';
  }

  @override
  String get notesFlag => 'Flag';

  @override
  String get notesUnflag => 'Unflag';

  @override
  String get notesManageShort => 'Manage';

  @override
  String get helpNotesListSwipesTitle => 'Swipe a note';

  @override
  String get helpNotesListSwipesBody =>
      'Swipe right to pin or unpin. Swipe left to flag it in your last-used colour, or to delete it. Deleted notes go to Recently Deleted for 30 days. Notes that belong to Contacts, Cheatsheets or Automobile show Manage instead of Delete.';

  @override
  String get notesPin => 'Pin';

  @override
  String get notesUnpin => 'Unpin';

  @override
  String get notesFlagAction => 'Flag…';

  @override
  String get notesFlagSheetTitle => 'Flag';

  @override
  String get notesClearFlag => 'Clear flag';

  @override
  String get flagColorRed => 'Red';

  @override
  String get flagColorOrange => 'Orange';

  @override
  String get flagColorYellow => 'Yellow';

  @override
  String get flagColorGreen => 'Green';

  @override
  String get flagColorBlue => 'Blue';

  @override
  String get flagColorPurple => 'Purple';

  @override
  String get flagColorGrey => 'Grey';

  @override
  String get notesPinnedLabel => 'Pinned';

  @override
  String notesFlaggedLabel(String color) {
    return 'Flagged $color';
  }

  @override
  String get notesPinFailed => 'Couldn\'t pin the note';

  @override
  String get notesFlagFailed => 'Couldn\'t flag the note';

  @override
  String get notesMovedToRecentlyDeleted => 'Note deleted';

  @override
  String get notesDeleteFailed => 'Couldn\'t delete the note';

  @override
  String get notesRestored => 'Note restored';

  @override
  String get notesRestoreFailed => 'Couldn\'t restore the note';

  @override
  String notesManageIn(String place) {
    return 'Manage in $place';
  }

  @override
  String get notesManagePlaceOwnScreen => 'its own screen';

  @override
  String get helpNoteDetailTitle => 'Note';

  @override
  String get helpNoteDetailSummary =>
      'Read a note and use the ⋯ menu to pin, flag, edit or delete it.';

  @override
  String get helpNoteDetailPinTitle => 'Pin';

  @override
  String get helpNoteDetailPinBody =>
      'Marks the note as pinned. Pins sync to your other devices. Choose Unpin to remove it.';

  @override
  String get helpNoteDetailFlagTitle => 'Flag';

  @override
  String get helpNoteDetailFlagBody =>
      'Marks the note with one of seven colours. Choose Clear flag to remove it.';

  @override
  String get helpNoteDetailDeleteTitle => 'Delete';

  @override
  String get helpNoteDetailDeleteBody =>
      'Moves the note to Recently Deleted. Tap Undo in the message to bring it back right away, or restore it from Recently Deleted within 30 days.';

  @override
  String get helpNoteDetailRestoreTitle => 'Restore';

  @override
  String get helpNoteDetailRestoreBody =>
      'A note moved to Recently Deleted shows a banner. Tap Restore to put it back in your notes.';

  @override
  String get helpNoteDetailExpandTitle => 'Full screen';

  @override
  String get helpNoteDetailExpandBody =>
      'On a wide screen, tap the full-screen button at the top left to hide the side panel and the list so the note fills the screen. Tap it again to bring them back. Notes always opens with the list showing.';

  @override
  String get notesExpandNoteTooltip => 'Full screen';

  @override
  String get notesCollapseNoteTooltip => 'Exit full screen';

  @override
  String get helpNoteDetailManageTitle => 'Manage in …';

  @override
  String get helpNoteDetailManageBody =>
      'Contacts, cheatsheet cards, cars, gas logs and other records are deleted from their own screens, not from Notes. Pin and flag still work here.';

  @override
  String get notesDensityCompact => 'Compact';

  @override
  String get notesDensityStandard => 'Standard';

  @override
  String get notesDensityRich => 'Rich';

  @override
  String notesRowSemantics(String title, String date) {
    return '$title, $date';
  }

  @override
  String notesRowSemanticsFlagged(String color) {
    return 'flagged $color';
  }

  @override
  String get notesRowSemanticsPinned => 'pinned';

  @override
  String notesRowMoreTags(String count) {
    return '+$count';
  }

  @override
  String get notesViewTooltip => 'View';

  @override
  String get notesFiltered => 'Filtered';

  @override
  String get notesSearchClearTooltip => 'Clear search';

  @override
  String get notesSearchClearAction => 'Clear search';

  @override
  String get notesNoneInView => 'No notes here';

  @override
  String get notesRetry => 'Retry';

  @override
  String get notesGroupPinned => 'Pinned';

  @override
  String get notesGroupToday => 'Today';

  @override
  String get notesGroupYesterday => 'Yesterday';

  @override
  String get notesGroupThisWeek => 'This week';

  @override
  String get notesGroupThisMonth => 'This month';

  @override
  String get notesGroupUnflagged => 'Unflagged';

  @override
  String get notesSortDateNewest => 'Date — newest first';

  @override
  String get notesSortDateOldest => 'Date — oldest first';

  @override
  String get notesSortLastModified => 'Last modified';

  @override
  String get notesSortTitle => 'Title — A → Z';

  @override
  String get notesSortFlag => 'Flag colour';

  @override
  String get notesViewRows => 'Rows';

  @override
  String get notesViewSort => 'Sort';

  @override
  String get helpNotesListTitle => 'Notes';

  @override
  String get helpNotesListSummary =>
      'Every note in one list, grouped by date, title or flag. Search, filter and choose how rows look from the top bar. Pull down to sync.';

  @override
  String get helpNotesListViewTitle => 'View';

  @override
  String get helpNotesListViewBody =>
      'Choose how much each row shows (compact, standard or rich) and how the list is sorted: by date, last modified, title or flag colour. Row style is kept on this device.';

  @override
  String get helpNotesListPinnedTitle => 'Pinned section';

  @override
  String get helpNotesListPinnedBody =>
      'Pinned notes that match the current filter and search sit at the top of every sort, and are not repeated further down. Pin a note from its ⋯ menu.';

  @override
  String get helpNotesListDatesTitle => 'Date sections';

  @override
  String get helpNotesListDatesBody =>
      'When sorted by date, notes are grouped into Today, Yesterday, This week, This month and then by month. The section header stays at the top while you scroll through it.';

  @override
  String get helpNotesListFlagsTitle => 'Flags';

  @override
  String get helpNotesListFlagsBody =>
      'A flag marks a note with a colour. Sort by flag colour to group flagged notes by colour, with unflagged notes last.';

  @override
  String get helpNotesListSearchTitle => 'Search';

  @override
  String get helpNotesListSearchBody =>
      'Type to search titles, text, tags and what a note is attached to. Matches are highlighted. The search stays applied when you come back; clear it with the × in the box.';

  @override
  String get helpNotesListFilterTitle => 'Side panel';

  @override
  String get helpNotesListFilterBody =>
      'Open the side panel (☰) to filter by Pinned, Flagged (by colour), Today, a domain, a tag or a smart filter; the numbers show how many notes each holds. Long-press one of your saved searches to rename, move or delete it. On a wide screen the panel stays open beside the list, until you hide it with the side-panel button.';

  @override
  String get helpNotesListSidebarTitle => 'Hide the side panel';

  @override
  String get helpNotesListSidebarBody =>
      'On a wide screen the side panel stays beside the list. Tap the side-panel button at the top to hide it and give the open note more room; tap it again to bring it back. Each device remembers its own choice.';

  @override
  String get notesTokenHasPhoto => 'Has photos';

  @override
  String get notesTokenHasPlace => 'Has place';

  @override
  String get notesTokenHasAttachment => 'Has attachments';

  @override
  String get notesTokenPinned => 'Pinned';

  @override
  String get notesTokenLast7d => 'Last 7 days';

  @override
  String get notesTokenLast30d => 'Last 30 days';

  @override
  String get notesTokenLast90d => 'Last 90 days';

  @override
  String notesTokenFlag(String color) {
    return '$color flag';
  }

  @override
  String notesTokenParent(String subject) {
    return 'Attached to $subject';
  }

  @override
  String notesTokenTag(String name) {
    return '#$name';
  }

  @override
  String notesTokenDateRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String notesTokenRemoved(String label) {
    return '$label (removed)';
  }

  @override
  String notesTokenRemoveTooltip(String label) {
    return 'Remove $label';
  }

  @override
  String get notesTokenUnknown => 'Unknown filter';

  @override
  String get notesRecentSearches => 'Recent searches';

  @override
  String get notesRecentSearchesClear => 'Clear';

  @override
  String get notesScopeAll => 'All notes';

  @override
  String notesScopeCurrent(String source) {
    return 'In $source';
  }

  @override
  String get notesSuggestionsHeader => 'Suggestions';

  @override
  String get helpNotesListTokensTitle => 'Search tokens';

  @override
  String get helpNotesListTokensBody =>
      'As you type, suggestions appear for tags, domains, kinds of note (such as Gas Log), flags, attached-to notes, photos, places and date ranges. Tap one to add it as a chip; tap a chip\'s ✕ (or press Backspace in an empty box on a keyboard) to remove it. While a filter is active, choose whether the search covers all notes or only that filter. Tap the empty search box to see your recent searches.';

  @override
  String get notesNoMatchesFilters => 'No notes match this search';

  @override
  String get notesSaveSearchTooltip => 'Save search';

  @override
  String get notesSaveSearchTitle => 'Save search';

  @override
  String get notesSaveSearchNameLabel => 'Name';

  @override
  String get notesSaveSearchSave => 'Save';

  @override
  String notesSavedSearchSaved(String name) {
    return 'Saved \"$name\"';
  }

  @override
  String get notesSavedSearchSaveFailed => 'Couldn\'t save the search';

  @override
  String get notesSavedSearchUpdateFailed =>
      'Couldn\'t update the saved search';

  @override
  String get notesSavedSearchesHeader => 'Saved searches';

  @override
  String get notesSavedSearchRename => 'Rename';

  @override
  String get notesSavedSearchRenameTitle => 'Rename saved search';

  @override
  String get notesSavedSearchMoveUp => 'Move up';

  @override
  String get notesSavedSearchMoveDown => 'Move down';

  @override
  String get notesSavedSearchDelete => 'Delete';

  @override
  String notesSavedSearchDeleted(String name) {
    return 'Deleted \"$name\"';
  }

  @override
  String get notesSavedSearchDeleteFailed =>
      'Couldn\'t delete the saved search';

  @override
  String notesSavedSearchRestored(String name) {
    return 'Restored \"$name\"';
  }

  @override
  String get notesSavedSearchRestoreFailed =>
      'Couldn\'t restore the saved search';

  @override
  String get notesSavedSearchMissing => 'This saved search was deleted';

  @override
  String get notesShowAllNotes => 'Show all notes';

  @override
  String get helpNotesListSavedTitle => 'Saved searches';

  @override
  String get helpNotesListSavedBody =>
      'Tap the bookmark beside the search box to save the current search, filters and tokens included. Saved searches appear in the side panel; tap one to open it, or long-press it to rename, move or delete it. They sync to your other devices.';

  @override
  String get notesSmartWithPhotos => 'With photos';

  @override
  String get notesSmartWithPlace => 'With place';

  @override
  String get notesSmartLast7d => 'Last 7 days';

  @override
  String get notesSidebarDomains => 'Domains';

  @override
  String get notesSidebarTags => 'Tags';

  @override
  String get notesSidebarSmartFilters => 'Smart filters';

  @override
  String get notesSidebarFlagged => 'Flagged';

  @override
  String get notesMenuTooltip => 'Filters and lists';

  @override
  String get notesHideSidebarTooltip => 'Hide side panel';

  @override
  String get notesShowSidebarTooltip => 'Show side panel';

  @override
  String get notesChipMoreTooltip => 'More filters';

  @override
  String get helpNotesListChipsTitle => 'Quick filters';

  @override
  String get helpNotesListChipsBody =>
      'The row under the search box switches between All, Pinned, Flagged and the domains and tags you use most; it learns from what you pick. Tap a selected chip again to go back to All, or tap ＋ to open the side panel with every filter.';

  @override
  String notesBulkDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Deleted $count notes',
      one: 'Deleted 1 note',
    );
    return '$_temp0';
  }

  @override
  String notesBulkDeletedSkipped(int count, int skipped) {
    return 'Deleted $count · $skipped skipped';
  }

  @override
  String notesBulkNothingDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'These $count notes are managed in their own screens',
      one: 'This note is managed in its own screen',
    );
    return '$_temp0';
  }

  @override
  String get notesBulkDeleteSomeFailed =>
      'Couldn\'t delete some notes. They stay selected.';

  @override
  String notesBulkRestored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Restored $count notes',
      one: 'Restored 1 note',
    );
    return '$_temp0';
  }

  @override
  String get notesBulkRestoreFailed => 'Couldn\'t restore the notes';

  @override
  String notesBulkPinPartial(int done, int total) {
    return 'Pinned $done of $total notes';
  }

  @override
  String notesBulkUnpinPartial(int done, int total) {
    return 'Unpinned $done of $total notes';
  }

  @override
  String notesBulkFlagPartial(int done, int total) {
    return 'Flagged $done of $total notes';
  }

  @override
  String notesBulkUnflagPartial(int done, int total) {
    return 'Unflagged $done of $total notes';
  }

  @override
  String notesBulkTagPartial(int done, int total) {
    return 'Tagged $done of $total notes';
  }

  @override
  String get notesBulkTagsTooltip => 'Tags';

  @override
  String get notesShareAction => 'Share…';

  @override
  String notesShareFrom(String place) {
    return 'Share from $place';
  }

  @override
  String get notesShareFailed => 'Couldn\'t share the note';

  @override
  String get notesShareVideoLabel => 'Video';

  @override
  String get notesAttachToAction => 'Attach to…';

  @override
  String notesAttached(String title) {
    return 'Attached to \"$title\"';
  }

  @override
  String get notesAttachFailed => 'Couldn\'t attach the note';

  @override
  String get notesAttachUndone => 'Attachment undone';

  @override
  String get notesAttachUndoFailed => 'Couldn\'t undo the attachment';

  @override
  String get notesSelectAction => 'Select';

  @override
  String get helpNotesListLongPressTitle => 'Touch and hold a note';

  @override
  String get helpNotesListLongPressBody =>
      'Opens a menu to pin, flag, tag, attach the note to another note, share it as text, select it, or delete it. Notes from Contacts, Cheatsheets or Automobile are shared and deleted from their own screens.';

  @override
  String notesSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
      zero: 'Select notes',
    );
    return '$_temp0';
  }

  @override
  String get notesSelectAll => 'Select All';

  @override
  String get notesDoneAction => 'Done';

  @override
  String get helpNotesListSelectTitle => 'Select several notes';

  @override
  String get helpNotesListSelectBody =>
      'Tap Edit (on Android, touch and hold a note and choose Select), then tap notes to select them. Pin, flag, tag or delete them all at once; Select All picks every note in the current list. One Undo brings back a bulk delete. Notes from Contacts, Cheatsheets or Automobile are skipped when deleting.';

  @override
  String get notesRecentlyDeletedTitle => 'Recently Deleted';

  @override
  String notesDeletesInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Deletes in $days days',
      one: 'Deletes in 1 day',
    );
    return '$_temp0';
  }

  @override
  String get notesRestoreAction => 'Restore';

  @override
  String get notesMovedToRecentlyDeletedBanner =>
      'This note was moved to Recently Deleted';

  @override
  String get notesParentDeleted => '(deleted note)';

  @override
  String get notesDeleteNow => 'Delete Now';

  @override
  String get notesDeleteNowTitle => 'Delete this note now?';

  @override
  String get notesDeleteForGoodBody =>
      'It will be removed from all your devices. This can\'t be undone.';

  @override
  String get notesEmptyAction => 'Empty…';

  @override
  String notesEmptyTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count notes now?',
      one: 'Delete 1 note now?',
    );
    return '$_temp0';
  }

  @override
  String get notesDeletedForGood => 'Note deleted for good';

  @override
  String notesEmptied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Deleted $count notes for good',
      one: 'Deleted 1 note for good',
    );
    return '$_temp0';
  }

  @override
  String notesEmptyPartial(int done, int total) {
    return 'Deleted $done of $total notes for good';
  }

  @override
  String get notesKeptLiveElsewhere =>
      'This note was restored on another device, so it was kept';

  @override
  String get notesRecentlyDeletedEmpty => 'No recently deleted notes';

  @override
  String get helpNotesRecentlyDeletedTitle => 'Recently Deleted';

  @override
  String get helpNotesRecentlyDeletedSummary =>
      'Notes you delete stay here for 30 days, then are removed for good.';

  @override
  String get helpNotesRecentlyDeletedRestoreTitle => 'Restore';

  @override
  String get helpNotesRecentlyDeletedRestoreBody =>
      'Swipe a note right and tap Restore to put it back in your notes.';

  @override
  String get helpNotesRecentlyDeletedDeleteNowTitle => 'Delete Now';

  @override
  String get helpNotesRecentlyDeletedDeleteNowBody =>
      'Swipe a note left and tap Delete Now to remove it from all your devices right away. This can\'t be undone.';

  @override
  String get helpNotesRecentlyDeletedEmptyTitle => 'Empty';

  @override
  String get helpNotesRecentlyDeletedEmptyBody =>
      'Removes every note listed here from all your devices. This can\'t be undone.';

  @override
  String get helpNotesListRecentlyDeletedTitle => 'Recently Deleted';

  @override
  String get helpNotesListRecentlyDeletedBody =>
      'Open the side panel and tap Recently Deleted to restore a deleted note within 30 days.';

  @override
  String get notesTagsAction => 'Tags…';

  @override
  String get notesTagPickerTitle => 'Tags';

  @override
  String get notesTagPickerHint => 'Find or create a tag';

  @override
  String notesTagCreate(String name) {
    return 'Create “$name”';
  }

  @override
  String get notesTagPickerEmpty => 'No tags yet. Type a name to create one.';

  @override
  String get notesTagFailed => 'Couldn\'t change the note\'s tags';

  @override
  String get notesTagCreateFailed => 'Couldn\'t create the tag';

  @override
  String get notesEditorTagsLabel => 'Tags';

  @override
  String get notesEditorTagsHint => 'Add a tag';

  @override
  String notesEditorRemoveTag(String name) {
    return 'Remove tag $name';
  }

  @override
  String get notesManageTagsTitle => 'Manage Tags';

  @override
  String get notesManageTagsRow => 'Manage tags…';

  @override
  String notesManageTagsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes',
      one: '1 note',
      zero: 'No notes',
    );
    return '$_temp0';
  }

  @override
  String get notesManageTagsEmpty =>
      'No tags yet. Add tags in a note\'s editor or from its long-press menu.';

  @override
  String get notesRenameTag => 'Rename…';

  @override
  String get notesRenameTagTitle => 'Rename Tag';

  @override
  String get notesMergeTag => 'Merge into…';

  @override
  String notesMergeTagConfirm(int count, String from, String to) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes',
      one: '1 note',
    );
    return 'Move $_temp0 from “$from” to “$to” and delete “$from”?';
  }

  @override
  String get notesMergeTagAction => 'Merge';

  @override
  String notesTagNameTaken(String name) {
    return 'A tag named “$name” already exists. Merge into it?';
  }

  @override
  String get notesDeleteTag => 'Delete…';

  @override
  String notesDeleteTagConfirm(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes',
      one: '1 note',
    );
    return 'Delete the tag “$name”? It is removed from $_temp0. The notes stay.';
  }

  @override
  String get notesManageTagsFailed => 'Couldn\'t change the tag';

  @override
  String get helpManageTagsTitle => 'Manage Tags';

  @override
  String get helpManageTagsSummary =>
      'Rename, merge or delete your tags. Changes apply to every note that has the tag.';

  @override
  String get helpManageTagsRenameTitle => 'Rename';

  @override
  String get helpManageTagsRenameBody =>
      'Tap a tag, then Rename. If the new name is taken, you can merge the two.';

  @override
  String get helpManageTagsMergeTitle => 'Merge';

  @override
  String get helpManageTagsMergeBody =>
      'Moves every note to the tag you pick and deletes the other tag.';

  @override
  String get helpManageTagsDeleteTitle => 'Delete';

  @override
  String get helpManageTagsDeleteBody =>
      'Removes the tag from its notes. The notes themselves are kept.';

  @override
  String get helpNotesListTagsTitle => 'Tags';

  @override
  String get helpNotesListTagsBody =>
      'Add tags in a note\'s editor or with Tags… on its long-press menu. Pick a tag in the side panel to see its notes; Manage tags… renames, merges or deletes them.';

  @override
  String get notesVideoLinkUnavailable => 'May no longer be available';

  @override
  String get helpNoteDetailVideoLinkTitle => 'Video links';

  @override
  String get helpNoteDetailVideoLinkBody =>
      'A YouTube or Bilibili link on its own line shows as a card. Tap it to watch in their app; the ◀ Hmm button at the top-left brings you back to this note.';

  @override
  String get notesAddVideoLinkTooltip => 'Add video link';

  @override
  String get notesAddVideoLinkTitle => 'Add video link';

  @override
  String get notesAddVideoLinkHint => 'Paste a YouTube or Bilibili link';

  @override
  String get notesAddVideoLinkAdd => 'Add';

  @override
  String get notesAddVideoLinkInvalid => 'That doesn\'t look like a link';

  @override
  String get notesVideoPlay => 'Play video';

  @override
  String get notesVideoPause => 'Pause';

  @override
  String get notesVideoFullScreen => 'Full screen';

  @override
  String get notesVideoNotOnDevice =>
      'This video is only on the device that added it, for now.';

  @override
  String get notesVideoSaveToPhotos => 'Save to Photos';

  @override
  String get notesVideoKeepOffline => 'Keep offline';

  @override
  String get notesVideoKeepOfflineFailed => 'Could not change Keep offline';

  @override
  String get notesVideoKeepOfflineFetchFailed =>
      'Couldn\'t download this video. It will try again after the next sync.';

  @override
  String get notesVideoShare => 'Share…';

  @override
  String get notesVideoRemove => 'Remove from note';

  @override
  String get notesVideoSaved => 'Saved to Photos';

  @override
  String get notesVideoPhotosDenied =>
      'Hmm can\'t add to Photos. Allow it in Settings.';

  @override
  String get notesVideoSaveFailed => 'Couldn\'t save the video';

  @override
  String get notesVideoShareFailed => 'Couldn\'t share the video';

  @override
  String get notesVideoRemoved => 'Video removed';

  @override
  String get notesVideoRemoveFailed => 'Couldn\'t remove the video';

  @override
  String get notesVideoRestored => 'Video restored';

  @override
  String get notesVideoRestoreFailed => 'Couldn\'t restore the video';

  @override
  String notesVideoUploading(String percent) {
    return 'Uploading $percent%';
  }

  @override
  String get notesVideoWaitingForWifi => 'Waiting for Wi-Fi';

  @override
  String get notesVideoUploadRetry => 'Upload will retry';

  @override
  String get notesVideoStillUploading => 'Still uploading from another device';

  @override
  String get notesVideoMobileDataTitle => 'Upload over mobile data?';

  @override
  String notesVideoMobileDataBody(String size) {
    return 'This video is $size. Uploading it now uses that much mobile data.';
  }

  @override
  String get notesVideoMobileDataUpload => 'Upload now using mobile data';

  @override
  String get notesVideoMobileDataCancel => 'Wait for Wi-Fi';

  @override
  String get notesVideoDownload => 'Download and play';

  @override
  String notesVideoDownloading(String percent) {
    return 'Downloading $percent%. Tap to cancel.';
  }

  @override
  String get notesVideoDownloadFailed => 'Couldn\'t download the video';

  @override
  String get helpNoteDetailVideoTitle => 'Videos';

  @override
  String get helpNoteDetailVideoBody =>
      'Tap a video to play it full screen. On iPad it plays in place, with play/pause, a scrub bar and a full-screen button that carries on from the same spot. With OneDrive sync, a video uploads when you\'re on Wi-Fi (tap \"Waiting for Wi-Fi\" to upload now over mobile data), other devices show \"Still uploading\" until it\'s done, then download it when you tap play. Long press it for Keep offline, Save to Photos, Share or Remove. Choose Keep offline to store it on this device for good.';

  @override
  String get notesAddVideoTooltip => 'Add video';

  @override
  String get notesVideoNeedsOneDrive => 'Videos need OneDrive sync for now';

  @override
  String get notesVideoSensitiveBlocked =>
      'Videos can\'t be added to notes with sensitive items yet';

  @override
  String get notesVideoTooLarge =>
      'This video is over 2 GB and can\'t be added';

  @override
  String get notesVideoUnsupported => 'This video format isn\'t supported';

  @override
  String get notesVideoLargeTitle => 'Large video';

  @override
  String notesVideoLargeBodyCloud(String size) {
    return 'This video is $size. It uses that much OneDrive space.';
  }

  @override
  String notesVideoLargeBodyLocal(String size) {
    return 'This video is $size. It uses that much space on this device.';
  }

  @override
  String get notesVideoAdd => 'Add';

  @override
  String get notesVideoAddFailed =>
      'Some videos couldn\'t be added and were skipped.';

  @override
  String notesVideoRemoveConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Remove $count videos from this note?',
      one: 'Remove 1 video from this note?',
    );
    return '$_temp0';
  }

  @override
  String get notesVideoRemoveConfirmRemove => 'Remove';

  @override
  String get notesVideoRemoveConfirmKeep => 'Keep';

  @override
  String get settingsVideos => 'Videos';

  @override
  String settingsVideosUsage(String used, String limit) {
    return '$used of $limit';
  }

  @override
  String get videoStorageTitle => 'Videos';

  @override
  String get videoStorageDownloaded => 'Downloaded';

  @override
  String get videoStorageKeptOffline => 'Kept offline';

  @override
  String videoStorageKeptSummary(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos · $size',
      one: '1 video · $size',
    );
    return '$_temp0';
  }

  @override
  String get videoStorageMobileData => 'Upload on mobile data';

  @override
  String get videoStorageMobileDataHint => 'Otherwise videos wait for Wi-Fi.';

  @override
  String get videoStorageClear => 'Clear downloaded videos';

  @override
  String videoStorageClearConfirm(String size) {
    return 'Remove $size of downloaded videos from this device? Kept-offline videos stay. Others download again when you play them.';
  }

  @override
  String videoStorageCleared(String size) {
    return 'Cleared $size';
  }

  @override
  String get videoStorageClearFailed => 'Couldn\'t clear downloaded videos';

  @override
  String get helpVideoStorageTitle => 'Videos';

  @override
  String get helpVideoStorageSummary =>
      'See how much space downloaded videos use on this device and control how videos upload.';

  @override
  String get helpVideoStorageDownloadedTitle => 'Downloaded';

  @override
  String get helpVideoStorageDownloadedBody =>
      'Videos fetched to play on this device. The oldest-used are cleared automatically once they pass the limit.';

  @override
  String get helpVideoStorageKeptOfflineTitle => 'Kept offline';

  @override
  String get helpVideoStorageKeptOfflineBody =>
      'Videos you chose to keep on this device. They are never cleared and do not count toward the limit.';

  @override
  String get helpVideoStorageMobileDataTitle => 'Upload on mobile data';

  @override
  String get helpVideoStorageMobileDataBody =>
      'When on, videos upload and Keep offline downloads run on mobile data. When off, they wait for Wi-Fi.';

  @override
  String get helpVideoStorageClearTitle => 'Clear downloaded videos';

  @override
  String get helpVideoStorageClearBody =>
      'Removes downloaded videos from this device. Kept-offline videos stay, and the others download again when you play them.';

  @override
  String get calendarTitle => 'Calendar';

  @override
  String get dashboardCalendarTitle => 'Calendar';

  @override
  String get dashboardCalendarDescription => 'Events and reminders';

  @override
  String get calendarToday => 'Today';

  @override
  String get calendarAddEvent => 'Add event';

  @override
  String get calendarPreviousMonth => 'Previous month';

  @override
  String get calendarNextMonth => 'Next month';

  @override
  String get calendarAllDay => 'All day';

  @override
  String get calendarEmptyDay => 'Nothing planned for this day.';

  @override
  String get calendarLoadFailed => 'Could not load the calendar.';

  @override
  String get calendarCloudApiUnavailable =>
      'The calendar is available in Local and Cloud storage modes. Switch data mode in Settings to use it.';

  @override
  String get calendarMarkDone => 'Done';

  @override
  String get calendarSkip => 'Skip';

  @override
  String get calendarStatusDone => 'Done';

  @override
  String get calendarStatusSkipped => 'Skipped';

  @override
  String get calendarStatusCancelled => 'Deleted';

  @override
  String get calendarRepeats => 'Repeats';

  @override
  String get calendarOccurrenceDone => 'Marked done';

  @override
  String get calendarOccurrenceDoneFailed => 'Could not mark it done';

  @override
  String get calendarOccurrenceDoneUndone => 'Done mark removed';

  @override
  String get calendarOccurrenceSkipped => 'Skipped';

  @override
  String get calendarOccurrenceSkippedFailed => 'Could not skip it';

  @override
  String get calendarOccurrenceSkippedUndone => 'Skip removed';

  @override
  String get calendarUndoFailed => 'Could not undo';

  @override
  String get calendarHolidays => 'Holidays';

  @override
  String get calendarHolidayDayOff => 'Day off';

  @override
  String get calendarHolidayWorkday => 'Workday';

  @override
  String get calendarHolidayHide => 'Not a day off for me';

  @override
  String calendarHolidayHidden(String name) {
    return '$name hidden';
  }

  @override
  String calendarHolidayShown(String name) {
    return '$name shown again';
  }

  @override
  String calendarHolidayHideFailed(String name) {
    return 'Couldn\'t hide $name';
  }

  @override
  String calendarHolidayShowFailed(String name) {
    return 'Couldn\'t show $name again';
  }

  @override
  String get calendarHolidayUndoFailed => 'Couldn\'t undo';

  @override
  String get calendarEdit => 'Edit';

  @override
  String get calendarDeleteThis => 'Delete this one';

  @override
  String get calendarDeleteSeries => 'Delete series';

  @override
  String get calendarSeriesDeleted => 'Event deleted';

  @override
  String get calendarSeriesDeleteFailed => 'Could not delete the event';

  @override
  String get calendarSeriesDeleteUndone => 'Event restored';

  @override
  String get calendarUnreadableEvent => 'An event could not be read';

  @override
  String get calendarUnreadableEventHint =>
      'It may have been written by a newer version of the app.';

  @override
  String get calendarPermissionBanner =>
      'Reminders are off because notification permission was declined. Turn it on in the system settings.';

  @override
  String get calendarNewEvent => 'New event';

  @override
  String get calendarEditEvent => 'Edit event';

  @override
  String get calendarSave => 'Save';

  @override
  String get calendarSaveFailed => 'Could not save the event';

  @override
  String get calendarTitleLabel => 'Title';

  @override
  String get calendarTitleRequired => 'Add a title.';

  @override
  String get calendarStartLabel => 'Starts';

  @override
  String get calendarEndLabel => 'Ends';

  @override
  String get calendarPickDate => 'Choose date';

  @override
  String get calendarPickTime => 'Choose time';

  @override
  String get calendarPickerDone => 'Done';

  @override
  String get calendarEndBeforeStart => 'The end is before the start.';

  @override
  String get calendarNotesLabel => 'Notes';

  @override
  String get calendarRepeatLabel => 'Repeat';

  @override
  String get calendarRepeatNone => 'None';

  @override
  String get calendarRepeatDaily => 'Daily';

  @override
  String get calendarRepeatWeekly => 'Weekly';

  @override
  String get calendarRepeatMonthly => 'Monthly';

  @override
  String get calendarRepeatYearly => 'Yearly';

  @override
  String get calendarRepeatEndLabel => 'End repeat';

  @override
  String get calendarRepeatEndNever => 'Never';

  @override
  String get calendarRepeatEndOnDate => 'On a date';

  @override
  String get calendarRepeatEndAfter => 'After a number of times';

  @override
  String get calendarRepeatCountLabel => 'Times';

  @override
  String get calendarRepeatFewer => 'Fewer times';

  @override
  String get calendarRepeatMore => 'More times';

  @override
  String get calendarRepeatClear => 'Clear';

  @override
  String get calendarRepeatReadOnlyHint =>
      'This repeat can\'t be changed here. Clear it to choose a new one.';

  @override
  String get calendarDoesNotRepeat => 'Does not repeat';

  @override
  String get calendarRepeatCustom => 'Custom repeat';

  @override
  String get calendarRepeatLunar => 'Lunar repeat';

  @override
  String get calendarListSeparator => ', ';

  @override
  String calendarRepeatDailyText(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Every $n days',
      one: 'Every day',
    );
    return '$_temp0';
  }

  @override
  String calendarRepeatWeeklyText(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Every $n weeks',
      one: 'Every week',
    );
    return '$_temp0';
  }

  @override
  String calendarRepeatWeeklyOnText(int n, String days) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Every $n weeks on $days',
      one: 'Every $days',
    );
    return '$_temp0';
  }

  @override
  String calendarRepeatMonthlyText(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Every $n months',
      one: 'Every month',
    );
    return '$_temp0';
  }

  @override
  String calendarRepeatMonthlyOnText(int n, String days) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Every $n months on day $days',
      one: 'Monthly on day $days',
    );
    return '$_temp0';
  }

  @override
  String calendarRepeatYearlyText(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Every $n years',
      one: 'Every year',
    );
    return '$_temp0';
  }

  @override
  String calendarRepeatOnDate(String date) {
    return 'On $date';
  }

  @override
  String calendarRepeatOnLunarDate(String date) {
    return 'On 农历$date';
  }

  @override
  String calendarRepeatLunarYearlyText(int n, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Every $n years on 农历$date',
      one: 'Every year on 农历$date',
    );
    return '$_temp0';
  }

  @override
  String calendarRepeatTimes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n times',
      one: 'once',
    );
    return '$_temp0';
  }

  @override
  String calendarRepeatUntil(String date) {
    return 'until $date';
  }

  @override
  String calendarRepeatWithLimit(String rule, String limit) {
    return '$rule, $limit';
  }

  @override
  String get calendarRemindersLabel => 'Reminders';

  @override
  String get calendarNoReminders => 'No reminders';

  @override
  String get calendarAddReminder => 'Add reminder';

  @override
  String get calendarRemoveReminder => 'Remove reminder';

  @override
  String get calendarReminderAtStart => 'At the start';

  @override
  String calendarReminderMinutes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n minutes before',
      one: '1 minute before',
    );
    return '$_temp0';
  }

  @override
  String calendarReminderHours(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n hours before',
      one: '1 hour before',
    );
    return '$_temp0';
  }

  @override
  String calendarReminderDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days before',
      one: '1 day before',
    );
    return '$_temp0';
  }

  @override
  String get calendarEditScopeTitle => 'Change which events?';

  @override
  String get calendarEditThisOccurrence => 'This occurrence';

  @override
  String get calendarEditAllOccurrences => 'All occurrences';

  @override
  String calendarFromSubsystem(String name) {
    return 'From $name';
  }

  @override
  String get calendarSubsystemDiabetes => 'Diabetes';

  @override
  String get calendarSubsystemDriverLicence => 'Driver\'s licence';

  @override
  String get calendarSubsystemAutomobile => 'Vehicle';

  @override
  String get calendarSubsystemInsurance => 'Insurance';

  @override
  String get calendarSubsystemScheduledService => 'Car service';

  @override
  String get calendarSubsystemContacts => 'Contacts';

  @override
  String calendarOpenSource(String source) {
    return 'Open $source';
  }

  @override
  String calendarLinkedChangeIn(String source) {
    return 'Change it in $source';
  }

  @override
  String get calendarOpenSourceGone => 'It\'s no longer there';

  @override
  String get helpCalendarEventLinkedTitle => 'Linked events';

  @override
  String get helpCalendarEventLinkedBody =>
      'An event kept on the calendar for a licence, vehicle, policy, service or birthday. Open goes to its source, where you change the title, date or repeat. You can change its reminders, Time Sensitive and notes here, and mark it done or skipped. It has no Delete: switch it off at the source.';

  @override
  String get helpCalendarEventEditLinkedTitle => 'Linked events';

  @override
  String get helpCalendarEventEditLinkedBody =>
      'The title, date and repeat of a linked event are set by its source and cannot be changed here. Reminders, Time Sensitive and notes can.';

  @override
  String get calendarDraftBanner =>
      'Suggested event. Approve it to keep it and get its reminders.';

  @override
  String get calendarApprove => 'Approve';

  @override
  String get calendarApproveFailed => 'Could not approve the event';

  @override
  String get calendarEventNotFound => 'This event no longer exists.';

  @override
  String get calendarEventNotFoundHint => 'It may have been deleted.';

  @override
  String get calendarEventLoadFailed => 'Could not load this event.';

  @override
  String get calendarMoreActions => 'More actions';

  @override
  String get calendarDelete => 'Delete';

  @override
  String get calendarDeleteFollowing => 'Delete this and following';

  @override
  String get calendarOccurrenceDeleted => 'Occurrence deleted';

  @override
  String get calendarOccurrenceDeleteFailed =>
      'Could not delete this occurrence';

  @override
  String get calendarOccurrenceDeleteUndone => 'Occurrence restored';

  @override
  String get calendarFollowingDeleted => 'This and following deleted';

  @override
  String get calendarFollowingDeleteFailed =>
      'Could not delete this and following';

  @override
  String get calendarFollowingDeleteUndone => 'Following occurrences restored';

  @override
  String get calendarOccurrenceLabel => 'This occurrence';

  @override
  String get helpCalendarEventTitle => 'Event';

  @override
  String get helpCalendarEventSummary =>
      'One event: when it is, how it repeats, its reminders and notes.';

  @override
  String get helpCalendarEventEditTitle => 'Edit';

  @override
  String get helpCalendarEventEditBody =>
      'Opens the editor. For a repeating event you choose to change this occurrence or all of them.';

  @override
  String get helpCalendarEventDoneTitle => 'Done and Skip';

  @override
  String get helpCalendarEventDoneBody =>
      'Mark the occurrence you opened as done or skipped. Its reminder stops. Undo is offered for a few seconds.';

  @override
  String get helpCalendarEventApproveTitle => 'Approve';

  @override
  String get helpCalendarEventApproveBody =>
      'A suggested event has no reminders until you approve it.';

  @override
  String get helpCalendarEventDeleteTitle => 'Delete';

  @override
  String get helpCalendarEventDeleteBody =>
      'Delete just this occurrence, this one and all after it, or the whole series. Undo is offered for a few seconds.';

  @override
  String get helpCalendarEventEditScreenTitle => 'Edit event';

  @override
  String get helpCalendarEventEditScreenSummary =>
      'Set the title, time, repeat and reminders, then tap Save.';

  @override
  String get helpCalendarEventEditAllDayTitle => 'All day';

  @override
  String get helpCalendarEventEditAllDayBody =>
      'An all-day event has a date and no time. Its reminders count from 09:00 on the day.';

  @override
  String get helpCalendarEventEditTimeTitle => 'Starts and ends';

  @override
  String get helpCalendarEventEditTimeBody =>
      'Tap the date or the time to change it. The end cannot be before the start. A one-off event stays at its real moment if you travel; a repeating one keeps its clock time.';

  @override
  String get helpCalendarEventEditRepeatTitle => 'Repeat';

  @override
  String get helpCalendarEventEditRepeatBody =>
      'Choose how often it repeats and when the repeat ends. A yearly repeat can follow the lunar date (农历) of the start day: a leap-month date falls in the normal month in other years, and day 30 falls on day 29 when that month is short. A repeat set elsewhere is shown as Custom or Lunar and can only be cleared.';

  @override
  String get helpCalendarEventEditRemindersTitle => 'Reminders';

  @override
  String get helpCalendarEventEditRemindersBody =>
      'Add or remove reminders. They ring on devices where Remind on this device is on.';

  @override
  String get calendarTimeSensitive => 'Time Sensitive';

  @override
  String get calendarTimeSensitiveSubtitle => 'Breaks through Focus';

  @override
  String get helpCalendarEventEditTimeSensitiveTitle => 'Time Sensitive';

  @override
  String get helpCalendarEventEditTimeSensitiveBody =>
      'Lets this event\'s reminders break through Focus on iPhone. Off by default. It needs a reminder on this device, and applies to every occurrence.';

  @override
  String get calendarEventTitle => 'Event';

  @override
  String get helpCalendarTitle => 'Calendar';

  @override
  String get helpCalendarSummary =>
      'Your events by month and by day. Pick a day to see what is planned.';

  @override
  String get helpCalendarAddTitle => 'Add event';

  @override
  String get helpCalendarAddBody => 'Creates a new event on the selected day.';

  @override
  String get helpCalendarMonthTitle => 'Month grid';

  @override
  String get helpCalendarMonthBody =>
      'Tap a day to see its events. A dot marks a day with events. Use the arrows to change month. With Show lunar calendar on (Settings), each day also shows its 农历 date, 节气 or festival.';

  @override
  String get helpCalendarTodayTitle => 'Today';

  @override
  String get helpCalendarTodayBody => 'Jumps back to today.';

  @override
  String get helpCalendarSwipeTitle => 'Swipe an event';

  @override
  String get helpCalendarSwipeBody =>
      'Swipe right to mark it done, left to skip it. Undo is offered for a few seconds.';

  @override
  String get helpCalendarHoldTitle => 'Touch and hold an event';

  @override
  String get helpCalendarHoldBody =>
      'Opens a menu to edit the event, delete just this one, or delete the whole series.';

  @override
  String get calendarOpenSettings => 'Open Settings';

  @override
  String get settingsCalendarTitle => 'Calendar';

  @override
  String get settingsCalendarRemindOnDevice => 'Remind on this device';

  @override
  String get settingsCalendarRemindOnDeviceSubtitle =>
      'Show calendar reminders as notifications on this device. Set per device; not synced.';

  @override
  String get settingsCalendarShowLunar => 'Show lunar calendar';

  @override
  String get settingsCalendarShowLunarSubtitle =>
      '农历 dates, 节气 and festivals on the month grid. Synced across your devices.';

  @override
  String get calendarRemindersTitle => 'Reminders';

  @override
  String get calendarRemindersEmpty => 'No reminders in the last 7 days';

  @override
  String get calendarRemindersLoadFailed => 'Could not load reminders.';

  @override
  String calendarRemindersFiredAt(String time) {
    return 'Fired $time';
  }

  @override
  String get dashboardRemindersTooltip => 'Reminders';

  @override
  String get helpCalendarRemindersTitle => 'Reminders';

  @override
  String get helpCalendarRemindersSummary =>
      'Reminders that fired on this device in the last 7 days, newest first.';

  @override
  String get helpCalendarRemindersOpenTitle => 'Open a reminder';

  @override
  String get helpCalendarRemindersOpenBody =>
      'Tap a row to open that occurrence of the event, where you can mark it done or skip it.';

  @override
  String get helpCalendarRemindersBellTitle => 'Bell on the home screen';

  @override
  String get helpCalendarRemindersBellBody =>
      'The bell shows how many reminders fired since you last opened this list, as does the app icon. Opening the list clears both. The bell is hidden when Remind on this device is off.';

  @override
  String get calendarHolidaysAdd => 'Add country';

  @override
  String get calendarHolidaysWholeCountry => 'Whole country';

  @override
  String calendarHolidaysUpdated(String date) {
    return 'Updated $date';
  }

  @override
  String calendarHolidaysNotPublished(int year) {
    return '$year not published yet';
  }

  @override
  String get calendarHolidaysOffline =>
      'Can\'t load countries. Check your connection.';

  @override
  String calendarHolidaysRemoved(String name) {
    return '$name removed';
  }

  @override
  String calendarHolidaysRemoveFailed(String name) {
    return 'Couldn\'t remove $name';
  }

  @override
  String calendarHolidaysRestored(String name) {
    return '$name restored';
  }

  @override
  String get calendarHolidaysMine => 'My holidays';

  @override
  String get calendarHolidaysSearch => 'Search';

  @override
  String get helpCalendarHolidaysTitle => 'Holidays';

  @override
  String get helpCalendarHolidaysSummary =>
      'Choose which countries\' public holidays appear on the calendar. The list is shared across your devices.';

  @override
  String get helpCalendarHolidaysAddTitle => 'Add a country';

  @override
  String get helpCalendarHolidaysAddBody =>
      'Pick a country, then a state or province if it has its own holidays, or Whole country. Each one gets its own colour on the calendar.';

  @override
  String get helpCalendarHolidaysRemoveTitle => 'Remove a country';

  @override
  String get helpCalendarHolidaysRemoveBody =>
      'Swipe a row sideways to remove it. Tap Undo straight away to bring it back with its colour and place in the list.';

  @override
  String get helpCalendarHolidaysMineTitle => 'My holidays';

  @override
  String get helpCalendarHolidaysMineBody =>
      'Add your own days, such as birthdays or a company day off, and bring back holidays you hid.';

  @override
  String get calendarMyHolidaysAdd => 'Add holiday';

  @override
  String get calendarMyHolidaysEdit => 'Edit holiday';

  @override
  String get calendarMyHolidaysName => 'Name';

  @override
  String get calendarMyHolidaysOnce => 'One-time';

  @override
  String get calendarMyHolidaysYearly => 'Every year';

  @override
  String get calendarMyHolidaysEveryYear => 'Every year';

  @override
  String get calendarMyHolidaysStart => 'Start date';

  @override
  String get calendarMyHolidaysEnd => 'End date (optional)';

  @override
  String get calendarMyHolidaysDayOff => 'Day off';

  @override
  String calendarMyHolidaysDeleted(String name) {
    return '$name deleted';
  }

  @override
  String calendarMyHolidaysDeleteFailed(String name) {
    return 'Couldn\'t delete $name';
  }

  @override
  String calendarMyHolidaysRestored(String name) {
    return '$name restored';
  }

  @override
  String get calendarMyHolidaysHiddenSection => 'Hidden holidays';

  @override
  String get calendarMyHolidaysShowAgain => 'Show again';

  @override
  String get helpCalendarMyHolidaysTitle => 'My holidays';

  @override
  String get helpCalendarMyHolidaysSummary =>
      'Your own special days, and the downloaded holidays you chose to hide. Both are shared across your devices.';

  @override
  String get helpCalendarMyHolidaysAddTitle => 'Add a holiday';

  @override
  String get helpCalendarMyHolidaysAddBody =>
      'Add a single day, a range of days, or a day that repeats every year. Choose whether it is a day off. Tap an entry to edit it, or swipe it sideways to delete it; Undo brings it back.';

  @override
  String get helpCalendarMyHolidaysHiddenTitle => 'Hidden holidays';

  @override
  String get helpCalendarMyHolidaysHiddenBody =>
      'Holidays you hid from a day\'s details are listed here. Tap Show again to bring one back on the calendar.';

  @override
  String get helpCalendarHolidaysMarksTitle => 'Holidays on the calendar';

  @override
  String get helpCalendarHolidaysMarksBody =>
      'An umbrella or sun mark is a day off and a briefcase mark is a make-up workday, in the country\'s colour. Several countries show as coloured dots. Open a day to see each holiday, and tap Hide on one that is wrong for you. The Holidays button chooses the countries.';

  @override
  String get calendarMyHolidaysSaveFailed => 'Couldn\'t save the holiday';

  @override
  String get calendarLinkedLicenceExpiry => 'Driver\'s licence expires';

  @override
  String calendarLinkedRegistrationExpiry(String vehicle) {
    return '$vehicle registration expires';
  }

  @override
  String calendarLinkedInsuranceExpiry(String vehicle) {
    return '$vehicle insurance expires';
  }

  @override
  String calendarLinkedServiceDue(String vehicle, String service) {
    return '$vehicle: $service due';
  }

  @override
  String calendarLinkedBirthday(String name) {
    return '$name\'s birthday';
  }

  @override
  String calendarLinkedTurnsAge(int age) {
    return 'turns $age';
  }

  @override
  String get activityKindWalk => 'Walk';

  @override
  String get activityKindRun => 'Run';

  @override
  String get activityKindCycling => 'Cycling';

  @override
  String get activityKindSwim => 'Swim';

  @override
  String get activityKindGym => 'Gym';

  @override
  String get activityKindYoga => 'Yoga';

  @override
  String get activityKindOther => 'Other';

  @override
  String get activityKindReading => 'Reading';

  @override
  String get activityKindCoding => 'Coding';

  @override
  String get activityAreaHealth => 'Health';

  @override
  String get activityAreaReading => 'Reading';

  @override
  String get activityAreaDevelopment => 'Development';

  @override
  String get activityIntensityLight => 'Light';

  @override
  String get activityIntensityModerate => 'Moderate';

  @override
  String get activityIntensityVigorous => 'Vigorous';

  @override
  String get activityTitle => 'Activity';

  @override
  String get activityLogAction => 'Log activity';

  @override
  String get activityEmpty => 'No activities in this period.';

  @override
  String get activityFilterAll => 'All';

  @override
  String get activityToday => 'Today';

  @override
  String get activityYesterday => 'Yesterday';

  @override
  String get activityLoadEarlier => 'Load earlier';

  @override
  String get activityDeleted => 'Activity deleted';

  @override
  String get activityDeleteFailed => 'Couldn\'t delete the activity';

  @override
  String get activityDeleteUndone => 'Activity restored';

  @override
  String get activityUndoFailed => 'Couldn\'t undo';

  @override
  String get activityDraftLabel => 'Draft';

  @override
  String get activityCloudApiUnavailable =>
      'The activity log isn\'t available in Cloud API mode yet. Switch to Local or Cloud Storage in Settings to use it.';

  @override
  String get activityNotAvailableShort => 'Not available';

  @override
  String get activityLoadFailed => 'Couldn\'t load activities.';

  @override
  String activityMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String activityHours(int hours) {
    return '$hours h';
  }

  @override
  String activityHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get dashboardActivityTitle => 'Activity';

  @override
  String activityActiveToday(String duration) {
    return 'Active today: $duration';
  }

  @override
  String get activityNoneToday => 'No activity yet today';

  @override
  String get helpActivityTitle => 'Activity';

  @override
  String get helpActivitySummary =>
      'A log of what you did: walks, workouts, reading and coding sessions, grouped by the day each one happened.';

  @override
  String get helpActivityAddTitle => 'Log an activity';

  @override
  String get helpActivityAddBody =>
      'Adds a new entry: pick what you did, how long it took and when it ended. Tap an entry to change it.';

  @override
  String get helpActivityFilterTitle => 'Filter by area';

  @override
  String get helpActivityFilterBody =>
      'The chips at the top show only Health, Reading or Development entries. All shows everything.';

  @override
  String get helpActivityDeleteTitle => 'Delete an entry';

  @override
  String get helpActivityDeleteBody =>
      'Touch and hold an entry, or swipe it left, to delete it. Tap Undo in the message to bring it back.';

  @override
  String get helpActivityEditTitle => 'Log activity';

  @override
  String get helpActivityEditSummary =>
      'Record one activity: what you did, for how long and when.';

  @override
  String get helpActivityEditKindTitle => 'Kind';

  @override
  String get helpActivityEditKindBody =>
      'Choose what you did, such as Walk, Gym or Reading. The kind decides which other fields are offered.';

  @override
  String get activityNewTitle => 'Log activity';

  @override
  String get activityEditTitle => 'Edit activity';

  @override
  String get activityKindLabel => 'Kind';

  @override
  String get activityDurationLabel => 'Duration';

  @override
  String get activityDurationCustom => 'Custom';

  @override
  String get activityEndedLabel => 'Ended';

  @override
  String get activityEndedInFuture => 'The end time can\'t be in the future.';

  @override
  String get activityIntensityLabel => 'Intensity';

  @override
  String get activityDistanceLabel => 'Distance';

  @override
  String get activityLinkLabel => 'Linked note';

  @override
  String get activityLinkNone => 'None';

  @override
  String get activityLinkRemoved => 'Note removed';

  @override
  String get activityLinkClear => 'Remove link';

  @override
  String get activityNotesLabel => 'Notes';

  @override
  String get activitySave => 'Save';

  @override
  String get activityDelete => 'Delete activity';

  @override
  String get activityUnknownKind => 'Unknown kind';

  @override
  String get helpActivityEditDurationTitle => 'Duration';

  @override
  String get helpActivityEditDurationBody =>
      'Tap 15, 30, 45 or 60 minutes, or Custom to type any length up to 24 hours. Save is available once a kind and a duration are set.';

  @override
  String get helpActivityEditEndedTitle => 'Ended';

  @override
  String get helpActivityEditEndedBody =>
      'When you finished. It starts at now; the start time is worked out as the end time minus the duration. It can\'t be in the future.';

  @override
  String get helpActivityEditLinkTitle => 'Linked note';

  @override
  String get helpActivityEditLinkBody =>
      'Link a note, such as the book you read or the project you worked on. If that note is deleted later, the entry shows Note removed and keeps the link.';

  @override
  String get activityDurationMinutes => 'Minutes';

  @override
  String get activitySaveFailed => 'Couldn\'t save the activity';

  @override
  String get activityPlannedLabel => 'Planned session';

  @override
  String get activityPlannedNone => 'None';

  @override
  String get activityPlannedMarkFailed =>
      'Saved, but the calendar session couldn\'t be marked done';

  @override
  String activityLoggedLine(String summary) {
    return 'Logged: $summary';
  }

  @override
  String get helpActivityEditPlannedTitle => 'Planned session';

  @override
  String get helpActivityEditPlannedBody =>
      'Pick the calendar session this was, from yesterday until 12 hours from now. The start moves to the session\'s time and saving marks the session done. Removing the link later doesn\'t undo that.';

  @override
  String get helpCalendarEventLoggedTitle => 'Logged';

  @override
  String get helpCalendarEventLoggedBody =>
      'Shows the activity logged for this session. Tap it to open the activity.';

  @override
  String get glucoseTitle => 'Glucose';

  @override
  String get glucoseLogAction => 'Log a reading';

  @override
  String get glucoseImportNow => 'Import now';

  @override
  String get glucoseImportFromHealth => 'Import from Apple Health';

  @override
  String get glucoseEmpty => 'No readings in the last 90 days.';

  @override
  String get glucoseToday => 'Today';

  @override
  String get glucoseYesterday => 'Yesterday';

  @override
  String get glucoseDeleted => 'Reading deleted';

  @override
  String get glucoseDeleteFailed => 'Couldn\'t delete the reading';

  @override
  String get glucoseDeleteUndone => 'Reading restored';

  @override
  String get glucoseUndoFailed => 'Couldn\'t undo';

  @override
  String get glucoseCloudApiUnavailable =>
      'The glucose log isn\'t available in Cloud API mode yet. Switch to Local or Cloud Storage in Settings to use it.';

  @override
  String get glucoseLoadFailed => 'Couldn\'t load readings.';

  @override
  String get glucoseSetRange => 'Set your target range';

  @override
  String glucoseTargetRange(String low, String high, String unit) {
    return 'Target $low–$high $unit';
  }

  @override
  String get glucoseNothingFound =>
      'No readings found. If you use a meter app, check Health → Sharing → Apps → Hmm.';

  @override
  String glucoseImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Imported $count readings',
      one: 'Imported 1 reading',
    );
    return '$_temp0';
  }

  @override
  String get glucoseImportBusy => 'Sync in progress. Try again in a moment.';

  @override
  String get glucoseImportFailed => 'Couldn\'t import readings.';

  @override
  String get glucoseImportWaitingForSync =>
      'Waiting for the first sync. Try again in a moment.';

  @override
  String get glucoseContextFasting => 'Fasting';

  @override
  String get glucoseContextBeforeMeal => 'Before meal';

  @override
  String get glucoseContextAfterMeal => 'After meal';

  @override
  String get glucoseContextBedtime => 'Bedtime';

  @override
  String get glucoseContextOther => 'Other';

  @override
  String get glucoseBandBelow => 'Below';

  @override
  String get glucoseBandIn => 'In range';

  @override
  String get glucoseBandAbove => 'Above';

  @override
  String get glucoseFromHealth => 'From Apple Health';

  @override
  String get glucoseTyped => 'Typed';

  @override
  String glucoseNoteTitle(String value) {
    return 'Glucose $value';
  }

  @override
  String get helpGlucoseTitle => 'Glucose';

  @override
  String get helpGlucoseSummary =>
      'Your blood glucose readings, grouped by the day each was taken. Readings can be typed in or imported from Apple Health.';

  @override
  String get helpGlucoseAddTitle => 'Log a reading';

  @override
  String get helpGlucoseAddBody =>
      'Adds a reading by hand: the value, the time and an optional tag. Tap a reading to change it.';

  @override
  String get helpGlucoseImportTitle => 'Import now';

  @override
  String get helpGlucoseImportBody =>
      'On iPhone, copies new blood glucose readings from Apple Health. Readings you deleted stay deleted.';

  @override
  String get helpGlucoseRangeTitle => 'Target range';

  @override
  String get helpGlucoseRangeBody =>
      'Set your own low and high so each reading shows whether it is below, in or above your range. Hmm suggests no range.';

  @override
  String get helpGlucoseDeleteTitle => 'Delete a reading';

  @override
  String get helpGlucoseDeleteBody =>
      'Touch and hold a reading, or swipe it left, to delete it. Tap Undo in the message to bring it back.';

  @override
  String get glucoseNewTitle => 'Log a reading';

  @override
  String get glucoseEditTitle => 'Reading';

  @override
  String get glucoseSave => 'Save';

  @override
  String get glucoseSaveFailed => 'Couldn\'t save the reading.';

  @override
  String get glucoseValueLabel => 'Glucose';

  @override
  String glucoseValueOutOfRange(String min, String max, String unit) {
    return 'Enter a value from $min to $max $unit.';
  }

  @override
  String get glucoseTimeLabel => 'Time';

  @override
  String get glucoseTagLabel => 'Tag';

  @override
  String get glucoseTagClear => 'Clear tag';

  @override
  String get glucoseNotesLabel => 'Notes';

  @override
  String glucoseFromHealthSource(String source) {
    return 'From Apple Health · $source';
  }

  @override
  String get glucoseRangeLow => 'Low';

  @override
  String get glucoseRangeHigh => 'High';

  @override
  String get glucoseRangeSave => 'Save';

  @override
  String get glucoseRangeSaveFailed => 'Couldn\'t save the target range.';

  @override
  String get glucoseRangeOrderError => 'Low must be below high.';

  @override
  String get glucoseRangeClear => 'Clear target range';

  @override
  String get glucoseDisplayUnitLabel => 'Display unit';

  @override
  String get glucoseImportOnDeviceLabel =>
      'Import from Apple Health on this device';

  @override
  String get glucoseSettingsSubtitle => 'Target range and units';

  @override
  String get helpGlucoseEditTitle => 'Glucose reading';

  @override
  String get helpGlucoseEditSummary =>
      'Type a reading, or change the tag and notes of one you already have. A reading imported from Apple Health keeps its value and time.';

  @override
  String get helpGlucoseEditValueTitle => 'Value and unit';

  @override
  String get helpGlucoseEditValueBody =>
      'The reading is stored in the unit you type it in. Values from 20 to 600 mg/dL (1.1 to 33.3 mmol/L) are accepted.';

  @override
  String get helpGlucoseEditTimeTitle => 'Time';

  @override
  String get helpGlucoseEditTimeBody =>
      'When the reading was taken. It starts at the current time.';

  @override
  String get helpGlucoseEditTagTitle => 'Tag';

  @override
  String get helpGlucoseEditTagBody =>
      'Optionally say when you measured: fasting, before or after a meal, bedtime or other. Tap the chosen tag again to clear it.';

  @override
  String get helpGlucoseRangeSummary =>
      'Your own target range, the unit readings are shown in, and, on iPhone, whether this device imports from Apple Health.';

  @override
  String get helpGlucoseRangeLowHighTitle => 'Low and high';

  @override
  String get helpGlucoseRangeLowHighBody =>
      'Both ends count as in range. Low must be below high. The unit under the fields is the one they are read in. Hmm suggests no range.';

  @override
  String get helpGlucoseRangeUnitTitle => 'Display unit';

  @override
  String get helpGlucoseRangeUnitBody =>
      'mg/dL or mmol/L. Readings are shown in this unit. The choice syncs to your other devices.';

  @override
  String get helpGlucoseRangeImportTitle => 'Import on this device';

  @override
  String get helpGlucoseRangeImportBody =>
      'Turns the automatic Apple Health import on or off for this device only.';

  @override
  String glucoseTileLast(String value, String when) {
    return 'Last: $value · $when';
  }

  @override
  String get glucoseTileNone => 'No readings yet';

  @override
  String get settingsHomeScreen => 'Home screen';

  @override
  String get settingsHomeScreenSubtitle =>
      'Choose which tiles show on the home screen';

  @override
  String get homeScreenSettingsHint =>
      'Hidden features stay reachable by typing / in the home search. These choices are the same on all your devices.';

  @override
  String get homeScreenSettingsLastVisible =>
      'At least one tile must stay visible.';

  @override
  String get helpHomeScreenSettingsTitle => 'Home screen';

  @override
  String get helpHomeScreenSettingsSummary =>
      'Choose which tiles appear on the home screen. The choice is shared across your devices.';

  @override
  String get helpHomeScreenSettingsSwitchTitle => 'Tile switch';

  @override
  String get helpHomeScreenSettingsSwitchBody =>
      'Turn a tile off to hide it from the home screen, or on to show it again. Hidden features can still be opened from the home search by typing /.';

  @override
  String get helpHomeScreenSettingsLastTitle => 'The last tile';

  @override
  String get helpHomeScreenSettingsLastBody =>
      'The only visible tile cannot be turned off, so the home screen is never empty.';

  @override
  String hmmSignInSheetTitle(String feature) {
    return 'Sign in to Hmm to use $feature';
  }

  @override
  String get hmmSignInSheetBody =>
      'Your data stays on this device. Signing in only unlocks this feature.';

  @override
  String get hmmSignInAction => 'Sign in';

  @override
  String get hmmFeatureReceiptScan => 'Cloud AI receipt scan';

  @override
  String get hmmFeatureAddressLookup => 'address lookup';

  @override
  String get hmmFeatureExchangeRates => 'exchange rates';

  @override
  String get hmmFeatureCloud => 'Hmm cloud';

  @override
  String get gasLogRatesNeedSignIn => 'Sign in to Hmm to convert currencies';
}
