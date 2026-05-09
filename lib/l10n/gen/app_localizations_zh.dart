// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Hmm 控制台';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsLanguageFollowSystem => '跟随系统';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageChinese => '中文';

  @override
  String get settingsDataStorage => '数据存储';

  @override
  String get settingsStorageMode => '存储模式';

  @override
  String get settingsCloudProvider => '云服务';

  @override
  String get settingsSignInOneDrive => '登录 OneDrive';

  @override
  String get settingsSignOutOneDrive => '退出 OneDrive';

  @override
  String get settingsSyncNow => '立即同步';

  @override
  String get commonCancel => '取消';

  @override
  String get commonSave => '保存';

  @override
  String get commonDelete => '删除';

  @override
  String get automobileRecordsInsurance => '保险';

  @override
  String get automobileRecordsServiceHistory => '维修保养记录';

  @override
  String get automobileRecordsScheduledService => '保养计划';

  @override
  String get automobileRecordsManage => '管理';

  @override
  String get automobileRecordsViewHistory => '查看记录';

  @override
  String get automobileRecordsNoActivePolicy => '没有有效的保单';

  @override
  String get automobileRecordsNoServiceRecords => '暂无保养记录';

  @override
  String get automobileRecordsNoSchedules => '尚未设置保养计划';
}
