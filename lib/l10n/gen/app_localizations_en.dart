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
}
