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
  String get commonRetry => '重试';

  @override
  String get commonEdit => '编辑';

  @override
  String commonError(String error) {
    return '错误：$error';
  }

  @override
  String get gasLogTitle => '加油记录';

  @override
  String get gasLogLoadFailed => '无法加载加油记录';

  @override
  String get gasLogEmpty => '暂无加油记录';

  @override
  String get gasLogLoadMore => '加载更多';

  @override
  String get gasLogDeleteTitle => '删除加油记录';

  @override
  String get gasLogDeleteBody => '确定要删除这条加油记录吗？';

  @override
  String gasLogDeleteFailed(String error) {
    return '删除失败：$error';
  }

  @override
  String get gasLogCreated => '加油记录已创建';

  @override
  String get gasLogUpdated => '加油记录已更新';

  @override
  String gasLogOdometer(String unit) {
    return '里程表（$unit）';
  }

  @override
  String gasLogDistance(String unit) {
    return '行驶距离（$unit）';
  }

  @override
  String gasLogFuel(String unit) {
    return '加油量（$unit）';
  }

  @override
  String gasLogUnitPrice(String currency, String unit) {
    return '单价（$currency/$unit）';
  }

  @override
  String gasLogTotalPrice(String currency) {
    return '总金额（$currency）';
  }

  @override
  String get gasLogFullTank => '加满';

  @override
  String get gasLogComment => '备注（选填）';

  @override
  String get gasLogSelectStation => '请选择或输入加油站';

  @override
  String get vehicleNewTitle => '新增车辆';

  @override
  String get vehicleCreated => '车辆已创建';

  @override
  String get vehicleUpdated => '车辆已更新';

  @override
  String get vehicleNotFound => '未找到该车辆';

  @override
  String get vehicleInformation => '车辆信息';

  @override
  String get vehicleManageTitle => '管理车辆';

  @override
  String get vehicleSelectTitle => '选择车辆';

  @override
  String get vehicleManage => '管理';

  @override
  String get vehicleManageVehicles => '管理车辆';

  @override
  String get vehicleLoadFailed => '无法加载车辆';

  @override
  String get vehicleEmpty => '暂无车辆';

  @override
  String get vehicleEmptyHint => '点击 + 添加你的第一辆车。';

  @override
  String get vehicleNoneFound => '未找到车辆';

  @override
  String get vehicleNoneFoundHint => '先添加一辆车即可开始。';

  @override
  String get vehicleStatusUpdated => '车辆状态已更新';

  @override
  String vehicleActiveCount(int count) {
    return '使用中（$count）';
  }

  @override
  String vehicleInactiveCount(int count) {
    return '已停用（$count）';
  }

  @override
  String get vehicleVin => '车架号（17 位）';

  @override
  String get vehicleMaker => '制造商';

  @override
  String get vehicleBrand => '品牌';

  @override
  String get vehicleModel => '车型';

  @override
  String get vehicleTrim => '配置（选填）';

  @override
  String get vehicleYear => '年份';

  @override
  String get vehicleColor => '颜色';

  @override
  String get vehicleColorOptional => '颜色（选填）';

  @override
  String get vehiclePlate => '车牌号';

  @override
  String get vehicleTankCapacity => '油箱容量（选填）';

  @override
  String get vehicleCityMpg => '市区油耗';

  @override
  String get vehicleHwyMpg => '高速油耗';

  @override
  String get vehicleCombinedMpg => '综合油耗';

  @override
  String vehicleMeterReading(String unit) {
    return '里程表读数（$unit）';
  }

  @override
  String vehiclePurchasePrice(String currency) {
    return '购车价格（$currency）';
  }

  @override
  String get vehicleNotes => '备注';

  @override
  String get vehicleNotesOptional => '备注（选填）';

  @override
  String get vehicleMileage => '里程';

  @override
  String get vehicleRegistration => '行驶证';

  @override
  String get vehicleRegistrationExpiry => '行驶证有效期';

  @override
  String get vehicleInvalidMeterReading => '请输入有效的里程表读数';

  @override
  String get vehiclePhotoUnavailable => '照片不可用';

  @override
  String vehiclePhotoPickFailed(String error) {
    return '无法选择照片：$error';
  }

  @override
  String get vehicleEditIdentityTitle => '修改车辆识别信息？';

  @override
  String vehicleActionConfirm(String action) {
    return '$action这辆车？';
  }

  @override
  String get vehicleDeactivate => '停用';

  @override
  String get vehicleReactivate => '重新启用';

  @override
  String get vehicleDeactivateTitle => '停用这辆车？';

  @override
  String get vehicleReactivateTitle => '重新启用这辆车？';

  @override
  String vehicleDeactivateBody(String vehicle) {
    return '确定要停用$vehicle吗？';
  }

  @override
  String vehicleReactivateBody(String vehicle) {
    return '确定要重新启用$vehicle吗？';
  }

  @override
  String stationDeactivateBody(String station) {
    return '确定要停用“$station”吗？';
  }

  @override
  String stationReactivateBody(String station) {
    return '确定要重新启用“$station”吗？';
  }

  @override
  String get stationDeactivateTitle => '停用这个加油站？';

  @override
  String get stationReactivateTitle => '重新启用这个加油站？';

  @override
  String get stationTitle => '加油站';

  @override
  String get stationLoadFailed => '无法加载加油站';

  @override
  String get stationEmpty => '暂无加油站';

  @override
  String get stationEmptyHint => '点击 + 添加你的第一个加油站。';

  @override
  String stationActionConfirm(String action) {
    return '$action这个加油站？';
  }

  @override
  String get stationName => '加油站名称';

  @override
  String get stationHintCreate => '输入名称以新建加油站';

  @override
  String get stationHintSelect => '选择或输入新的加油站';

  @override
  String get stationNameRequired => '加油站名称 *';

  @override
  String get stationAddress => '地址';

  @override
  String get stationCityRequired => '城市 *';

  @override
  String get stationStateProvince => '省/州';

  @override
  String get stationCountryRequired => '国家 *';

  @override
  String get stationPostalCode => '邮政编码';

  @override
  String get stationDescription => '描述';

  @override
  String stationCreateFailed(String error) {
    return '创建加油站失败：$error';
  }

  @override
  String stationUpdateFailed(String error) {
    return '更新加油站失败：$error';
  }

  @override
  String get stationLocationCaptured => '已获取位置和地址';

  @override
  String get stationLocationNoAddress => '已获取位置（无法查询地址）';

  @override
  String get stationLocationDenied => '无法获取位置，请检查权限设置。';

  @override
  String stationLocationError(String error) {
    return '定位错误：$error';
  }

  @override
  String stationSaveFailed(String action, String error) {
    return '$action加油站失败：$error';
  }

  @override
  String get sectionIdentity => '识别信息';

  @override
  String get sectionAppearance => '外观';

  @override
  String get sectionEngine => '发动机';

  @override
  String get sectionOwnership => '拥有方式';

  @override
  String get sectionNotes => '备注';

  @override
  String get sectionChangeHistory => '变更记录';

  @override
  String get fieldDate => '日期';

  @override
  String get fuelTypeLabel => '燃油类型';

  @override
  String get fuelGradeLabel => '燃油标号';

  @override
  String get engineTypeLabel => '发动机类型';

  @override
  String get ownershipStatusLabel => '拥有方式';

  @override
  String get optionRegular => '普通';

  @override
  String get optionMidGrade => '中级';

  @override
  String get optionPremium => '高级';

  @override
  String get optionDiesel => '柴油';

  @override
  String get optionE85 => 'E85 乙醇汽油';

  @override
  String get optionElectric => '纯电动';

  @override
  String get optionOther => '其他';

  @override
  String get optionGasoline => '汽油';

  @override
  String get optionHybrid => '混合动力';

  @override
  String get optionPlugInHybrid => '插电式混合动力';

  @override
  String get optionHydrogen => '氢燃料';

  @override
  String get optionCng => '压缩天然气';

  @override
  String get optionOwned => '全款拥有';

  @override
  String get optionFinanced => '贷款购买';

  @override
  String get optionLeased => '租赁';

  @override
  String get optionCompany => '公司车辆';

  @override
  String get validationVinRequired => '请输入车架号';

  @override
  String get validationVinLength => '车架号必须为 17 位';

  @override
  String get validationMakerRequired => '请输入制造商';

  @override
  String get validationMakerTooLong => '制造商不能超过 50 个字符';

  @override
  String get validationBrandRequired => '请输入品牌';

  @override
  String get validationBrandTooLong => '品牌不能超过 50 个字符';

  @override
  String get validationModelRequired => '请输入车型';

  @override
  String get validationModelTooLong => '车型不能超过 50 个字符';

  @override
  String get validationPlateRequired => '请输入车牌号';

  @override
  String get validationPlateTooLong => '车牌号不能超过 20 个字符';

  @override
  String get validationYearRequired => '请输入年份';

  @override
  String validationYearRange(int min, int max) {
    return '请输入 $min 到 $max 之间的年份';
  }

  @override
  String get validationOdometerRequired => '请输入里程表读数';

  @override
  String get validationOdometerInvalid => '请输入有效的里程表读数';

  @override
  String get validationFuelRequired => '请输入加油量';

  @override
  String get validationFuelInvalid => '请输入有效的加油量';

  @override
  String get validationPriceRequired => '请输入金额';

  @override
  String get validationPriceInvalid => '请输入有效的金额';

  @override
  String get validationDistanceInvalid => '请输入有效的行驶距离';

  @override
  String validationOdometerBelowCurrent(String current) {
    return '里程表读数不能小于当前读数（$current）';
  }

  @override
  String validationOdometerLargeGap(String gap, String expected) {
    return '差距过大：里程表读数与预期值（$expected）相差 $gap';
  }

  @override
  String get recordsAddPolicy => '添加保单';

  @override
  String get recordsNoPolicies => '暂无保险保单';

  @override
  String get recordsNoPoliciesHint => '点击 + 记录这辆车的保单。';

  @override
  String get recordsPoliciesLoadFailed => '无法加载保单';

  @override
  String get recordsDeletePolicyTitle => '删除保单？';

  @override
  String recordsDeletePolicyBody(String number, String provider) {
    return '确定要删除 $provider 的保单 $number 吗？';
  }

  @override
  String recordsPolicyNumber(String number) {
    return '保单 $number';
  }

  @override
  String get recordsProvider => '保险公司';

  @override
  String get recordsPolicyNumberLabel => '保单号';

  @override
  String get recordsEffectiveDate => '生效日期';

  @override
  String get recordsExpiryDate => '到期日期';

  @override
  String get recordsPremium => '保费';

  @override
  String get recordsCurrencyShort => '币种';

  @override
  String get recordsDeductible => '免赔额（选填）';

  @override
  String get recordsActive => '生效中';

  @override
  String get recordsNotes => '备注';

  @override
  String get recordsDatesRequired => '必须填写生效日期和到期日期';

  @override
  String get recordsDateOrderInvalid => '生效日期必须早于到期日期';

  @override
  String get recordsAddSchedule => '添加保养计划';

  @override
  String get recordsNoSchedules => '暂无保养计划';

  @override
  String get recordsNoSchedulesHint => '点击 + 设置周期性提醒。';

  @override
  String get recordsSchedulesLoadFailed => '无法加载保养计划';

  @override
  String get recordsDeleteScheduleTitle => '删除保养计划？';

  @override
  String recordsDeleteScheduleBody(String name) {
    return '确定要删除保养计划“$name”吗？';
  }

  @override
  String recordsNextDueDate(String date) {
    return '下次到期 $date';
  }

  @override
  String recordsNextDueMileage(String mileage, String unit) {
    return '下次到期 $mileage $unit';
  }

  @override
  String get recordsScheduleName => '名称';

  @override
  String get recordsEveryNDays => '每 N 天';

  @override
  String get recordsEveryNMiles => '每 N 英里';

  @override
  String get recordsNextDueDateLabel => '下次到期日期';

  @override
  String get recordsNextDueMileageLabel => '下次到期里程';

  @override
  String get recordsIntervalRequired => '请至少设置一个间隔（天数或里程）';

  @override
  String get recordsAddRecord => '添加记录';

  @override
  String get recordsNoServiceRecords => '暂无维修保养记录';

  @override
  String get recordsNoServiceRecordsHint => '点击 + 记录这辆车的第一次保养。';

  @override
  String get recordsServiceLoadFailed => '无法加载维修保养记录';

  @override
  String get recordsDeleteServiceTitle => '删除维修保养记录？';

  @override
  String recordsServiceDateMileage(String date, String mileage, String unit) {
    return '$date • $mileage $unit';
  }

  @override
  String recordsItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个项目',
    );
    return '$_temp0';
  }

  @override
  String recordsRecordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已有 $count 条记录',
    );
    return '$_temp0';
  }

  @override
  String recordsActiveSchedules(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个生效中的计划',
    );
    return '$_temp0';
  }

  @override
  String get recordsServiceName => '保养项目名称';

  @override
  String get recordsReference => '单号（选填）';

  @override
  String get recordsServiceDate => '保养日期';

  @override
  String get recordsMileage => '里程';

  @override
  String get recordsServiceTypes => '保养类型';

  @override
  String get recordsDescription => '描述';

  @override
  String get recordsShopName => '维修店名称（选填）';

  @override
  String get recordsMarkdownHint => '支持 Markdown';

  @override
  String get recordsPreview => '预览';

  @override
  String get recordsTakePhoto => '拍照';

  @override
  String get recordsChoosePhoto => '选择照片';

  @override
  String get recordsChoosePdf => '选择 PDF';

  @override
  String get recordsNeedsCloudAi => '需要云端 AI（可在设置中更改）';

  @override
  String get recordsScanReceipt => '扫描收据';

  @override
  String get recordsCompleteFields => '请填写高亮的必填项（例如里程）。';

  @override
  String get recordsServiceDateRequired => '请填写保养日期';

  @override
  String get recordsLineItemNameRequired => '每个明细项都需要名称';

  @override
  String get recordsRemoveStoredImagesTitle => '删除已保存的图片？';

  @override
  String get recordsKeepAttached => '保留附件';

  @override
  String get recordsLineItems => '明细项';

  @override
  String get recordsAddItem => '添加明细';

  @override
  String get recordsTax => '税费';

  @override
  String get recordsItemHint => '项目';

  @override
  String get recordsQtyHint => '数量';

  @override
  String get recordsUnitHint => '单价';

  @override
  String get recordsAmountHint => '0.00';

  @override
  String get recordsVehicleNotes => '车辆备注';

  @override
  String get serviceTypeOilChange => '更换机油';

  @override
  String get serviceTypeTireRotation => '轮胎换位';

  @override
  String get serviceTypeBrake => '刹车';

  @override
  String get serviceTypeInspection => '检查';

  @override
  String get serviceTypeRepair => '维修';

  @override
  String get serviceTypeOther => '其他';

  @override
  String get lineItemLabour => '工时';

  @override
  String get lineItemPart => '配件';

  @override
  String get lineItemFee => '费用';

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
