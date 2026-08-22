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
  String get settingsLauncher => '启动器';

  @override
  String get settingsLauncherSubtitle => '固定常用项并设置搜索别名';

  @override
  String get settingsGeoCapture => '为新笔记添加位置';

  @override
  String get settingsGeoCaptureSubtitle => '创建笔记时记录你所在的位置';

  @override
  String get settingsQuickPanel => '快捷面板';

  @override
  String get settingsQuickPanelSubtitle => '长按右下角可打开主页和快速同步';

  @override
  String get settingsQuickPanelReplay => '使用演示';

  @override
  String get settingsQuickPanelReplaySubtitle => '重新播放快捷面板提示';

  @override
  String settingsSwitchedToMode(String mode) {
    return '已切换为$mode。重启应用后生效。';
  }

  @override
  String get settingsOneDriveClientIdMissing =>
      '未设置 OneDrive 客户端 ID。请使用 --dart-define=ONEDRIVE_CLIENT_ID=<app-id> 重新构建（参见 docs/cloud_storage_setup.md §1）。';

  @override
  String settingsAuthStateError(String error) {
    return '登录状态错误：$error';
  }

  @override
  String get settingsDatabaseLocation => '数据库位置';

  @override
  String get settingsChangeLocation => '更改位置';

  @override
  String get settingsResetToDefault => '恢复默认';

  @override
  String get settingsChooseDatabaseFolder => '选择数据库文件夹';

  @override
  String settingsDatabaseLocationSet(String path) {
    return '数据库位置已设为 $path。重启应用后生效。';
  }

  @override
  String get settingsDatabaseLocationReset => '已恢复默认位置。重启应用后生效。';

  @override
  String settingsGenericError(String error) {
    return '错误：$error';
  }

  @override
  String get settingsChooseVaultFolder => '选择保险库文件夹（例如放在 OneDrive 内）';

  @override
  String settingsVaultFolderSet(String path) {
    return '保险库文件夹已设为 $path/vault。新照片将保存在这里。';
  }

  @override
  String get settingsVaultFolderReset =>
      '保险库文件夹已恢复默认（应用文档目录）。在你选择文件夹之前，cloudStorage 模式无法同步文件内容。';

  @override
  String get settingsVaultFolderLabel => '保险库文件夹（存放照片）';

  @override
  String get settingsVaultFolderHelper =>
      '将它设在 OneDrive 文件夹内，车辆照片就能在多台设备之间自动同步。';

  @override
  String get settingsVaultFolderDefault => '默认（应用沙盒——不跨设备同步）';

  @override
  String settingsVaultPathError(String error) {
    return '保险库路径错误：$error';
  }

  @override
  String get settingsChooseFolder => '选择文件夹';

  @override
  String get settingsCleanUpPhotos => '清理无用照片';

  @override
  String get settingsCleanUpNone => '没有需要清理的无用照片。';

  @override
  String get settingsCleanUpTitle => '清理无用照片？';

  @override
  String settingsCleanUpBody(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个无用文件',
    );
    return '发现 $_temp0（$size），是取消或替换照片时遗留的。它们没有被任何车辆引用，可以安全删除。';
  }

  @override
  String settingsCleanUpDone(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个文件',
    );
    return '已回收 $_temp0（$size）。';
  }

  @override
  String settingsCleanUpFailed(String error) {
    return '清理失败：$error';
  }

  @override
  String get settingsSignedInOneDrive => '已登录 OneDrive';

  @override
  String settingsSignInOneDriveFailed(String error) {
    return 'OneDrive 登录失败：$error';
  }

  @override
  String get settingsSignedOutOneDrive => '已退出 OneDrive';

  @override
  String get settingsSyncing => '正在同步…';

  @override
  String settingsSyncSucceeded(int pushed, int pulled) {
    return '同步完成——已上传 $pushed 条 / 已下载 $pulled 条笔记';
  }

  @override
  String settingsSyncFailed(String error) {
    return '同步失败：$error';
  }

  @override
  String get settingsSyncOver => '同步网络';

  @override
  String get settingsSyncWifiOnly => '仅 WiFi';

  @override
  String get settingsSyncWifiOnlySubtitle =>
      '自动同步会等待 WiFi。使用蜂窝数据时，手动点击“立即同步”会先询问你。';

  @override
  String get settingsSyncAnyNetwork => '任意网络';

  @override
  String get settingsSyncAnyNetworkSubtitle => '自动同步可能使用蜂窝数据，超出的流量费用由你承担。';

  @override
  String get settingsVehicleInformation => '车辆信息';

  @override
  String get settingsShowRegistration => '显示行驶证卡片';

  @override
  String get settingsShowRegistrationSubtitle =>
      '如果你所在地区已不再要求定期更新车辆登记，可以关闭（例如安大略省已于 2022 年取消年检贴纸）。';

  @override
  String get settingsGasLogDefaults => '加油记录默认值';

  @override
  String get settingsDistanceUnit => '距离单位';

  @override
  String get settingsFuelUnit => '燃油单位';

  @override
  String get settingsCurrency => '货币';

  @override
  String get unitMile => '英里';

  @override
  String get unitKilometer => '公里';

  @override
  String get unitGallon => '加仑';

  @override
  String get unitLiter => '升';

  @override
  String get dataModeLocal => '本地（离线）';

  @override
  String get dataModeLocalDescription => '数据只保存在本机。不同步，也不需要账号。';

  @override
  String get dataModeCloudStorage => '云存储';

  @override
  String get dataModeCloudStorageDescription =>
      '数据保存在本地，并同步到你自己的云盘账号（OneDrive）。';

  @override
  String get dataModeCloudApi => '云端（API）';

  @override
  String get dataModeCloudApiDescription => '数据保存在本地，并与 Hmm 后端 API 同步。';

  @override
  String get vaultSectionTitle => '安全保险库';

  @override
  String get vaultSetUpTitle => '设置安全保险库';

  @override
  String get vaultSetUpSubtitle => '用密码加密敏感附件（例如行驶证、车架号照片）';

  @override
  String get vaultLockedTitle => '安全保险库——已锁定';

  @override
  String get vaultLockedSubtitle => '解锁后才能查看或添加敏感附件';

  @override
  String get vaultUnlock => '解锁';

  @override
  String get vaultOnTitle => '安全保险库——已开启';

  @override
  String get vaultOnSubtitle => '本设备上的敏感附件已解锁';

  @override
  String get vaultLockNow => '立即锁定';

  @override
  String get vaultNeedsResetTitle => '安全保险库——需要重置';

  @override
  String get vaultNeedsResetSubtitle => '无法读取保险库配置，必须重置';

  @override
  String get vaultResetTitle => '重置安全保险库';

  @override
  String get vaultResetSubtitle => '忘记密码？重置会清空保险库';

  @override
  String get vaultIncorrectPassphrase => '密码不正确。';

  @override
  String get vaultPassphrase => '密码';

  @override
  String get vaultConfirmPassphrase => '确认密码';

  @override
  String get vaultForgotWarning => '如果忘记这个密码，这些文件将无法恢复。';

  @override
  String get vaultPassphrasesDoNotMatch => '两次输入的密码不一致。';

  @override
  String get vaultSetUpAction => '设置';

  @override
  String get vaultUnlockDialogTitle => '解锁安全保险库';

  @override
  String vaultResetWarning(String token) {
    return '这会永久删除安全保险库中的所有文件，且无法撤销。请输入 $token 以确认。';
  }

  @override
  String vaultResetTypeToken(String token) {
    return '输入 $token';
  }

  @override
  String get syncStatusSyncing => '正在同步…';

  @override
  String syncStatusFailing(int count) {
    return '同步失败——最近 $count 次尝试';
  }

  @override
  String get syncStatusWaitingWifi => '等待 WiFi 后同步';

  @override
  String get syncStatusLastFailed => '上次同步失败';

  @override
  String syncStatusSynced(String when) {
    return '已于$when同步';
  }

  @override
  String get syncStatusNever => '尚未同步';

  @override
  String get syncRelativeJustNow => '刚刚';

  @override
  String syncRelativeMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 分钟前',
    );
    return '$_temp0';
  }

  @override
  String syncRelativeHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 小时前',
    );
    return '$_temp0';
  }

  @override
  String syncRelativeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天前',
    );
    return '$_temp0';
  }

  @override
  String get syncCellularTitle => '使用蜂窝数据同步？';

  @override
  String get syncCellularBody => '你的网络策略设为“仅 WiFi”，但你点击了立即同步。继续将使用蜂窝数据。';

  @override
  String get syncAnyway => '仍要同步';

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
