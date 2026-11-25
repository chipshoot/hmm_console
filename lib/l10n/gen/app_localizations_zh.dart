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
  String get settingsAppearance => '外观';

  @override
  String get settingsAppearanceSystem => '跟随系统';

  @override
  String get settingsAppearanceLight => '浅色';

  @override
  String get settingsAppearanceDark => '深色';

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
  String get oneDriveChooseFolderTitle => '选择 OneDrive 中的 Hmm 数据';

  @override
  String oneDriveFolderModified(String date) {
    return '最后修改 $date';
  }

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
  String get commonCopy => '复制';

  @override
  String get commonClose => '关闭';

  @override
  String get syncErrorTitle => '同步错误';

  @override
  String get syncErrorCopied => '已复制';

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
  String syncSheetSignedInAs(String email) {
    return '已登录：$email';
  }

  @override
  String get syncSheetSignInAgain => '重新登录';

  @override
  String get syncSheetSyncNow => '立即同步';

  @override
  String get syncSheetAuthExpired => 'Hmm 登录已过期。请重新登录以恢复同步。';

  @override
  String get catalogGeneral => '常规';

  @override
  String get catalogGasLog => '加油记录';

  @override
  String get catalogAutomobile => '车辆';

  @override
  String get catalogInsurance => '保险';

  @override
  String get catalogScheduledService => '保养计划';

  @override
  String get catalogServiceRecord => '维修保养记录';

  @override
  String get catalogNote => '笔记';

  @override
  String get domainAutomobile => '车辆';

  @override
  String get domainGeneral => '常规';

  @override
  String get domainOther => '其他';

  @override
  String get notesTitle => '笔记';

  @override
  String get notesSearchHint => '搜索笔记';

  @override
  String get notesLoadFailed => '无法加载笔记';

  @override
  String get notesAll => '全部';

  @override
  String get notesPickTitle => '选择笔记';

  @override
  String get notesSelectNote => '请选择一条笔记';

  @override
  String get notesNone => '无';

  @override
  String get notesEmpty => '还没有笔记';

  @override
  String get notesNoUnattached => '没有未关联的笔记';

  @override
  String notesNoMatches(String query) {
    return '没有符合“$query”的笔记';
  }

  @override
  String get notesSearchNotes => '搜索笔记';

  @override
  String get notesLinkedUnavailable => '关联的笔记不可用';

  @override
  String notesGenericFailure(String error) {
    return '失败：$error';
  }

  @override
  String get notesSubjectRequired => '请输入标题';

  @override
  String get notesTitleHint => '标题';

  @override
  String get notesBodyHint => '开始输入…';

  @override
  String get notesDone => '完成';

  @override
  String get notesRemoveStoredImagesTitle => '删除已保存的图片？';

  @override
  String get notesKeepAttached => '保留附件';

  @override
  String get notesDeletedElsewhereTitle => '已在其他设备上删除';

  @override
  String get notesDeletedElsewhereBody =>
      '你编辑时，这条笔记已在其他设备上被删除。可以恢复它并保存你的修改，或放弃修改，让它留在“最近删除”中。';

  @override
  String get notesDeletedElsewhereRestore => '恢复并保存';

  @override
  String get notesDeletedElsewhereDiscard => '放弃修改';

  @override
  String get notesEditAction => '编辑';

  @override
  String get notesViewRaw => '查看原始内容';

  @override
  String get notesRawContentTitle => '原始内容';

  @override
  String get notesSubsystemsTitle => '子系统';

  @override
  String get notesSubsystemAutomobile => '车辆';

  @override
  String get notesRecordMicPermission => '录音需要麦克风权限';

  @override
  String get notesRecordStartFailed => '无法开始录音';

  @override
  String get notesRecordTooLong => '录音过长，请录制短一些的内容';

  @override
  String notesRecording(String time) {
    return '正在录音…  $time';
  }

  @override
  String get notesRecordStop => '停止';

  @override
  String get notesVaultSetUpPrompt => '请先在设置中启用安全保险库才能查看这张图片。';

  @override
  String get attachmentPhotoLoadFailed => '无法加载照片';

  @override
  String get cheatsheetWalletTitle => '速查卡';

  @override
  String get cheatsheetNew => '新建速查卡';

  @override
  String get cheatsheetLoadFailed => '无法加载速查卡。';

  @override
  String get cheatsheetEmpty => '暂无速查卡。点击 + 新建一张。';

  @override
  String get cheatsheetSearchHint => '搜索速查卡';

  @override
  String get cheatsheetNoMatches => '没有匹配的结果。';

  @override
  String get cheatsheetGone => '这张速查卡已不存在。';

  @override
  String get cheatsheetSaveFailed => '无法保存这张速查卡。';

  @override
  String get cheatsheetDeleteFailed => '无法删除这张速查卡。';

  @override
  String get cheatsheetDeleteTitle => '删除这张速查卡？';

  @override
  String get cheatsheetEditTooltip => '编辑速查卡';

  @override
  String get cheatsheetDeleteTooltip => '删除速查卡';

  @override
  String get cheatsheetOpenSource => '打开来源';

  @override
  String get cheatsheetOpenSourceTooltip => '打开来源笔记';

  @override
  String get cheatsheetOpenFailed => '无法打开。';

  @override
  String get cheatsheetTitleLabel => '标题';

  @override
  String get cheatsheetWalletGroupLabel => '分组';

  @override
  String get cheatsheetNewRow => '新增行';

  @override
  String get cheatsheetAddRow => '添加行';

  @override
  String get cheatsheetTapToBind => '点按以选择笔记';

  @override
  String get cheatsheetStartEmpty => '从空白开始';

  @override
  String get cheatsheetRemoveRow => '删除这一行';

  @override
  String cheatsheetSourceLoadFailed(String error) {
    return '无法加载笔记：$error';
  }

  @override
  String get cheatsheetSourceEmpty => '还没有可引用的笔记。';

  @override
  String get cheatsheetSourceNoMatches => '没有匹配的笔记。';

  @override
  String get cheatsheetSourceBack => '返回笔记列表';

  @override
  String get cheatsheetWholeNote => '整条笔记';

  @override
  String get cheatsheetSourceImages => '照片';

  @override
  String get cheatsheetImageSummary => '照片';

  @override
  String get cheatsheetSourceSearchHint => '搜索笔记';

  @override
  String get cheatsheetSourceOther => '其他笔记';

  @override
  String get cheatsheetSourceDomainVehicle => '车辆';

  @override
  String get cheatsheetSourceDomainContacts => '联系人';

  @override
  String get cheatsheetGroupVehicle => '车辆';

  @override
  String get cheatsheetGroupHealth => '健康';

  @override
  String get cheatsheetGroupReference => '参考';

  @override
  String get cheatsheetGroupUngrouped => '未分组';

  @override
  String get cheatsheetTemplateAccidentClaim => '事故理赔';

  @override
  String get cheatsheetTemplateHealthInfo => '健康信息';

  @override
  String get cheatsheetTemplateDocument => '文档';

  @override
  String get cheatsheetTemplateBlank => '空白';

  @override
  String get cheatsheetRowPlate => '车牌号';

  @override
  String get cheatsheetRowVin => '车架号';

  @override
  String get cheatsheetRowInsurer => '保险公司';

  @override
  String get cheatsheetRowPolicyNumber => '保单号';

  @override
  String get cheatsheetRowDriver => '驾驶人';

  @override
  String get cheatsheetRowPhone => '电话';

  @override
  String get cheatsheetRowAddress => '地址';

  @override
  String get cheatsheetRowLicencePhoto => '驾照';

  @override
  String get cheatsheetRowInsuranceCard => '保险卡';

  @override
  String get cheatsheetRowPerson => '本人';

  @override
  String get cheatsheetRowFamilyDoctor => '家庭医生';

  @override
  String get cheatsheetRowDoctorPhone => '医生电话';

  @override
  String get cheatsheetRowPharmacy => '药房';

  @override
  String get cheatsheetRowPharmacyPhone => '药房电话';

  @override
  String get cheatsheetRowSection1 => '第 1 节';

  @override
  String cheatsheetTileSubtitle(String group, int count) {
    return '$group · $count 行';
  }

  @override
  String cheatsheetTileSemantics(String title, String group, int count) {
    return '$title，$group，$count 行';
  }

  @override
  String get cheatsheetChipAll => '全部';

  @override
  String get cheatsheetLookTitle => '外观';

  @override
  String get cheatsheetLookTheme => '颜色';

  @override
  String get cheatsheetLookPattern => '图案';

  @override
  String get cheatsheetLookIcon => '图标';

  @override
  String get cheatsheetLookCover => '封面照片';

  @override
  String get cheatsheetLookLayout => '布局';

  @override
  String get cheatsheetLookReset => '重置外观';

  @override
  String get cheatsheetLayoutFacts => '信息';

  @override
  String get cheatsheetLayoutKeyPoints => '要点';

  @override
  String get cheatsheetThemeBlue => '蓝色';

  @override
  String get cheatsheetThemeGreen => '绿色';

  @override
  String get cheatsheetThemeOrange => '橙色';

  @override
  String get cheatsheetThemeRed => '红色';

  @override
  String get cheatsheetThemePurple => '紫色';

  @override
  String get cheatsheetThemeTeal => '青色';

  @override
  String get cheatsheetThemePink => '粉色';

  @override
  String get cheatsheetThemeAmber => '琥珀色';

  @override
  String get cheatsheetThemeSlate => '石板灰';

  @override
  String get cheatsheetThemeIndigo => '靛蓝';

  @override
  String get cheatsheetThemeBrown => '棕色';

  @override
  String get cheatsheetThemeBlack => '黑色';

  @override
  String get cheatsheetPatternNone => '纯色';

  @override
  String get cheatsheetPatternDots => '圆点';

  @override
  String get cheatsheetPatternStripes => '条纹';

  @override
  String get cheatsheetPatternGrid => '网格';

  @override
  String get cheatsheetPatternWaves => '波浪';

  @override
  String get cheatsheetIconChoose => '选择图标';

  @override
  String get cheatsheetCoverAdd => '添加封面';

  @override
  String get cheatsheetCoverChange => '更换封面';

  @override
  String get cheatsheetCoverRemove => '移除封面';

  @override
  String get cheatsheetCoverCamera => '拍照';

  @override
  String get cheatsheetCoverLibrary => '从相册选择';

  @override
  String get cheatsheetCoverScan => '扫描文档';

  @override
  String get cheatsheetCoverFailed => '无法添加该照片。';

  @override
  String get cheatsheetEmojiPickerTitle => '选择表情符号';

  @override
  String get cheatsheetEmojiSearchHint => '用中文或英文搜索';

  @override
  String get cheatsheetEmojiCustomLabel => '或输入任意表情符号';

  @override
  String get cheatsheetEmojiUse => '使用';

  @override
  String get cheatsheetEmojiInvalid => '请输入一个表情符号。';

  @override
  String get cheatsheetEmojiClear => '不使用表情符号';

  @override
  String get cheatsheetEmojiNoMatches => '没有匹配的表情符号。';

  @override
  String get cheatsheetEmojiGroupVehicle => '车辆';

  @override
  String get cheatsheetEmojiGroupHealth => '健康';

  @override
  String get cheatsheetEmojiGroupHome => '家居';

  @override
  String get cheatsheetEmojiGroupBooks => '书籍与学习';

  @override
  String get cheatsheetEmojiGroupWork => '工作';

  @override
  String get cheatsheetEmojiGroupTravel => '旅行';

  @override
  String get cheatsheetEmojiGroupMoney => '财务';

  @override
  String get cheatsheetEmojiGroupMisc => '其他';

  @override
  String get cheatsheetRowEmojiTooltip => '行表情符号';

  @override
  String get cheatsheetTileProtectedSemantics => '，受保护';

  @override
  String get cheatsheetTileCoverLockedSemantics => '，封面已锁定';

  @override
  String get launcherTitle => '启动器';

  @override
  String get launcherPinned => '已固定（拖动排序）';

  @override
  String get launcherFavorites => '常用';

  @override
  String get launcherAliases => '别名';

  @override
  String get launcherNewAlias => '新建别名（例如 cs）';

  @override
  String get launcherDestination => '目标';

  @override
  String get launcherAddAlias => '添加别名';

  @override
  String get launcherNoMatches => '没有匹配的功能';

  @override
  String get launcherTypeSlash => '输入 / 快速跳转到功能';

  @override
  String get launcherRecent => '最近使用';

  @override
  String get launcherAssistantStub => 'AI 问答即将推出。\n输入 / 快速跳转到功能。';

  @override
  String get launcherSearchHint => '输入 / 搜索功能 · AI 问答（即将推出）';

  @override
  String launcherAliasMapping(String alias, String destination) {
    return '“$alias”  →  $destination';
  }

  @override
  String get launcherDestVehicles => '车辆';

  @override
  String get launcherDestGasLog => '加油记录';

  @override
  String get launcherDestServiceLog => '维修保养记录';

  @override
  String get launcherDestScheduledServices => '保养计划';

  @override
  String get launcherDestInsurance => '保险';

  @override
  String get launcherDestVehicleNotes => '车辆备注';

  @override
  String get launcherDestNotes => '笔记';

  @override
  String get launcherDestGasStations => '加油站';

  @override
  String get launcherDestCheatsheets => '速查卡';

  @override
  String get launcherDestSettings => '设置';

  @override
  String get authLogin => '登录';

  @override
  String get authSignUp => '注册';

  @override
  String get authEmail => '邮箱';

  @override
  String get authPassword => '密码';

  @override
  String get authConfirmPassword => '确认密码';

  @override
  String get authUsername => '用户名';

  @override
  String get authForgotPasswordPrompt => '忘记密码？';

  @override
  String get authForgotPassword => '找回密码';

  @override
  String get authResendEmail => '重新发送邮件';

  @override
  String get authGoogle => 'Google';

  @override
  String get authApple => 'Apple';

  @override
  String get dashboardSettings => '设置';

  @override
  String get dashboardSignOut => '退出登录';

  @override
  String dashboardComingSoon(String feature) {
    return '$feature即将推出…';
  }

  @override
  String get dashboardLooksGood => '就这样';

  @override
  String get dashboardOpenSettings => '打开设置';

  @override
  String get dashboardDataStorage => '数据存储';

  @override
  String get dashboardDistance => '距离';

  @override
  String get dashboardFuelVolume => '燃油量';

  @override
  String get dashboardCurrency => '货币';

  @override
  String get dashboardWelcome => '欢迎 — 快速开始';

  @override
  String get dashboardDefaultsBlurb => '我们为你选好了这些默认设置。如果有不合适的，可以在设置中修改。';

  @override
  String get onboardingWelcome => '欢迎';

  @override
  String get onboardingNewUser => '第一次使用 Hmm';

  @override
  String get onboardingNewUserSubtitle => '在这台设备上从零开始。在你于设置中开启云同步之前，数据只保存在本机。';

  @override
  String get onboardingMigrating => '我已在其他设备上使用 Hmm';

  @override
  String get onboardingMigratingSubtitle => '登录 OneDrive，把已有的数据和设置同步到这台设备。';

  @override
  String get onboardingHmmCloud => 'Hmm 云（服务器）';

  @override
  String get onboardingHmmCloudSubtitle => '登录或注册 Hmm 账户；数据保存在 Hmm 服务器上。';

  @override
  String get onboardingContinue => '继续';

  @override
  String get onboardingSkip => '暂时跳过';

  @override
  String get receiptCloudAiTitle => '使用云端 AI 识别收据？';

  @override
  String get receiptCloudAiBody =>
      '你的收据照片或 PDF 会上传到 Hmm 服务器，由 AI 读取并自动填写字段。本机识别不会离开手机，但无法读取 PDF，明细拆分也不够准确。';

  @override
  String get receiptEnableCloudAi => '启用云端 AI';

  @override
  String get receiptOnDevice => '本机识别（私密）';

  @override
  String get receiptCloudAi => '云端 AI（更准确）';

  @override
  String get receiptOnDeviceSubtitle => '在手机上识别照片，不会上传任何内容。无法读取 PDF。';

  @override
  String get receiptCloudAiSubtitle => '上传收据交由 AI 识别。可读取 PDF，并拆分明细。';

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
  String get vehicleAdd => '添加车辆';

  @override
  String get automobileHubTitle => '汽车';

  @override
  String get automobileHubVehicles => '车辆';

  @override
  String get automobileHubLicenceTitle => '驾驶执照';

  @override
  String get automobileHubLicenceAdd => '添加您的驾驶执照';

  @override
  String get automobileHubLicenceAddHint => '扫描证件或手动输入';

  @override
  String automobileHubLicenceExpires(String date) {
    return '$date到期';
  }

  @override
  String get automobileHubNoVehicles => '还没有车辆';

  @override
  String get automobileHubNoVehiclesHint => '添加车辆，把加油记录、保险和保养记录放在一起。';

  @override
  String automobileHubGasLogFor(String name) {
    return '$name的加油记录';
  }

  @override
  String automobileHubNotesFor(String name) {
    return '$name的备注';
  }

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
  String get stationAdd => '添加加油站';

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
  String get recordsGasLog => '加油记录';

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
  String get vehicleNotesNew => '新建笔记';

  @override
  String vehicleNotesDomainCaption(String name) {
    return '汽车 · $name';
  }

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

  @override
  String get contactBlockTitle => '联系方式';

  @override
  String get contactBlockAdd => '添加联系方式';

  @override
  String get contactBlockRemove => '移除联系方式';

  @override
  String get contactFieldName => '姓名';

  @override
  String get contactFieldOrganization => '机构';

  @override
  String get contactFieldPhone => '电话';

  @override
  String get contactCountryCodeTitle => '国家/地区代码';

  @override
  String get contactCountryCodeSearchHint => '按国家/地区或区号搜索';

  @override
  String get contactCountryCodePlaceholder => '区号';

  @override
  String get contactCountryCodeNone => '不设区号';

  @override
  String get contactFieldMobile => '手机';

  @override
  String get contactFieldFax => '传真';

  @override
  String get contactFieldEmail => '电子邮箱';

  @override
  String get contactFieldAddress => '地址';

  @override
  String get contactFieldStreet => '街道地址';

  @override
  String get contactFieldCity => '城市';

  @override
  String get contactFieldRegion => '省 / 州';

  @override
  String get contactFieldPostalCode => '邮政编码';

  @override
  String get contactFieldCountry => '国家';

  @override
  String get contactFieldNotes => '备注';

  @override
  String get vehicleRegistrationSection => '行驶证';

  @override
  String get vehicleRegistrationNumber => '登记号';

  @override
  String get vehicleRegistrationJurisdiction => '省 / 州';

  @override
  String get vehicleRegistrationIssued => '发证日期';

  @override
  String get vehicleValueNotSet => '未设置';

  @override
  String get launcherDestLicence => '驾驶证';

  @override
  String get licenceTitle => '驾驶证';

  @override
  String get licenceEmpty => '尚未保存驾驶证';

  @override
  String get licenceAdd => '添加驾驶证';

  @override
  String get licenceEdit => '编辑驾驶证';

  @override
  String get licenceNumber => '证件号码';

  @override
  String get licenceClass => '准驾车型';

  @override
  String get licenceJurisdiction => '省 / 州';

  @override
  String get licenceIssued => '发证日期';

  @override
  String get licenceExpires => '有效期至';

  @override
  String get licenceFront => '正面';

  @override
  String get licenceBack => '反面';

  @override
  String get licenceCaptureFront => '拍摄正面';

  @override
  String get licenceCaptureBack => '拍摄反面';

  @override
  String get licenceShow => '出示驾驶证';

  @override
  String get licenceScan => '扫描驾驶证';

  @override
  String get licenceScanExtraPagesIgnored => '仅使用了前两页。';

  @override
  String get licenceSaved => '驾驶证已保存';

  @override
  String get licenceNoImages => '尚未拍摄照片';

  @override
  String get helpButtonTooltip => '帮助';

  @override
  String get helpAutomobileHubTitle => '汽车';

  @override
  String get helpAutomobileHubSummary => '驾驶证和车辆集中在这里。';

  @override
  String get helpAutomobileHubLicenceTitle => '驾驶证';

  @override
  String get helpAutomobileHubLicenceBody => '点击卡片查看或添加驾驶证。云端 API 模式下不显示。';

  @override
  String get helpAutomobileHubVehicleTitle => '车辆';

  @override
  String get helpAutomobileHubVehicleBody => '点击车辆所在行，查看和编辑车辆信息。';

  @override
  String get helpAutomobileHubNotesTitle => '备注';

  @override
  String get helpAutomobileHubNotesBody => '打开这辆车的备注。数字表示备注数量。';

  @override
  String get helpAutomobileHubFuelTitle => '加油记录';

  @override
  String get helpAutomobileHubFuelBody => '打开这辆车的加油记录。';

  @override
  String get helpAutomobileHubManageTitle => '管理';

  @override
  String get helpAutomobileHubManageBody => '添加车辆，并选择哪些车辆处于启用状态。';

  @override
  String get helpVehicleNotesTitle => '车辆备注';

  @override
  String get helpVehicleNotesSummary => '关于这辆车的所有记录。这些备注在备注列表中归入“汽车”。';

  @override
  String get helpVehicleNotesNewTitle => '新建备注';

  @override
  String get helpVehicleNotesNewBody => '新建一条已关联到这辆车的备注。';

  @override
  String get helpVehicleNotesAttachTitle => '关联已有备注';

  @override
  String get helpVehicleNotesAttachBody => '选择一条尚未关联的“常规”备注，把它关联到这辆车。';

  @override
  String get helpVehicleNotesDetachTitle => '取消关联';

  @override
  String get helpVehicleNotesDetachBody =>
      '解除备注与这辆车的关联。备注会保留并移到“常规”，之后可随时重新关联。';

  @override
  String get helpVehicleNotesOpenTitle => '打开备注';

  @override
  String get helpVehicleNotesOpenBody => '点击备注即可查看或编辑。';

  @override
  String get undoAction => '撤销';

  @override
  String get undoNoteDetached => '备注已移至“常规”';

  @override
  String get undoNoteDetachFailed => '无法取消关联备注';

  @override
  String get undoNoteRestored => '备注已恢复';

  @override
  String get undoNoteRestoreFailed => '无法撤销，备注仍在“常规”中';

  @override
  String get notesAttachExistingTooltip => '关联已有备注';

  @override
  String get notesAddTooltip => '添加备注';

  @override
  String get notesDetachTooltip => '取消关联备注';

  @override
  String get contactsTitle => '联系人';

  @override
  String get contactBirthday => '生日';

  @override
  String get contactBirthdayGregorian => '公历';

  @override
  String get contactBirthdayLunar => '农历';

  @override
  String get contactBirthdayLeapMonth => '闰月';

  @override
  String get contactBirthdayYear => '年份（可选）';

  @override
  String get contactBirthdayNoYear => '不填年份';

  @override
  String get contactBirthdayClear => '清除';

  @override
  String contactBirthdayAge(int age) {
    return '$age岁';
  }

  @override
  String contactBirthdayNext(String date) {
    return '下次 $date';
  }

  @override
  String get contactBirthdayNotSet => '未设置';

  @override
  String get contactRemind => '提醒我';

  @override
  String get contactRemindHint => '显示在日历中，并在当天提醒';

  @override
  String get contactRemindOn => '已开启生日提醒';

  @override
  String get contactRemindOff => '已关闭生日提醒';

  @override
  String get contactRemindFailed => '无法更改提醒';

  @override
  String get contactRemindUndone => '已撤销提醒更改';

  @override
  String get contactRemindUndoFailed => '无法撤销提醒更改';

  @override
  String get helpContactEditBirthdayTitle => '生日';

  @override
  String get helpContactEditBirthdayBody => '可设置公历或农历生日，年份可填可不填。清除生日会同时关闭提醒。';

  @override
  String get helpContactDetailRemindTitle => '提醒我';

  @override
  String get helpContactDetailRemindBody =>
      '把这个生日显示在日历中，并在当天 9:00 提醒你。可在日历中调整提醒。';

  @override
  String get contactsEmpty => '暂无联系人';

  @override
  String get contactsSearchHint => '搜索联系人';

  @override
  String get contactAdd => '添加联系人';

  @override
  String get contactEdit => '编辑联系人';

  @override
  String get contactDelete => '删除联系人';

  @override
  String get contactTypePerson => '个人';

  @override
  String get contactTypeOrganization => '机构';

  @override
  String get contactFirstName => '名';

  @override
  String get contactLastName => '姓';

  @override
  String get contactOrganizationName => '机构名称';

  @override
  String get contactPhones => '电话';

  @override
  String get contactEmails => '电子邮箱';

  @override
  String get contactAddresses => '地址';

  @override
  String get contactNotes => '备注';

  @override
  String get contactIsSelf => '这是我';

  @override
  String get contactIsSelfHint => '只能有一个联系人标记为本人';

  @override
  String get contactRelationship => '关系';

  @override
  String get contactAddPhone => '添加电话';

  @override
  String get contactAddEmail => '添加邮箱';

  @override
  String get contactAddAddress => '添加地址';

  @override
  String get contactNameRequired => '联系人需要名称';

  @override
  String get contactGroupFamily => '家人';

  @override
  String get contactGroupProviders => '服务提供方';

  @override
  String get contactGroupOther => '其他';

  @override
  String get relationshipSelf => '本人';

  @override
  String get relationshipSpouse => '配偶';

  @override
  String get relationshipParent => '父母';

  @override
  String get relationshipChild => '子女';

  @override
  String get relationshipFamily => '家人';

  @override
  String get relationshipFriend => '朋友';

  @override
  String get relationshipDoctor => '医生';

  @override
  String get relationshipPharmacy => '药房';

  @override
  String get relationshipInsurer => '保险';

  @override
  String get relationshipOther => '其他';

  @override
  String get fieldLabelMobile => '手机';

  @override
  String get fieldLabelHome => '住宅';

  @override
  String get fieldLabelWork => '工作';

  @override
  String get fieldLabelPersonal => '个人';

  @override
  String get fieldLabelOther => '其他';

  @override
  String get contactsCloudApiUnavailable => '联系人仅在本地和云存储模式下可用。请在设置中切换数据模式。';

  @override
  String get contactsLoadFailed => '无法加载联系人';

  @override
  String get contactNotFound => '此联系人已不存在';

  @override
  String get contactDeactivated => '联系人已移除';

  @override
  String get contactDeactivateFailed => '无法移除联系人';

  @override
  String get contactDeactivateUndone => '联系人已恢复';

  @override
  String get contactDeactivateUndoFailed => '无法恢复联系人';

  @override
  String get contactAddTooltip => '添加联系人';

  @override
  String get contactEditTooltip => '编辑联系人';

  @override
  String get contactRemoveTooltip => '移除联系人';

  @override
  String get contactRemoveFieldTooltip => '移除此项';

  @override
  String get contactAddressCountry => '国家/地区';

  @override
  String get contactAddressCountryUS => '美国';

  @override
  String get contactAddressCountryCA => '加拿大';

  @override
  String get contactAddressCountryCN => '中国';

  @override
  String get contactAddressCountryOther => '其他';

  @override
  String get contactAddressStreet => '街道地址';

  @override
  String get contactAddressUnit => '公寓/套房/单元';

  @override
  String get contactAddressCity => '城市';

  @override
  String get contactAddressState => '州';

  @override
  String get contactAddressProvinceTerritory => '省/地区';

  @override
  String get contactAddressZip => 'ZIP 邮政编码';

  @override
  String get contactAddressPostalCode => '邮政编码';

  @override
  String get contactAddressCnProvince => '省份';

  @override
  String get contactAddressCnDistrict => '区/县';

  @override
  String get contactAddressCnDetail => '详细地址';

  @override
  String get contactAddressRegionSelect => '请选择';

  @override
  String get contactAddressRegionSearchHint => '按名称或代码搜索';

  @override
  String get contactAddressInvalidZip => '请输入 5 位 ZIP 邮政编码，或 ZIP+4（12345-6789）';

  @override
  String get contactAddressInvalidCaPostal => '请输入形如 A1A 1A1 的邮政编码';

  @override
  String get contactAddressInvalidCnPostal => '请输入 6 位邮政编码';

  @override
  String get contactAddressFixPostal => '请先修正标出的邮政编码再保存';

  @override
  String get helpContactsTitle => '联系人';

  @override
  String get helpContactsSummary => '你的通讯录：保存你联系的人和机构。';

  @override
  String get helpContactsAddTitle => '添加联系人';

  @override
  String get helpContactsAddBody => '新建联系人，可以是个人或机构。';

  @override
  String get helpContactsSearchTitle => '搜索';

  @override
  String get helpContactsSearchBody =>
      '输入文字，按姓名、电话或邮箱筛选联系人。中文姓名也可用拼音全拼（zhangwei）或首字母（zw）搜索。';

  @override
  String get helpContactsSelfTitle => '本人';

  @override
  String get helpContactsSelfBody =>
      '“本人”联系人保存你自己的信息，并带有“本人”标记。在编辑页打开“这是我”即可标记，并自动归为“本人”关系。点按即可查看或编辑。';

  @override
  String get helpContactDetailTitle => '联系人';

  @override
  String get helpContactDetailSummary => '这位联系人的全部信息。';

  @override
  String get helpContactDetailCallTitle => '拨打电话';

  @override
  String get helpContactDetailCallBody => '点按电话号码即可拨打。';

  @override
  String get helpContactDetailMapTitle => '在地图中打开';

  @override
  String get helpContactDetailMapBody =>
      '点按地址，在地图中查看。中文地址会在 Google 地图中打开（如已安装则打开其应用），因为苹果地图无法准确找到中文地址。';

  @override
  String get helpContactDetailEditTitle => '编辑';

  @override
  String get helpContactDetailEditBody => '修改联系人的名称、详细信息或关系。';

  @override
  String get helpContactDetailRemoveTitle => '移除';

  @override
  String get helpContactDetailRemoveBody => '将此联系人从列表中移除。移除后立即点按“撤销”即可恢复。';

  @override
  String get contactEnglishName => '英文名';

  @override
  String get contactEnglishNameHint => '可选。用于给说英语的人看的速查卡。';

  @override
  String get helpContactEditEnglishNameTitle => '英文名';

  @override
  String get helpContactEditEnglishNameBody =>
      '名字为中文时显示。填写此人或机构使用的英文名，例如 Michael Wang。它不改变联系人在列表中的显示和排序，但可以被搜索到；速查卡的一行可以显示它（选择 Contact.englishName），用于给说英语的人看的卡片。';

  @override
  String get helpContactEditTitle => '编辑联系人';

  @override
  String get helpContactEditSummary => '填写联系人的名称和详细信息，然后保存。';

  @override
  String get helpContactEditTypeTitle => '个人或机构';

  @override
  String get helpContactEditTypeBody => '选择这是个人还是机构，这会决定显示哪些名称栏。';

  @override
  String get contactPhotoChoose => '选择照片';

  @override
  String get contactPhotoTake => '拍照';

  @override
  String get contactPhotoRemove => '移除照片';

  @override
  String get contactPhotoChange => '更换照片';

  @override
  String get contactPhotoPickFailed => '无法添加照片';

  @override
  String get helpContactEditPhotoTitle => '照片';

  @override
  String get helpContactEditPhotoBody =>
      '点按顶部的圆圈，可选择照片、拍照或移除照片。照片会显示在联系人页面和列表中。';

  @override
  String get helpContactEditFieldsTitle => '电话、邮箱和地址';

  @override
  String get helpContactEditFieldsBody =>
      '可添加多个，并为每个设置标签，如手机或工作。电话号码旁可点按区号选择国家/地区区号，也可直接粘贴以 + 开头的号码。';

  @override
  String get helpContactEditAddressTitle => '地址';

  @override
  String get helpContactEditAddressBody =>
      '为每个地址选择国家/地区。美国、加拿大和中国按当地格式提供对应字段：街道、单元、城市、州或省（从列表中选择）以及 ZIP 或邮政编码；中国地址依次为省份、城市、区/县、详细地址和邮政编码。邮政编码格式不正确时会提示，修正前无法保存联系人。切换国家/地区会保留街道、城市和邮政编码，但会清空州/省和区/县。选择“其他”可用多行自由文本填写任意地址；切换到“其他”时，已填写的内容会保留为文本。';

  @override
  String get helpContactEditRelationshipTitle => '关系';

  @override
  String get helpContactEditRelationshipBody =>
      '这位联系人与你的关系。例如，家庭医生选“医生”。选“其他”可自行描述。';

  @override
  String get helpContactEditSelfTitle => '这是我';

  @override
  String get helpContactEditSelfBody => '将此联系人标记为你本人。只能标记一个联系人。';

  @override
  String get helpCheatsheetWalletTitle => '速查卡';

  @override
  String get helpCheatsheetWalletSummary =>
      '一目了然地查看所有卡片。点按卡片即可打开；用搜索和筛选标签缩小范围。';

  @override
  String get helpCheatsheetWalletTilesTitle => '卡片';

  @override
  String get helpCheatsheetWalletTilesBody =>
      '每张卡片显示其颜色或封面照片、图标、标题，以及所属分组和行数。点按卡片即可打开。';

  @override
  String get helpCheatsheetWalletGroupsTitle => '分组标签';

  @override
  String get helpCheatsheetWalletGroupsBody =>
      '第一排标签一次只显示一个卡包分组；点“全部”可重新显示所有卡片。搜索只在所选分组内进行。';

  @override
  String get helpCheatsheetWalletTagsTitle => '标签筛选';

  @override
  String get helpCheatsheetWalletTagsBody => '标签筛选只显示带有全部已选标签的卡片。再次点按标签即可取消。';

  @override
  String get helpCheatsheetWalletLockTitle => '锁定标记';

  @override
  String get helpCheatsheetWalletLockBody =>
      '锁形图标表示受保护的卡片。🔒 表示其封面照片已在保险库中锁定：卡片会改为显示颜色，打开卡片后可解锁照片。';

  @override
  String get helpCheatsheetDetailTitle => '速查卡详情';

  @override
  String get helpCheatsheetDetailSummary => '一张卡片，各行内容取自你的笔记。可在顶部栏编辑或删除。';

  @override
  String get helpCheatsheetDetailFactsTitle => '“信息”布局';

  @override
  String get helpCheatsheetDetailFactsBody =>
      '每一行显示标签，下方是取自笔记的值。短横线表示该行尚未关联；“source removed”表示其笔记已被删除。点按电话号码或地址可拨打或在地图中查看。';

  @override
  String get helpCheatsheetDetailKeyPointsTitle => '“要点”布局';

  @override
  String get helpCheatsheetDetailKeyPointsBody =>
      '各行在卡片颜色上编号，若已选择表情符号则一并显示，标签加粗，值显示在下方。值、操作和照片与“信息”布局相同。';

  @override
  String get helpCheatsheetDetailOpenSourceTitle => '打开笔记';

  @override
  String get helpCheatsheetDetailOpenSourceBody =>
      '点按一行上的打开按钮，查看其值的来源。联系人会在联系人页面打开，其他笔记以笔记形式打开。长按该行可查看原始笔记。';

  @override
  String get helpCheatsheetDetailHeaderTitle => '封面标题区';

  @override
  String get helpCheatsheetDetailHeaderBody =>
      '卡片顶部显示其颜色和图案或封面照片、图标、标题，以及所属分组和行数。可在设计器中更改外观。';

  @override
  String get helpCheatsheetDetailLockTitle => '已锁定的封面';

  @override
  String get helpCheatsheetDetailLockBody =>
      '封面照片受保护且保险库已锁定时，标题区会改为显示锁定图块。点按即可解锁并查看照片。';

  @override
  String get helpCheatsheetDesignerTitle => '设计速查卡';

  @override
  String get helpCheatsheetDesignerSummary => '为卡片命名、选择外观，然后将每一行指向笔记中的某一部分。';

  @override
  String get helpCheatsheetDesignerLookTitle => '外观';

  @override
  String get helpCheatsheetDesignerLookBody =>
      '“外观”包含颜色、图案、图标、封面和布局。新建卡片时默认展开，编辑已有卡片时默认收起；点按其标题栏即可展开或收起。标题栏中的小卡片会预览卡片在卡包中的样子。';

  @override
  String get helpCheatsheetDesignerIconTitle => '图标';

  @override
  String get helpCheatsheetDesignerIconBody =>
      '为卡片选择一个表情符号。可用中文或英文搜索，也可以自己输入任意表情符号。';

  @override
  String get helpCheatsheetDesignerCoverTitle => '封面照片';

  @override
  String get helpCheatsheetDesignerCoverBody =>
      '拍照、从相册选择或扫描文档作为卡片背景；标题下方会加一条深色条以保持文字清晰。随时可以移除，颜色会恢复。封面仅在本地和云存储模式下可用。';

  @override
  String get helpCheatsheetDesignerLayoutTitle => '布局';

  @override
  String get helpCheatsheetDesignerLayoutBody =>
      '“信息”在每个标签旁显示其值。“要点”为各行编号并使用卡片主题颜色，适合书籍和文档。';

  @override
  String get helpCheatsheetDesignerSourceTitle => '为一行选择笔记';

  @override
  String get helpCheatsheetDesignerSourceBody =>
      '点按一行下方的链接，选择其值的来源。笔记页面会打开，可使用搜索、标签和筛选；点按笔记后，再选择一个字段、一个段落、一张照片或整条笔记。在该步骤返回会回到笔记页面。';

  @override
  String get helpCheatsheetDesignerRowEmojiTitle => '行表情符号';

  @override
  String get helpCheatsheetDesignerRowEmojiBody =>
      '在“要点”布局中，每一行都可以有自己的表情符号。切换到“信息”会隐藏它们，但不会删除。';

  @override
  String get helpCheatsheetDesignerResetTitle => '重置外观';

  @override
  String get helpCheatsheetDesignerResetBody =>
      '将颜色、图案、图标和布局恢复为模板默认值，移除封面照片（云端 API 模式下保留封面）并清除所有行表情符号。';

  @override
  String get contactCustomRelationship => '描述这层关系';

  @override
  String get contactSaveFailed => '无法保存联系人';

  @override
  String get settingsContactSortBy => '联系人排序方式';

  @override
  String get settingsContactSortFamily => '姓氏';

  @override
  String get settingsContactSortGiven => '名字';

  @override
  String get helpContactsSortTitle => '排序';

  @override
  String get helpContactsSortBody =>
      '联系人默认按姓氏排序。如需按名字排序，请在“设置”中更改“联系人排序方式”。中文姓名按拼音排序，与拉丁字母姓名排在一起。';

  @override
  String get contactNameOptions => '更多姓名选项';

  @override
  String get contactNameOrder => '姓名顺序';

  @override
  String get contactNameOrderAuto => '自动';

  @override
  String get contactNameOrderGivenFirst => '名在前';

  @override
  String get contactNameOrderFamilyFirst => '姓在前';

  @override
  String get contactPhoneticFamily => '姓氏拼音';

  @override
  String get contactPhoneticGiven => '名字拼音';

  @override
  String get contactPhoneticInvalid => '只能使用拉丁字母、空格和撇号';

  @override
  String get contactPhoneticFixToSave => '请修正标出的拼音后再保存';

  @override
  String contactShownAs(String name) {
    return '显示为：$name';
  }

  @override
  String get helpContactEditNameOptionsTitle => '更多姓名选项';

  @override
  String get helpContactEditNameOptionsBody =>
      '中文姓名按姓在前显示（张伟），其他姓名按名在前显示（John Smith）。“姓名顺序”可为单个联系人更改此规则。拼音字段决定姓名的排序和搜索方式；留空时使用灰色显示的自动拼音。输入中文姓名时，此部分会自动展开。';

  @override
  String get notesContactTitleFallback => '联系人';

  @override
  String get notesCalendarEventTitleFallback => '日程';

  @override
  String get notesCheatsheetTitleFallback => '速查卡';

  @override
  String notesCheatsheetPreview(String group, int count) {
    return '$group · $count 行';
  }

  @override
  String get notesFlag => '旗标';

  @override
  String get notesUnflag => '移除旗标';

  @override
  String get notesManageShort => '管理';

  @override
  String get helpNotesListSwipesTitle => '滑动笔记';

  @override
  String get helpNotesListSwipesBody =>
      '向右滑动可置顶或取消置顶。向左滑动可用上次使用的颜色加旗标，或删除笔记。删除的笔记会在“最近删除”中保留 30 天。属于通讯录、卡片或汽车的笔记显示“管理”而不是“删除”。';

  @override
  String get notesPin => '置顶';

  @override
  String get notesUnpin => '取消置顶';

  @override
  String get notesFlagAction => '旗标…';

  @override
  String get notesFlagSheetTitle => '旗标';

  @override
  String get notesClearFlag => '清除旗标';

  @override
  String get flagColorRed => '红色';

  @override
  String get flagColorOrange => '橙色';

  @override
  String get flagColorYellow => '黄色';

  @override
  String get flagColorGreen => '绿色';

  @override
  String get flagColorBlue => '蓝色';

  @override
  String get flagColorPurple => '紫色';

  @override
  String get flagColorGrey => '灰色';

  @override
  String get notesPinnedLabel => '已置顶';

  @override
  String notesFlaggedLabel(String color) {
    return '$color旗标';
  }

  @override
  String get notesPinFailed => '无法置顶此笔记';

  @override
  String get notesFlagFailed => '无法为此笔记加旗标';

  @override
  String get notesMovedToRecentlyDeleted => '笔记已删除';

  @override
  String get notesDeleteFailed => '无法删除此笔记';

  @override
  String get notesRestored => '笔记已恢复';

  @override
  String get notesRestoreFailed => '无法恢复此笔记';

  @override
  String notesManageIn(String place) {
    return '请在$place中管理';
  }

  @override
  String get notesManagePlaceOwnScreen => '其所属页面';

  @override
  String get helpNoteDetailTitle => '笔记';

  @override
  String get helpNoteDetailSummary => '阅读笔记，并通过 ⋯ 菜单置顶、加旗标、编辑或删除。';

  @override
  String get helpNoteDetailPinTitle => '置顶';

  @override
  String get helpNoteDetailPinBody => '将笔记标记为置顶。置顶会同步到你的其他设备。选择“取消置顶”即可移除。';

  @override
  String get helpNoteDetailFlagTitle => '旗标';

  @override
  String get helpNoteDetailFlagBody => '用七种颜色之一标记笔记。选择“清除旗标”即可移除。';

  @override
  String get helpNoteDetailDeleteTitle => '删除';

  @override
  String get helpNoteDetailDeleteBody =>
      '将笔记移到“最近删除”。点按消息中的“撤销”可立即恢复，也可在 30 天内从“最近删除”中恢复。';

  @override
  String get helpNoteDetailRestoreTitle => '恢复';

  @override
  String get helpNoteDetailRestoreBody => '已移到“最近删除”的笔记会显示横幅。点按“恢复”即可将其放回笔记中。';

  @override
  String get helpNoteDetailExpandTitle => '全屏显示';

  @override
  String get helpNoteDetailExpandBody =>
      '在宽屏上，轻点左上角的全屏按钮可隐藏侧边栏和列表，让笔记占满整个屏幕。再次轻点即可恢复。每次打开笔记时都会显示列表。';

  @override
  String get notesExpandNoteTooltip => '全屏显示';

  @override
  String get notesCollapseNoteTooltip => '退出全屏';

  @override
  String get helpNoteDetailManageTitle => '在其他位置管理';

  @override
  String get helpNoteDetailManageBody =>
      '联系人、速查卡、车辆、加油记录等记录需在各自的页面中删除，而不是在笔记中删除。置顶和旗标在此仍然可用。';

  @override
  String get notesDensityCompact => '紧凑';

  @override
  String get notesDensityStandard => '标准';

  @override
  String get notesDensityRich => '丰富';

  @override
  String notesRowSemantics(String title, String date) {
    return '$title，$date';
  }

  @override
  String notesRowSemanticsFlagged(String color) {
    return '已标记$color';
  }

  @override
  String get notesRowSemanticsPinned => '已置顶';

  @override
  String notesRowMoreTags(String count) {
    return '+$count';
  }

  @override
  String get notesViewTooltip => '显示';

  @override
  String get notesFiltered => '已筛选';

  @override
  String get notesSearchClearTooltip => '清除搜索';

  @override
  String get notesSearchClearAction => '清除搜索';

  @override
  String get notesNoneInView => '这里没有笔记';

  @override
  String get notesRetry => '重试';

  @override
  String get notesGroupPinned => '置顶';

  @override
  String get notesGroupToday => '今天';

  @override
  String get notesGroupYesterday => '昨天';

  @override
  String get notesGroupThisWeek => '本周';

  @override
  String get notesGroupThisMonth => '本月';

  @override
  String get notesGroupUnflagged => '未标记';

  @override
  String get notesSortDateNewest => '日期（最新优先）';

  @override
  String get notesSortDateOldest => '日期（最早优先）';

  @override
  String get notesSortLastModified => '最近修改';

  @override
  String get notesSortTitle => '标题（A → Z）';

  @override
  String get notesSortFlag => '旗标颜色';

  @override
  String get notesViewRows => '行样式';

  @override
  String get notesViewSort => '排序';

  @override
  String get helpNotesListTitle => '笔记';

  @override
  String get helpNotesListSummary =>
      '所有笔记都在一个列表里，按日期、标题或旗标分组。可在顶部栏搜索、筛选并选择行的显示方式。下拉即可同步。';

  @override
  String get helpNotesListViewTitle => '显示';

  @override
  String get helpNotesListViewBody =>
      '选择每行显示多少内容（紧凑、标准或丰富），以及列表的排序方式：按日期、最近修改、标题或旗标颜色。行样式只保存在本设备上。';

  @override
  String get helpNotesListPinnedTitle => '置顶区';

  @override
  String get helpNotesListPinnedBody =>
      '符合当前筛选和搜索的置顶笔记在任何排序下都显示在最上方，下方不会重复出现。可在笔记的 ⋯ 菜单中置顶。';

  @override
  String get helpNotesListDatesTitle => '日期分区';

  @override
  String get helpNotesListDatesBody =>
      '按日期排序时，笔记分为今天、昨天、本周、本月，之后按月份分组。滚动浏览某个分区时，它的标题会一直停留在顶部。';

  @override
  String get helpNotesListFlagsTitle => '旗标';

  @override
  String get helpNotesListFlagsBody =>
      '旗标用颜色标记笔记。按旗标颜色排序时，已标记的笔记按颜色分组，未标记的排在最后。';

  @override
  String get helpNotesListSearchTitle => '搜索';

  @override
  String get helpNotesListSearchBody =>
      '输入即可搜索标题、正文、标签以及笔记所附属的对象，匹配内容会高亮显示。返回时搜索仍然生效；点搜索框里的 × 即可清除。';

  @override
  String get helpNotesListFilterTitle => '侧边栏';

  @override
  String get helpNotesListFilterBody =>
      '打开侧边栏（☰）即可按已置顶、已标记（按颜色）、今天、领域、标签或智能筛选来筛选；数字表示各项包含的笔记数。长按你保存的搜索可重命名、移动或删除。在宽屏上，侧边栏会一直显示在列表旁，直到你用侧边栏按钮将其隐藏。';

  @override
  String get helpNotesListSidebarTitle => '隐藏侧边栏';

  @override
  String get helpNotesListSidebarBody =>
      '在宽屏上，侧边栏会显示在列表旁。轻点顶部的侧边栏按钮可将其隐藏，为打开的笔记腾出更多空间；再次轻点即可恢复。每台设备会分别记住自己的选择。';

  @override
  String get notesTokenHasPhoto => '含照片';

  @override
  String get notesTokenHasPlace => '含地点';

  @override
  String get notesTokenHasAttachment => '含附件';

  @override
  String get notesTokenPinned => '已置顶';

  @override
  String get notesTokenLast7d => '最近 7 天';

  @override
  String get notesTokenLast30d => '最近 30 天';

  @override
  String get notesTokenLast90d => '最近 90 天';

  @override
  String notesTokenFlag(String color) {
    return '$color旗标';
  }

  @override
  String notesTokenParent(String subject) {
    return '附属于$subject';
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
    return '$label（已移除）';
  }

  @override
  String notesTokenRemoveTooltip(String label) {
    return '移除$label';
  }

  @override
  String get notesTokenUnknown => '未知条件';

  @override
  String get notesRecentSearches => '最近搜索';

  @override
  String get notesRecentSearchesClear => '清除';

  @override
  String get notesScopeAll => '全部笔记';

  @override
  String notesScopeCurrent(String source) {
    return '在$source中';
  }

  @override
  String get notesSuggestionsHeader => '建议';

  @override
  String get helpNotesListTokensTitle => '搜索条件';

  @override
  String get helpNotesListTokensBody =>
      '输入时会出现标签、领域、笔记类型（如加油记录）、旗标、所属笔记、照片、地点和日期范围的建议。点按建议即可添加为条件；点按条件上的 ✕（或在外接键盘上于空白搜索框中按退格键）即可移除。启用筛选时，可选择在全部笔记或仅在该筛选中搜索。点按空白搜索框可查看最近的搜索。';

  @override
  String get notesNoMatchesFilters => '没有符合此搜索的笔记';

  @override
  String get notesSaveSearchTooltip => '保存搜索';

  @override
  String get notesSaveSearchTitle => '保存搜索';

  @override
  String get notesSaveSearchNameLabel => '名称';

  @override
  String get notesSaveSearchSave => '保存';

  @override
  String notesSavedSearchSaved(String name) {
    return '已保存“$name”';
  }

  @override
  String get notesSavedSearchSaveFailed => '无法保存搜索';

  @override
  String get notesSavedSearchUpdateFailed => '无法更新已保存的搜索';

  @override
  String get notesSavedSearchesHeader => '已保存的搜索';

  @override
  String get notesSavedSearchRename => '重命名';

  @override
  String get notesSavedSearchRenameTitle => '重命名已保存的搜索';

  @override
  String get notesSavedSearchMoveUp => '上移';

  @override
  String get notesSavedSearchMoveDown => '下移';

  @override
  String get notesSavedSearchDelete => '删除';

  @override
  String notesSavedSearchDeleted(String name) {
    return '已删除“$name”';
  }

  @override
  String get notesSavedSearchDeleteFailed => '无法删除已保存的搜索';

  @override
  String notesSavedSearchRestored(String name) {
    return '已恢复“$name”';
  }

  @override
  String get notesSavedSearchRestoreFailed => '无法恢复已保存的搜索';

  @override
  String get notesSavedSearchMissing => '此已保存的搜索已被删除';

  @override
  String get notesShowAllNotes => '显示全部笔记';

  @override
  String get helpNotesListSavedTitle => '已保存的搜索';

  @override
  String get helpNotesListSavedBody =>
      '点按搜索框旁的书签图标即可保存当前搜索，包括筛选和条件。已保存的搜索显示在侧边栏中；点按即可打开，长按可重命名、移动或删除。它们会同步到你的其他设备。';

  @override
  String get notesSmartWithPhotos => '含照片';

  @override
  String get notesSmartWithPlace => '含地点';

  @override
  String get notesSmartLast7d => '最近 7 天';

  @override
  String get notesSidebarDomains => '领域';

  @override
  String get notesSidebarTags => '标签';

  @override
  String get notesSidebarSmartFilters => '智能筛选';

  @override
  String get notesSidebarFlagged => '已标记';

  @override
  String get notesMenuTooltip => '筛选和列表';

  @override
  String get notesHideSidebarTooltip => '隐藏侧边栏';

  @override
  String get notesShowSidebarTooltip => '显示侧边栏';

  @override
  String get notesChipMoreTooltip => '更多筛选';

  @override
  String get helpNotesListChipsTitle => '快速筛选';

  @override
  String get helpNotesListChipsBody =>
      '搜索框下方的一行可在全部、已置顶、已标记以及你最常用的领域和标签之间切换；它会根据你的选择自动调整。再次点按已选中的条件即可回到全部，点按 ＋ 打开包含所有筛选的侧边栏。';

  @override
  String notesBulkDeleted(int count) {
    return '已删除 $count 条笔记';
  }

  @override
  String notesBulkDeletedSkipped(int count, int skipped) {
    return '已删除 $count 条 · 跳过 $skipped 条';
  }

  @override
  String notesBulkNothingDeleted(int count) {
    return '这些笔记需在各自的页面中管理';
  }

  @override
  String get notesBulkDeleteSomeFailed => '部分笔记无法删除，它们仍处于选中状态。';

  @override
  String notesBulkRestored(int count) {
    return '已恢复 $count 条笔记';
  }

  @override
  String get notesBulkRestoreFailed => '无法恢复这些笔记';

  @override
  String notesBulkPinPartial(int done, int total) {
    return '已置顶 $done/$total 条笔记';
  }

  @override
  String notesBulkUnpinPartial(int done, int total) {
    return '已取消置顶 $done/$total 条笔记';
  }

  @override
  String notesBulkFlagPartial(int done, int total) {
    return '已加旗标 $done/$total 条笔记';
  }

  @override
  String notesBulkUnflagPartial(int done, int total) {
    return '已移除旗标 $done/$total 条笔记';
  }

  @override
  String notesBulkTagPartial(int done, int total) {
    return '已为 $done/$total 条笔记设置标签';
  }

  @override
  String get notesBulkTagsTooltip => '标签';

  @override
  String get notesShareAction => '分享…';

  @override
  String notesShareFrom(String place) {
    return '请在$place中分享';
  }

  @override
  String get notesShareFailed => '无法分享笔记';

  @override
  String get notesShareVideoLabel => '视频';

  @override
  String get notesAttachToAction => '附加到…';

  @override
  String notesAttached(String title) {
    return '已附加到“$title”';
  }

  @override
  String get notesAttachFailed => '无法附加笔记';

  @override
  String get notesAttachUndone => '已撤销附加';

  @override
  String get notesAttachUndoFailed => '无法撤销附加';

  @override
  String get notesSelectAction => '选择';

  @override
  String get helpNotesListLongPressTitle => '长按笔记';

  @override
  String get helpNotesListLongPressBody =>
      '打开菜单，可置顶、加旗标、加标签、附加到另一条笔记、以文本分享、选择或删除。来自通讯录、卡片或汽车的笔记需在各自的页面中分享和删除。';

  @override
  String notesSelectedCount(int count) {
    return '已选 $count 项';
  }

  @override
  String get notesSelectAll => '全选';

  @override
  String get notesDoneAction => '完成';

  @override
  String get helpNotesListSelectTitle => '选择多条笔记';

  @override
  String get helpNotesListSelectBody =>
      '点按“编辑”（Android 上长按笔记并选择“选择”），然后点按笔记进行选择。可一次置顶、加旗标、设置标签或删除；“全选”会选中当前列表中的所有笔记。批量删除可一键撤销。删除时会跳过来自通讯录、卡片或汽车的笔记。';

  @override
  String get notesRecentlyDeletedTitle => '最近删除';

  @override
  String notesDeletesInDays(int days) {
    return '$days 天后删除';
  }

  @override
  String get notesRestoreAction => '恢复';

  @override
  String get notesMovedToRecentlyDeletedBanner => '这条笔记已移到“最近删除”';

  @override
  String get notesParentDeleted => '（已删除的笔记）';

  @override
  String get notesDeleteNow => '立即删除';

  @override
  String get notesDeleteNowTitle => '立即删除这条笔记？';

  @override
  String get notesDeleteForGoodBody => '它将从你的所有设备上移除，且无法撤销。';

  @override
  String get notesEmptyAction => '清空…';

  @override
  String notesEmptyTitle(int count) {
    return '立即删除 $count 条笔记？';
  }

  @override
  String get notesDeletedForGood => '笔记已永久删除';

  @override
  String notesEmptied(int count) {
    return '已永久删除 $count 条笔记';
  }

  @override
  String notesEmptyPartial(int done, int total) {
    return '已永久删除 $done/$total 条笔记';
  }

  @override
  String get notesKeptLiveElsewhere => '这条笔记已在其他设备上恢复，因此被保留';

  @override
  String get notesRecentlyDeletedEmpty => '没有最近删除的笔记';

  @override
  String get helpNotesRecentlyDeletedTitle => '最近删除';

  @override
  String get helpNotesRecentlyDeletedSummary => '删除的笔记会在这里保留 30 天，之后被永久删除。';

  @override
  String get helpNotesRecentlyDeletedRestoreTitle => '恢复';

  @override
  String get helpNotesRecentlyDeletedRestoreBody => '向右滑动笔记并点按“恢复”，即可将其放回笔记中。';

  @override
  String get helpNotesRecentlyDeletedDeleteNowTitle => '立即删除';

  @override
  String get helpNotesRecentlyDeletedDeleteNowBody =>
      '向左滑动笔记并点按“立即删除”，即可立即从所有设备上移除。此操作无法撤销。';

  @override
  String get helpNotesRecentlyDeletedEmptyTitle => '清空';

  @override
  String get helpNotesRecentlyDeletedEmptyBody => '从所有设备上移除此处列出的所有笔记。此操作无法撤销。';

  @override
  String get helpNotesListRecentlyDeletedTitle => '最近删除';

  @override
  String get helpNotesListRecentlyDeletedBody =>
      '打开侧边栏并点按“最近删除”，可在 30 天内恢复已删除的笔记。';

  @override
  String get notesTagsAction => '标签…';

  @override
  String get notesTagPickerTitle => '标签';

  @override
  String get notesTagPickerHint => '查找或新建标签';

  @override
  String notesTagCreate(String name) {
    return '新建“$name”';
  }

  @override
  String get notesTagPickerEmpty => '还没有标签。输入名称即可新建。';

  @override
  String get notesTagFailed => '无法更改笔记的标签';

  @override
  String get notesTagCreateFailed => '无法新建标签';

  @override
  String get notesEditorTagsLabel => '标签';

  @override
  String get notesEditorTagsHint => '添加标签';

  @override
  String notesEditorRemoveTag(String name) {
    return '移除标签 $name';
  }

  @override
  String get notesManageTagsTitle => '管理标签';

  @override
  String get notesManageTagsRow => '管理标签…';

  @override
  String notesManageTagsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条笔记',
    );
    return '$_temp0';
  }

  @override
  String get notesManageTagsEmpty => '还没有标签。可在笔记编辑器或长按菜单中添加。';

  @override
  String get notesRenameTag => '重命名…';

  @override
  String get notesRenameTagTitle => '重命名标签';

  @override
  String get notesMergeTag => '合并到…';

  @override
  String notesMergeTagConfirm(int count, String from, String to) {
    return '将 $count 条笔记从“$from”移到“$to”，并删除“$from”？';
  }

  @override
  String get notesMergeTagAction => '合并';

  @override
  String notesTagNameTaken(String name) {
    return '已有名为“$name”的标签。要合并到它吗？';
  }

  @override
  String get notesDeleteTag => '删除…';

  @override
  String notesDeleteTagConfirm(String name, int count) {
    return '删除标签“$name”？它将从 $count 条笔记中移除，笔记本身会保留。';
  }

  @override
  String get notesManageTagsFailed => '无法更改标签';

  @override
  String get helpManageTagsTitle => '管理标签';

  @override
  String get helpManageTagsSummary => '重命名、合并或删除标签。更改会应用到所有带有该标签的笔记。';

  @override
  String get helpManageTagsRenameTitle => '重命名';

  @override
  String get helpManageTagsRenameBody => '点按标签，然后选择重命名。如果新名称已被使用，可以把两个标签合并。';

  @override
  String get helpManageTagsMergeTitle => '合并';

  @override
  String get helpManageTagsMergeBody => '把所有笔记移到你选择的标签，并删除另一个标签。';

  @override
  String get helpManageTagsDeleteTitle => '删除';

  @override
  String get helpManageTagsDeleteBody => '从笔记中移除该标签，笔记本身会保留。';

  @override
  String get helpNotesListTagsTitle => '标签';

  @override
  String get helpNotesListTagsBody =>
      '可在笔记编辑器中或通过长按菜单的“标签…”添加标签。在侧边栏选择标签可查看其笔记；“管理标签…”可重命名、合并或删除标签。';

  @override
  String get notesVideoLinkUnavailable => '可能已无法观看';

  @override
  String get helpNoteDetailVideoLinkTitle => '视频链接';

  @override
  String get helpNoteDetailVideoLinkBody =>
      '单独一行的 YouTube 或哔哩哔哩链接会显示为卡片。点按即可在对应应用中观看；左上角的 ◀ Hmm 按钮可返回此笔记。';

  @override
  String get notesAddVideoLinkTooltip => '添加视频链接';

  @override
  String get notesAddVideoLinkTitle => '添加视频链接';

  @override
  String get notesAddVideoLinkHint => '粘贴 YouTube 或哔哩哔哩链接';

  @override
  String get notesAddVideoLinkAdd => '添加';

  @override
  String get notesAddVideoLinkInvalid => '这不是有效的链接';

  @override
  String get notesVideoPlay => '播放视频';

  @override
  String get notesVideoPause => '暂停';

  @override
  String get notesVideoFullScreen => '全屏';

  @override
  String get notesVideoNotOnDevice => '此视频目前仅保存在添加它的设备上。';

  @override
  String get notesVideoSaveToPhotos => '存储到照片';

  @override
  String get notesVideoKeepOffline => '离线保存';

  @override
  String get notesVideoKeepOfflineFailed => '无法更改离线保存';

  @override
  String get notesVideoKeepOfflineFetchFailed => '无法下载此视频，将在下次同步后重试。';

  @override
  String get notesVideoShare => '分享…';

  @override
  String get notesVideoRemove => '从笔记中移除';

  @override
  String get notesVideoSaved => '已存储到照片';

  @override
  String get notesVideoPhotosDenied => 'Hmm 无法存入照片，请在设置中允许。';

  @override
  String get notesVideoSaveFailed => '无法存储视频';

  @override
  String get notesVideoShareFailed => '无法分享视频';

  @override
  String get notesVideoRemoved => '已移除视频';

  @override
  String get notesVideoRemoveFailed => '无法移除视频';

  @override
  String get notesVideoRestored => '已恢复视频';

  @override
  String get notesVideoRestoreFailed => '无法恢复视频';

  @override
  String notesVideoUploading(String percent) {
    return '正在上传 $percent%';
  }

  @override
  String get notesVideoWaitingForWifi => '等待 Wi-Fi';

  @override
  String get notesVideoUploadRetry => '稍后将重试上传';

  @override
  String get notesVideoStillUploading => '另一台设备仍在上传';

  @override
  String get notesVideoMobileDataTitle => '使用移动数据上传？';

  @override
  String notesVideoMobileDataBody(String size) {
    return '此视频大小为 $size。现在上传将消耗等量的移动数据。';
  }

  @override
  String get notesVideoMobileDataUpload => '立即使用移动数据上传';

  @override
  String get notesVideoMobileDataCancel => '等待 Wi-Fi';

  @override
  String get notesVideoDownload => '下载并播放';

  @override
  String notesVideoDownloading(String percent) {
    return '正在下载 $percent%。轻点可取消。';
  }

  @override
  String get notesVideoDownloadFailed => '无法下载此视频';

  @override
  String get helpNoteDetailVideoTitle => '视频';

  @override
  String get helpNoteDetailVideoBody =>
      '轻点视频即可全屏播放。在 iPad 上会就地播放，提供播放/暂停、进度条和全屏按钮，全屏后从当前位置继续。启用 OneDrive 同步后，视频会在 Wi-Fi 下上传（轻点“等待 Wi-Fi”可立即使用移动数据上传）；上传完成前，其他设备会显示“另一台设备仍在上传”，完成后轻点播放即可下载。长按可离线保存、存储到照片、分享或移除。选择“离线保存”可将其永久保存在本设备。';

  @override
  String get notesAddVideoTooltip => '添加视频';

  @override
  String get notesVideoNeedsOneDrive => '视频目前需要 OneDrive 同步';

  @override
  String get notesVideoSensitiveBlocked => '含有敏感内容的笔记暂时不能添加视频';

  @override
  String get notesVideoTooLarge => '该视频超过 2 GB，无法添加';

  @override
  String get notesVideoUnsupported => '不支持该视频格式';

  @override
  String get notesVideoLargeTitle => '大视频';

  @override
  String notesVideoLargeBodyCloud(String size) {
    return '该视频大小为 $size，将占用相同的 OneDrive 空间。';
  }

  @override
  String notesVideoLargeBodyLocal(String size) {
    return '该视频大小为 $size，将占用本设备相同的存储空间。';
  }

  @override
  String get notesVideoAdd => '添加';

  @override
  String get notesVideoAddFailed => '部分视频无法添加，已跳过。';

  @override
  String notesVideoRemoveConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '从此笔记移除 $count 个视频？',
    );
    return '$_temp0';
  }

  @override
  String get notesVideoRemoveConfirmRemove => '移除';

  @override
  String get notesVideoRemoveConfirmKeep => '保留';

  @override
  String get settingsVideos => '视频';

  @override
  String settingsVideosUsage(String used, String limit) {
    return '$used / $limit';
  }

  @override
  String get videoStorageTitle => '视频';

  @override
  String get videoStorageDownloaded => '已下载';

  @override
  String get videoStorageKeptOffline => '离线保存';

  @override
  String videoStorageKeptSummary(int count, String size) {
    return '$count 个视频 · $size';
  }

  @override
  String get videoStorageMobileData => '使用移动数据上传';

  @override
  String get videoStorageMobileDataHint => '否则视频会等待 Wi-Fi。';

  @override
  String get videoStorageClear => '清除已下载的视频';

  @override
  String videoStorageClearConfirm(String size) {
    return '从本设备移除 $size 已下载的视频？离线保存的视频会保留，其他视频播放时会重新下载。';
  }

  @override
  String videoStorageCleared(String size) {
    return '已清除 $size';
  }

  @override
  String get videoStorageClearFailed => '无法清除已下载的视频';

  @override
  String get helpVideoStorageTitle => '视频';

  @override
  String get helpVideoStorageSummary => '查看已下载视频在本设备上占用的空间，并控制视频如何上传。';

  @override
  String get helpVideoStorageDownloadedTitle => '已下载';

  @override
  String get helpVideoStorageDownloadedBody =>
      '为在本设备播放而获取的视频。超出上限后，最久未使用的会自动清除。';

  @override
  String get helpVideoStorageKeptOfflineTitle => '离线保存';

  @override
  String get helpVideoStorageKeptOfflineBody => '你选择保存在本设备上的视频。它们不会被清除，也不计入上限。';

  @override
  String get helpVideoStorageMobileDataTitle => '使用移动数据上传';

  @override
  String get helpVideoStorageMobileDataBody =>
      '开启后，视频上传和离线保存的下载会使用移动数据。关闭时，它们会等待 Wi-Fi。';

  @override
  String get helpVideoStorageClearTitle => '清除已下载的视频';

  @override
  String get helpVideoStorageClearBody =>
      '从本设备移除已下载的视频。离线保存的视频会保留，其他视频播放时会重新下载。';

  @override
  String get calendarTitle => '日历';

  @override
  String get dashboardCalendarTitle => '日历';

  @override
  String get dashboardCalendarDescription => '日程与提醒';

  @override
  String get calendarToday => '今天';

  @override
  String get calendarAddEvent => '添加日程';

  @override
  String get calendarPreviousMonth => '上个月';

  @override
  String get calendarNextMonth => '下个月';

  @override
  String get calendarAllDay => '全天';

  @override
  String get calendarEmptyDay => '这一天没有安排。';

  @override
  String get calendarLoadFailed => '无法加载日历。';

  @override
  String get calendarCloudApiUnavailable => '日历可在“本地”和“云存储”模式下使用。请在设置中切换数据模式。';

  @override
  String get calendarMarkDone => '完成';

  @override
  String get calendarSkip => '跳过';

  @override
  String get calendarStatusDone => '已完成';

  @override
  String get calendarStatusSkipped => '已跳过';

  @override
  String get calendarStatusCancelled => '已删除';

  @override
  String get calendarRepeats => '重复';

  @override
  String get calendarOccurrenceDone => '已标记完成';

  @override
  String get calendarOccurrenceDoneFailed => '无法标记完成';

  @override
  String get calendarOccurrenceDoneUndone => '已取消完成标记';

  @override
  String get calendarOccurrenceSkipped => '已跳过';

  @override
  String get calendarOccurrenceSkippedFailed => '无法跳过';

  @override
  String get calendarOccurrenceSkippedUndone => '已取消跳过';

  @override
  String get calendarUndoFailed => '无法撤销';

  @override
  String get calendarHolidays => '节假日';

  @override
  String get calendarHolidayDayOff => '休息日';

  @override
  String get calendarHolidayWorkday => '工作日';

  @override
  String get calendarHolidayHide => '不是我的假日';

  @override
  String calendarHolidayHidden(String name) {
    return '已隐藏$name';
  }

  @override
  String calendarHolidayShown(String name) {
    return '已恢复$name';
  }

  @override
  String calendarHolidayHideFailed(String name) {
    return '无法隐藏$name';
  }

  @override
  String calendarHolidayShowFailed(String name) {
    return '无法恢复$name';
  }

  @override
  String get calendarHolidayUndoFailed => '无法撤销';

  @override
  String get calendarEdit => '编辑';

  @override
  String get calendarDeleteThis => '删除这一次';

  @override
  String get calendarDeleteSeries => '删除整个系列';

  @override
  String get calendarSeriesDeleted => '日程已删除';

  @override
  String get calendarSeriesDeleteFailed => '无法删除日程';

  @override
  String get calendarSeriesDeleteUndone => '日程已恢复';

  @override
  String get calendarUnreadableEvent => '有一个日程无法读取';

  @override
  String get calendarUnreadableEventHint => '它可能由更新版本的应用写入。';

  @override
  String get calendarPermissionBanner => '由于通知权限被拒绝，提醒已关闭。请在系统设置中开启。';

  @override
  String get calendarNewEvent => '新建日程';

  @override
  String get calendarEditEvent => '编辑日程';

  @override
  String get calendarSave => '保存';

  @override
  String get calendarSaveFailed => '无法保存日程';

  @override
  String get calendarTitleLabel => '标题';

  @override
  String get calendarTitleRequired => '请填写标题。';

  @override
  String get calendarStartLabel => '开始';

  @override
  String get calendarEndLabel => '结束';

  @override
  String get calendarPickDate => '选择日期';

  @override
  String get calendarPickTime => '选择时间';

  @override
  String get calendarPickerDone => '完成';

  @override
  String get calendarEndBeforeStart => '结束时间早于开始时间。';

  @override
  String get calendarNotesLabel => '备注';

  @override
  String get calendarRepeatLabel => '重复';

  @override
  String get calendarRepeatNone => '不重复';

  @override
  String get calendarRepeatDaily => '每天';

  @override
  String get calendarRepeatWeekly => '每周';

  @override
  String get calendarRepeatMonthly => '每月';

  @override
  String get calendarRepeatYearly => '每年';

  @override
  String get calendarRepeatEndLabel => '结束重复';

  @override
  String get calendarRepeatEndNever => '永不';

  @override
  String get calendarRepeatEndOnDate => '在某日';

  @override
  String get calendarRepeatEndAfter => '重复一定次数后';

  @override
  String get calendarRepeatCountLabel => '次数';

  @override
  String get calendarRepeatFewer => '减少次数';

  @override
  String get calendarRepeatMore => '增加次数';

  @override
  String get calendarRepeatClear => '清除';

  @override
  String get calendarRepeatReadOnlyHint => '此重复方式无法在这里修改。清除后可重新选择。';

  @override
  String get calendarDoesNotRepeat => '不重复';

  @override
  String get calendarRepeatCustom => '自定义重复';

  @override
  String get calendarRepeatLunar => '农历重复';

  @override
  String get calendarListSeparator => '、';

  @override
  String calendarRepeatDailyText(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '每$n天',
      one: '每天',
    );
    return '$_temp0';
  }

  @override
  String calendarRepeatWeeklyText(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '每$n周',
      one: '每周',
    );
    return '$_temp0';
  }

  @override
  String calendarRepeatWeeklyOnText(int n, String days) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '每$n周的$days',
      one: '每$days',
    );
    return '$_temp0';
  }

  @override
  String calendarRepeatMonthlyText(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '每$n个月',
      one: '每月',
    );
    return '$_temp0';
  }

  @override
  String calendarRepeatMonthlyOnText(int n, String days) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '每$n个月的$days日',
      one: '每月$days日',
    );
    return '$_temp0';
  }

  @override
  String calendarRepeatYearlyText(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '每$n年',
      one: '每年',
    );
    return '$_temp0';
  }

  @override
  String calendarRepeatOnDate(String date) {
    return '$date';
  }

  @override
  String calendarRepeatOnLunarDate(String date) {
    return '农历$date';
  }

  @override
  String calendarRepeatLunarYearlyText(int n, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '每$n年农历$date',
      one: '每年农历$date',
    );
    return '$_temp0';
  }

  @override
  String calendarRepeatTimes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '共$n次',
      one: '共1次',
    );
    return '$_temp0';
  }

  @override
  String calendarRepeatUntil(String date) {
    return '直到$date';
  }

  @override
  String calendarRepeatWithLimit(String rule, String limit) {
    return '$rule，$limit';
  }

  @override
  String get calendarRemindersLabel => '提醒';

  @override
  String get calendarNoReminders => '无提醒';

  @override
  String get calendarAddReminder => '添加提醒';

  @override
  String get calendarRemoveReminder => '删除提醒';

  @override
  String get calendarReminderAtStart => '开始时';

  @override
  String calendarReminderMinutes(int n) {
    return '提前$n分钟';
  }

  @override
  String calendarReminderHours(int n) {
    return '提前$n小时';
  }

  @override
  String calendarReminderDays(int n) {
    return '提前$n天';
  }

  @override
  String get calendarEditScopeTitle => '要修改哪些日程？';

  @override
  String get calendarEditThisOccurrence => '仅此一次';

  @override
  String get calendarEditAllOccurrences => '所有重复';

  @override
  String calendarFromSubsystem(String name) {
    return '来自$name';
  }

  @override
  String get calendarSubsystemDiabetes => '糖尿病';

  @override
  String get calendarSubsystemDriverLicence => '驾照';

  @override
  String get calendarSubsystemAutomobile => '车辆';

  @override
  String get calendarSubsystemInsurance => '保险';

  @override
  String get calendarSubsystemScheduledService => '保养';

  @override
  String get calendarSubsystemContacts => '联系人';

  @override
  String calendarOpenSource(String source) {
    return '打开$source';
  }

  @override
  String calendarLinkedChangeIn(String source) {
    return '请在$source中修改';
  }

  @override
  String get calendarOpenSourceGone => '已不存在';

  @override
  String get helpCalendarEventLinkedTitle => '关联日程';

  @override
  String get helpCalendarEventLinkedBody =>
      '为驾照、车辆、保单、保养或生日保留在日历上的日程。“打开”会进入它的来源，标题、日期和重复要在那里修改。这里可以改它的提醒、时间敏感和备注，也可以标记完成或跳过。它没有删除：请在来源中关闭。';

  @override
  String get helpCalendarEventEditLinkedTitle => '关联日程';

  @override
  String get helpCalendarEventEditLinkedBody =>
      '关联日程的标题、日期和重复由来源决定，这里不能修改。提醒、时间敏感和备注可以修改。';

  @override
  String get calendarDraftBanner => '建议的日程。批准后保留，并开始提醒。';

  @override
  String get calendarApprove => '批准';

  @override
  String get calendarApproveFailed => '无法批准日程';

  @override
  String get calendarEventNotFound => '此日程已不存在。';

  @override
  String get calendarEventNotFoundHint => '它可能已被删除。';

  @override
  String get calendarEventLoadFailed => '无法加载此日程。';

  @override
  String get calendarMoreActions => '更多操作';

  @override
  String get calendarDelete => '删除';

  @override
  String get calendarDeleteFollowing => '删除此次及以后';

  @override
  String get calendarOccurrenceDeleted => '已删除这一次';

  @override
  String get calendarOccurrenceDeleteFailed => '无法删除这一次';

  @override
  String get calendarOccurrenceDeleteUndone => '已恢复这一次';

  @override
  String get calendarFollowingDeleted => '已删除此次及以后';

  @override
  String get calendarFollowingDeleteFailed => '无法删除此次及以后';

  @override
  String get calendarFollowingDeleteUndone => '已恢复此次及以后';

  @override
  String get calendarOccurrenceLabel => '这一次';

  @override
  String get helpCalendarEventTitle => '日程';

  @override
  String get helpCalendarEventSummary => '一个日程：时间、重复方式、提醒和备注。';

  @override
  String get helpCalendarEventEditTitle => '编辑';

  @override
  String get helpCalendarEventEditBody => '打开编辑器。重复日程可以选择只改这一次或全部修改。';

  @override
  String get helpCalendarEventDoneTitle => '完成和跳过';

  @override
  String get helpCalendarEventDoneBody => '把打开的这一次标记为完成或跳过，它的提醒随之取消。几秒内可以撤销。';

  @override
  String get helpCalendarEventApproveTitle => '批准';

  @override
  String get helpCalendarEventApproveBody => '建议的日程在批准前不会提醒。';

  @override
  String get helpCalendarEventDeleteTitle => '删除';

  @override
  String get helpCalendarEventDeleteBody => '只删除这一次、删除这一次及以后，或删除整个系列。几秒内可以撤销。';

  @override
  String get helpCalendarEventEditScreenTitle => '编辑日程';

  @override
  String get helpCalendarEventEditScreenSummary => '设置标题、时间、重复和提醒，然后点保存。';

  @override
  String get helpCalendarEventEditAllDayTitle => '全天';

  @override
  String get helpCalendarEventEditAllDayBody => '全天日程只有日期没有时间，提醒从当天 09:00 起算。';

  @override
  String get helpCalendarEventEditTimeTitle => '开始和结束';

  @override
  String get helpCalendarEventEditTimeBody =>
      '点日期或时间进行修改。结束不能早于开始。一次性日程在出行时保持原来的时刻；重复日程保持钟面时间。';

  @override
  String get helpCalendarEventEditRepeatTitle => '重复';

  @override
  String get helpCalendarEventEditRepeatBody =>
      '选择重复频率和结束方式。每年重复可以按开始日期的农历日期：闰月日期在其他年份落在同名的普通月份，三十日在小月落在廿九。在其他地方设置的重复显示为\"自定义\"或\"农历\"，只能清除。';

  @override
  String get helpCalendarEventEditRemindersTitle => '提醒';

  @override
  String get helpCalendarEventEditRemindersBody =>
      '添加或删除提醒。提醒只在开启了“在此设备上提醒”的设备上响起。';

  @override
  String get calendarTimeSensitive => '时间敏感';

  @override
  String get calendarTimeSensitiveSubtitle => '可突破专注模式';

  @override
  String get helpCalendarEventEditTimeSensitiveTitle => '时间敏感';

  @override
  String get helpCalendarEventEditTimeSensitiveBody =>
      '让此日程的提醒在 iPhone 上突破专注模式。默认关闭。需要有一个在此设备上的提醒，并适用于所有重复。';

  @override
  String get calendarEventTitle => '日程';

  @override
  String get helpCalendarTitle => '日历';

  @override
  String get helpCalendarSummary => '按月和按天查看你的日程。选择一天即可看到当天的安排。';

  @override
  String get helpCalendarAddTitle => '添加日程';

  @override
  String get helpCalendarAddBody => '在所选日期新建一个日程。';

  @override
  String get helpCalendarMonthTitle => '月历';

  @override
  String get helpCalendarMonthBody =>
      '点按某一天查看当天日程。有圆点的日期表示有日程。用箭头切换月份。在设置中打开“显示农历”后，每天还会显示农历日期、节气或节日。';

  @override
  String get helpCalendarTodayTitle => '今天';

  @override
  String get helpCalendarTodayBody => '回到今天。';

  @override
  String get helpCalendarSwipeTitle => '滑动日程';

  @override
  String get helpCalendarSwipeBody => '向右滑动标记完成，向左滑动跳过。几秒内可以撤销。';

  @override
  String get helpCalendarHoldTitle => '长按日程';

  @override
  String get helpCalendarHoldBody => '打开菜单：编辑日程、只删除这一次，或删除整个系列。';

  @override
  String get calendarOpenSettings => '打开设置';

  @override
  String get settingsCalendarTitle => '日历';

  @override
  String get settingsCalendarRemindOnDevice => '在此设备上提醒';

  @override
  String get settingsCalendarRemindOnDeviceSubtitle =>
      '在此设备上以通知形式显示日历提醒。按设备设置，不会同步。';

  @override
  String get settingsCalendarShowLunar => '显示农历';

  @override
  String get settingsCalendarShowLunarSubtitle =>
      '在月历上显示农历日期、节气和传统节日。在你的设备间同步。';

  @override
  String get calendarRemindersTitle => '提醒';

  @override
  String get calendarRemindersEmpty => '过去 7 天没有提醒';

  @override
  String get calendarRemindersLoadFailed => '无法加载提醒。';

  @override
  String calendarRemindersFiredAt(String time) {
    return '$time 已提醒';
  }

  @override
  String get dashboardRemindersTooltip => '提醒';

  @override
  String get helpCalendarRemindersTitle => '提醒';

  @override
  String get helpCalendarRemindersSummary => '过去 7 天内在此设备上响起的提醒，最新的在前。';

  @override
  String get helpCalendarRemindersOpenTitle => '打开提醒';

  @override
  String get helpCalendarRemindersOpenBody => '点按一行即可打开该日程的这一次，可在那里标记完成或跳过。';

  @override
  String get helpCalendarRemindersBellTitle => '主屏幕上的铃铛';

  @override
  String get helpCalendarRemindersBellBody =>
      '铃铛和应用图标会显示自你上次打开此列表以来响起的提醒数量。打开列表后两者都会清零。关闭“在此设备上提醒”时不显示铃铛。';

  @override
  String get calendarHolidaysAdd => '添加国家或地区';

  @override
  String get calendarHolidaysWholeCountry => '全国';

  @override
  String calendarHolidaysUpdated(String date) {
    return '更新于 $date';
  }

  @override
  String calendarHolidaysNotPublished(int year) {
    return '$year 年尚未公布';
  }

  @override
  String get calendarHolidaysOffline => '无法加载国家列表，请检查网络连接。';

  @override
  String calendarHolidaysRemoved(String name) {
    return '已移除$name';
  }

  @override
  String calendarHolidaysRemoveFailed(String name) {
    return '无法移除$name';
  }

  @override
  String calendarHolidaysRestored(String name) {
    return '已恢复$name';
  }

  @override
  String get calendarHolidaysMine => '我的假日';

  @override
  String get calendarHolidaysSearch => '搜索';

  @override
  String get helpCalendarHolidaysTitle => '节假日';

  @override
  String get helpCalendarHolidaysSummary => '选择日历上显示哪些国家的公共假日。此列表会在你的设备间同步。';

  @override
  String get helpCalendarHolidaysAddTitle => '添加国家或地区';

  @override
  String get helpCalendarHolidaysAddBody =>
      '先选国家，如果它有各州或省的假日，再选州或省，或选“全国”。每个条目在日历上有各自的颜色。';

  @override
  String get helpCalendarHolidaysRemoveTitle => '移除国家或地区';

  @override
  String get helpCalendarHolidaysRemoveBody =>
      '向一侧滑动某一行即可移除。立即点按“撤销”可恢复，颜色和位置不变。';

  @override
  String get helpCalendarHolidaysMineTitle => '我的假日';

  @override
  String get helpCalendarHolidaysMineBody =>
      '添加你自己的日子，例如生日或公司休息日，也可以恢复你隐藏过的假日。';

  @override
  String get calendarMyHolidaysAdd => '添加假日';

  @override
  String get calendarMyHolidaysEdit => '编辑假日';

  @override
  String get calendarMyHolidaysName => '名称';

  @override
  String get calendarMyHolidaysOnce => '仅一次';

  @override
  String get calendarMyHolidaysYearly => '每年';

  @override
  String get calendarMyHolidaysEveryYear => '每年';

  @override
  String get calendarMyHolidaysStart => '开始日期';

  @override
  String get calendarMyHolidaysEnd => '结束日期（可选）';

  @override
  String get calendarMyHolidaysDayOff => '休息日';

  @override
  String calendarMyHolidaysDeleted(String name) {
    return '已删除$name';
  }

  @override
  String calendarMyHolidaysDeleteFailed(String name) {
    return '无法删除$name';
  }

  @override
  String calendarMyHolidaysRestored(String name) {
    return '已恢复$name';
  }

  @override
  String get calendarMyHolidaysHiddenSection => '已隐藏的假日';

  @override
  String get calendarMyHolidaysShowAgain => '重新显示';

  @override
  String get helpCalendarMyHolidaysTitle => '我的假日';

  @override
  String get helpCalendarMyHolidaysSummary =>
      '你自己的特别日子，以及你选择隐藏的已下载假日。两者都会在你的设备间同步。';

  @override
  String get helpCalendarMyHolidaysAddTitle => '添加假日';

  @override
  String get helpCalendarMyHolidaysAddBody =>
      '可以添加单独一天、连续几天，或每年重复的日子，并选择是否为休息日。点按条目可编辑，向一侧滑动可删除；点“撤销”可恢复。';

  @override
  String get helpCalendarMyHolidaysHiddenTitle => '已隐藏的假日';

  @override
  String get helpCalendarMyHolidaysHiddenBody =>
      '你在某天详情里隐藏的假日会列在这里。点“重新显示”即可让它回到日历上。';

  @override
  String get helpCalendarHolidaysMarksTitle => '日历上的假日';

  @override
  String get helpCalendarHolidaysMarksBody =>
      '“休”表示休息日，“班”表示调休上班日。多个国家会显示为彩色圆点。打开某一天可查看每个假日，对不适用于你的假日点“隐藏”。“节假日”按钮用来选择国家。';

  @override
  String get calendarMyHolidaysSaveFailed => '无法保存假日';

  @override
  String get calendarLinkedLicenceExpiry => '驾照到期';

  @override
  String calendarLinkedRegistrationExpiry(String vehicle) {
    return '$vehicle 行驶证到期';
  }

  @override
  String calendarLinkedInsuranceExpiry(String vehicle) {
    return '$vehicle 保险到期';
  }

  @override
  String calendarLinkedServiceDue(String vehicle, String service) {
    return '$vehicle：$service 到期';
  }

  @override
  String calendarLinkedBirthday(String name) {
    return '$name生日';
  }

  @override
  String calendarLinkedTurnsAge(int age) {
    return '$age岁';
  }

  @override
  String get activityKindWalk => '步行';

  @override
  String get activityKindRun => '跑步';

  @override
  String get activityKindCycling => '骑行';

  @override
  String get activityKindSwim => '游泳';

  @override
  String get activityKindGym => '健身';

  @override
  String get activityKindYoga => '瑜伽';

  @override
  String get activityKindOther => '其他';

  @override
  String get activityKindReading => '阅读';

  @override
  String get activityKindCoding => '编程';

  @override
  String get activityAreaHealth => '健康';

  @override
  String get activityAreaReading => '阅读';

  @override
  String get activityAreaDevelopment => '开发';

  @override
  String get activityIntensityLight => '轻度';

  @override
  String get activityIntensityModerate => '中等';

  @override
  String get activityIntensityVigorous => '剧烈';

  @override
  String get activityTitle => '活动';

  @override
  String get activityLogAction => '记录活动';

  @override
  String get activityEmpty => '这段时间没有活动。';

  @override
  String get activityFilterAll => '全部';

  @override
  String get activityToday => '今天';

  @override
  String get activityYesterday => '昨天';

  @override
  String get activityLoadEarlier => '加载更早的';

  @override
  String get activityDeleted => '活动已删除';

  @override
  String get activityDeleteFailed => '无法删除活动';

  @override
  String get activityDeleteUndone => '活动已恢复';

  @override
  String get activityUndoFailed => '无法撤销';

  @override
  String get activityDraftLabel => '草稿';

  @override
  String get activityCloudApiUnavailable =>
      '云端 API 模式暂不支持活动记录。请在设置中切换到本地或云存储模式后使用。';

  @override
  String get activityNotAvailableShort => '暂不可用';

  @override
  String get activityLoadFailed => '无法加载活动。';

  @override
  String activityMinutes(int minutes) {
    return '$minutes 分钟';
  }

  @override
  String activityHours(int hours) {
    return '$hours 小时';
  }

  @override
  String activityHoursMinutes(int hours, int minutes) {
    return '$hours 小时 $minutes 分钟';
  }

  @override
  String get dashboardActivityTitle => '活动';

  @override
  String activityActiveToday(String duration) {
    return '今日活动：$duration';
  }

  @override
  String get activityNoneToday => '今天还没有活动';

  @override
  String get helpActivityTitle => '活动';

  @override
  String get helpActivitySummary => '记录你做过的事：散步、锻炼、阅读和编程，按每项活动发生的日期分组。';

  @override
  String get helpActivityAddTitle => '记录活动';

  @override
  String get helpActivityAddBody => '新增一条记录：选择做了什么、用了多久、何时结束。点按记录可修改。';

  @override
  String get helpActivityFilterTitle => '按领域筛选';

  @override
  String get helpActivityFilterBody => '顶部的标签只显示健康、阅读或开发类记录。“全部”显示所有记录。';

  @override
  String get helpActivityDeleteTitle => '删除记录';

  @override
  String get helpActivityDeleteBody => '按住记录或向左轻扫即可删除。点按提示中的“撤销”可恢复。';

  @override
  String get helpActivityEditTitle => '记录活动';

  @override
  String get helpActivityEditSummary => '记录一项活动：做了什么、多长时间、什么时候。';

  @override
  String get helpActivityEditKindTitle => '类型';

  @override
  String get helpActivityEditKindBody => '选择你做的事，例如散步、健身或阅读。类型决定显示哪些其他字段。';

  @override
  String get activityNewTitle => '记录活动';

  @override
  String get activityEditTitle => '编辑活动';

  @override
  String get activityKindLabel => '类型';

  @override
  String get activityDurationLabel => '时长';

  @override
  String get activityDurationCustom => '自定义';

  @override
  String get activityEndedLabel => '结束时间';

  @override
  String get activityEndedInFuture => '结束时间不能晚于现在。';

  @override
  String get activityIntensityLabel => '强度';

  @override
  String get activityDistanceLabel => '距离';

  @override
  String get activityLinkLabel => '关联笔记';

  @override
  String get activityLinkNone => '无';

  @override
  String get activityLinkRemoved => '笔记已删除';

  @override
  String get activityLinkClear => '移除关联';

  @override
  String get activityNotesLabel => '备注';

  @override
  String get activitySave => '保存';

  @override
  String get activityDelete => '删除活动';

  @override
  String get activityUnknownKind => '未知类型';

  @override
  String get helpActivityEditDurationTitle => '时长';

  @override
  String get helpActivityEditDurationBody =>
      '点按 15、30、45 或 60 分钟，或点按自定义输入最长 24 小时的时长。设置类型和时长后即可保存。';

  @override
  String get helpActivityEditEndedTitle => '结束时间';

  @override
  String get helpActivityEditEndedBody => '你完成的时间，默认为现在；开始时间等于结束时间减去时长。不能晚于现在。';

  @override
  String get helpActivityEditLinkTitle => '关联笔记';

  @override
  String get helpActivityEditLinkBody =>
      '关联一条笔记，例如读的书或做的项目。如果该笔记之后被删除，记录会显示“笔记已删除”，关联仍会保留。';

  @override
  String get activityDurationMinutes => '分钟';

  @override
  String get activitySaveFailed => '无法保存活动';

  @override
  String get activityPlannedLabel => '计划的日程';

  @override
  String get activityPlannedNone => '无';

  @override
  String get activityPlannedMarkFailed => '已保存，但未能将日历中的日程标记为完成';

  @override
  String activityLoggedLine(String summary) {
    return '已记录：$summary';
  }

  @override
  String get helpActivityEditPlannedTitle => '计划的日程';

  @override
  String get helpActivityEditPlannedBody =>
      '选择这次活动对应的日历日程（昨天至未来 12 小时内）。开始时间会移到该日程的时间，保存后该日程会标记为完成。之后移除关联不会撤销标记。';

  @override
  String get helpCalendarEventLoggedTitle => '已记录';

  @override
  String get helpCalendarEventLoggedBody => '显示为此日程记录的活动。点按可打开该活动。';

  @override
  String get glucoseTitle => '血糖';

  @override
  String get glucoseLogAction => '记录读数';

  @override
  String get glucoseImportNow => '立即导入';

  @override
  String get glucoseImportFromHealth => '从“健康”导入';

  @override
  String get glucoseEmpty => '最近 90 天没有读数。';

  @override
  String get glucoseToday => '今天';

  @override
  String get glucoseYesterday => '昨天';

  @override
  String get glucoseDeleted => '读数已删除';

  @override
  String get glucoseDeleteFailed => '无法删除读数';

  @override
  String get glucoseDeleteUndone => '读数已恢复';

  @override
  String get glucoseUndoFailed => '无法撤销';

  @override
  String get glucoseCloudApiUnavailable =>
      '血糖记录暂不支持云 API 模式。请在设置中切换到本地或云存储后使用。';

  @override
  String get glucoseLoadFailed => '无法加载读数。';

  @override
  String get glucoseSetRange => '设置目标范围';

  @override
  String glucoseTargetRange(String low, String high, String unit) {
    return '目标 $low–$high $unit';
  }

  @override
  String get glucoseNothingFound =>
      '未找到读数。如果你使用血糖仪应用，请检查“健康”→“共享”→“App”→“Hmm”。';

  @override
  String glucoseImported(int count) {
    return '已导入 $count 条读数';
  }

  @override
  String get glucoseImportBusy => '正在同步，请稍后再试。';

  @override
  String get glucoseImportFailed => '无法导入读数。';

  @override
  String get glucoseImportWaitingForSync => '正在等待首次同步，请稍后再试。';

  @override
  String get glucoseContextFasting => '空腹';

  @override
  String get glucoseContextBeforeMeal => '餐前';

  @override
  String get glucoseContextAfterMeal => '餐后';

  @override
  String get glucoseContextBedtime => '睡前';

  @override
  String get glucoseContextOther => '其他';

  @override
  String get glucoseBandBelow => '偏低';

  @override
  String get glucoseBandIn => '达标';

  @override
  String get glucoseBandAbove => '偏高';

  @override
  String get glucoseFromHealth => '来自“健康”';

  @override
  String get glucoseTyped => '手动输入';

  @override
  String glucoseNoteTitle(String value) {
    return '血糖 $value';
  }

  @override
  String get helpGlucoseTitle => '血糖';

  @override
  String get helpGlucoseSummary => '你的血糖读数，按每次测量的日期分组。可以手动输入，也可以从“健康”导入。';

  @override
  String get helpGlucoseAddTitle => '记录读数';

  @override
  String get helpGlucoseAddBody => '手动添加一条读数：数值、时间和可选的标签。点按读数可修改。';

  @override
  String get helpGlucoseImportTitle => '立即导入';

  @override
  String get helpGlucoseImportBody => '在 iPhone 上，从“健康”复制新的血糖读数。你删除过的读数不会再回来。';

  @override
  String get helpGlucoseRangeTitle => '目标范围';

  @override
  String get helpGlucoseRangeBody =>
      '设置你自己的下限和上限，每条读数会显示偏低、达标或偏高。Hmm 不会建议任何范围。';

  @override
  String get helpGlucoseDeleteTitle => '删除读数';

  @override
  String get helpGlucoseDeleteBody => '按住读数或向左轻扫即可删除。点按提示中的“撤销”可恢复。';

  @override
  String get glucoseNewTitle => '记录读数';

  @override
  String get glucoseEditTitle => '读数';

  @override
  String get glucoseSave => '保存';

  @override
  String get glucoseSaveFailed => '无法保存读数。';

  @override
  String get glucoseValueLabel => '血糖';

  @override
  String glucoseValueOutOfRange(String min, String max, String unit) {
    return '请输入 $min 到 $max $unit 之间的数值。';
  }

  @override
  String get glucoseTimeLabel => '时间';

  @override
  String get glucoseTagLabel => '标签';

  @override
  String get glucoseTagClear => '清除标签';

  @override
  String get glucoseNotesLabel => '备注';

  @override
  String glucoseFromHealthSource(String source) {
    return '来自“健康” · $source';
  }

  @override
  String get glucoseRangeLow => '下限';

  @override
  String get glucoseRangeHigh => '上限';

  @override
  String get glucoseRangeSave => '保存';

  @override
  String get glucoseRangeSaveFailed => '无法保存目标范围。';

  @override
  String get glucoseRangeOrderError => '下限必须小于上限。';

  @override
  String get glucoseRangeClear => '清除目标范围';

  @override
  String get glucoseDisplayUnitLabel => '显示单位';

  @override
  String get glucoseImportOnDeviceLabel => '在此设备上从“健康”导入';

  @override
  String get glucoseSettingsSubtitle => '目标范围和单位';

  @override
  String get helpGlucoseEditTitle => '血糖读数';

  @override
  String get helpGlucoseEditSummary =>
      '手动输入读数，或修改已有读数的标签和备注。从“健康”导入的读数不能改数值和时间。';

  @override
  String get helpGlucoseEditValueTitle => '数值和单位';

  @override
  String get helpGlucoseEditValueBody =>
      '读数按你输入时的单位保存。可输入 20 到 600 mg/dL（1.1 到 33.3 mmol/L）。';

  @override
  String get helpGlucoseEditTimeTitle => '时间';

  @override
  String get helpGlucoseEditTimeBody => '读数的测量时间，默认是当前时间。';

  @override
  String get helpGlucoseEditTagTitle => '标签';

  @override
  String get helpGlucoseEditTagBody => '可选，说明测量时机：空腹、餐前、餐后、睡前或其他。再次点按已选标签即可清除。';

  @override
  String get helpGlucoseRangeSummary =>
      '你自己的目标范围、读数的显示单位，以及在 iPhone 上此设备是否从“健康”导入。';

  @override
  String get helpGlucoseRangeLowHighTitle => '下限和上限';

  @override
  String get helpGlucoseRangeLowHighBody =>
      '两端都算达标。下限必须小于上限。数值按字段下方所选的单位解读。Hmm 不会建议任何范围。';

  @override
  String get helpGlucoseRangeUnitTitle => '显示单位';

  @override
  String get helpGlucoseRangeUnitBody =>
      'mg/dL 或 mmol/L。读数按此单位显示。该选择会同步到你的其他设备。';

  @override
  String get helpGlucoseRangeImportTitle => '在此设备上导入';

  @override
  String get helpGlucoseRangeImportBody => '仅为此设备开启或关闭“健康”自动导入。';

  @override
  String glucoseTileLast(String value, String when) {
    return '最近：$value · $when';
  }

  @override
  String get glucoseTileNone => '暂无读数';

  @override
  String get settingsHomeScreen => '主屏幕';

  @override
  String get settingsHomeScreenSubtitle => '选择主屏幕上显示哪些图标';

  @override
  String get homeScreenSettingsHint => '隐藏的功能仍可在主屏幕搜索中输入 / 打开。这些选择在你的所有设备上一致。';

  @override
  String get homeScreenSettingsLastVisible => '至少要保留一个图标。';

  @override
  String get helpHomeScreenSettingsTitle => '主屏幕';

  @override
  String get helpHomeScreenSettingsSummary => '选择主屏幕上显示哪些图标。该选择会在你的各台设备间同步。';

  @override
  String get helpHomeScreenSettingsSwitchTitle => '图标开关';

  @override
  String get helpHomeScreenSettingsSwitchBody =>
      '关闭开关会把图标从主屏幕隐藏，打开则重新显示。隐藏的功能仍可在主屏幕搜索中输入 / 打开。';

  @override
  String get helpHomeScreenSettingsLastTitle => '最后一个图标';

  @override
  String get helpHomeScreenSettingsLastBody => '唯一可见的图标无法关闭，因此主屏幕不会变空。';

  @override
  String hmmSignInSheetTitle(String feature) {
    return '登录 Hmm 以使用$feature';
  }

  @override
  String get hmmSignInSheetBody => '你的数据仍保存在本设备上。登录只用于开启此功能。';

  @override
  String get hmmSignInAction => '登录';

  @override
  String get hmmFeatureReceiptScan => '云端 AI 扫描收据';

  @override
  String get hmmFeatureAddressLookup => '地址查询';

  @override
  String get hmmFeatureExchangeRates => '汇率';

  @override
  String get hmmFeatureCloud => 'Hmm 云';

  @override
  String get gasLogRatesNeedSignIn => '登录 Hmm 以换算货币';
}
