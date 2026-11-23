import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import 'help_models.dart';

export 'help_models.dart';

/// Every screen that has a "?" help sheet. Adding a value without a case in
/// [helpFor] does not compile.
enum HelpId {
  automobileHub,
  vehicleNotes,
  calendar,
  calendarEvent,
  calendarEventEdit,
  calendarReminders,
  calendarHolidays,
  calendarMyHolidays,
  contacts,
  contactDetail,
  contactEdit,
  cheatsheetWallet,
  cheatsheetDetail,
  cheatsheetDesigner,
  noteDetail,
  notesList,
  notesRecentlyDeleted,
  manageTags,
  videoStorage,
  activity,
  activityEdit,
  glucose,
  glucoseEdit,
  glucoseRange,
  homeScreenSettings,
}

ScreenHelp helpFor(HelpId id, AppLocalizations l) => switch (id) {
  HelpId.glucose => ScreenHelp(
    title: l.helpGlucoseTitle,
    summary: l.helpGlucoseSummary,
    entries: [
      HelpEntry(
        icon: Icons.add,
        title: l.helpGlucoseAddTitle,
        body: l.helpGlucoseAddBody,
      ),
      // Import from Apple Health exists on iOS only.
      if (defaultTargetPlatform == TargetPlatform.iOS)
        HelpEntry(
          icon: Icons.sync,
          title: l.helpGlucoseImportTitle,
          body: l.helpGlucoseImportBody,
        ),
      HelpEntry(
        icon: Icons.track_changes,
        title: l.helpGlucoseRangeTitle,
        body: l.helpGlucoseRangeBody,
      ),
      HelpEntry(
        icon: Icons.delete_outline,
        title: l.helpGlucoseDeleteTitle,
        body: l.helpGlucoseDeleteBody,
      ),
    ],
  ),
  HelpId.glucoseEdit => ScreenHelp(
    title: l.helpGlucoseEditTitle,
    summary: l.helpGlucoseEditSummary,
    entries: [
      HelpEntry(
        icon: Icons.bloodtype_outlined,
        title: l.helpGlucoseEditValueTitle,
        body: l.helpGlucoseEditValueBody,
      ),
      HelpEntry(
        icon: Icons.schedule,
        title: l.helpGlucoseEditTimeTitle,
        body: l.helpGlucoseEditTimeBody,
      ),
      HelpEntry(
        icon: Icons.label_outline,
        title: l.helpGlucoseEditTagTitle,
        body: l.helpGlucoseEditTagBody,
      ),
    ],
  ),
  HelpId.glucoseRange => ScreenHelp(
    title: l.helpGlucoseRangeTitle,
    summary: l.helpGlucoseRangeSummary,
    entries: [
      HelpEntry(
        icon: Icons.track_changes,
        title: l.helpGlucoseRangeLowHighTitle,
        body: l.helpGlucoseRangeLowHighBody,
      ),
      HelpEntry(
        icon: Icons.straighten,
        title: l.helpGlucoseRangeUnitTitle,
        body: l.helpGlucoseRangeUnitBody,
      ),
      // The switch exists on iOS only.
      if (defaultTargetPlatform == TargetPlatform.iOS)
        HelpEntry(
          icon: Icons.favorite_border,
          title: l.helpGlucoseRangeImportTitle,
          body: l.helpGlucoseRangeImportBody,
        ),
    ],
  ),
  HelpId.activity => ScreenHelp(
    title: l.helpActivityTitle,
    summary: l.helpActivitySummary,
    entries: [
      HelpEntry(
        icon: Icons.add,
        title: l.helpActivityAddTitle,
        body: l.helpActivityAddBody,
      ),
      HelpEntry(
        icon: Icons.filter_list,
        title: l.helpActivityFilterTitle,
        body: l.helpActivityFilterBody,
      ),
      HelpEntry(
        icon: Icons.delete_outline,
        title: l.helpActivityDeleteTitle,
        body: l.helpActivityDeleteBody,
      ),
    ],
  ),
  HelpId.activityEdit => ScreenHelp(
    title: l.helpActivityEditTitle,
    summary: l.helpActivityEditSummary,
    entries: [
      HelpEntry(
        icon: Icons.directions_walk,
        title: l.helpActivityEditKindTitle,
        body: l.helpActivityEditKindBody,
      ),
      HelpEntry(
        icon: Icons.timer_outlined,
        title: l.helpActivityEditDurationTitle,
        body: l.helpActivityEditDurationBody,
      ),
      HelpEntry(
        icon: Icons.schedule,
        title: l.helpActivityEditEndedTitle,
        body: l.helpActivityEditEndedBody,
      ),
      HelpEntry(
        icon: Icons.link,
        title: l.helpActivityEditLinkTitle,
        body: l.helpActivityEditLinkBody,
      ),
      HelpEntry(
        icon: Icons.event_available,
        title: l.helpActivityEditPlannedTitle,
        body: l.helpActivityEditPlannedBody,
      ),
    ],
  ),
  HelpId.automobileHub => ScreenHelp(
    title: l.helpAutomobileHubTitle,
    summary: l.helpAutomobileHubSummary,
    entries: [
      HelpEntry(
        icon: Icons.badge_outlined,
        title: l.helpAutomobileHubLicenceTitle,
        body: l.helpAutomobileHubLicenceBody,
      ),
      HelpEntry(
        icon: Icons.directions_car,
        title: l.helpAutomobileHubVehicleTitle,
        body: l.helpAutomobileHubVehicleBody,
      ),
      HelpEntry(
        icon: Icons.sticky_note_2_outlined,
        title: l.helpAutomobileHubNotesTitle,
        body: l.helpAutomobileHubNotesBody,
      ),
      HelpEntry(
        icon: Icons.local_gas_station_outlined,
        title: l.helpAutomobileHubFuelTitle,
        body: l.helpAutomobileHubFuelBody,
      ),
      HelpEntry(
        icon: Icons.settings,
        title: l.helpAutomobileHubManageTitle,
        body: l.helpAutomobileHubManageBody,
      ),
    ],
  ),
  HelpId.vehicleNotes => ScreenHelp(
    title: l.helpVehicleNotesTitle,
    summary: l.helpVehicleNotesSummary,
    entries: [
      HelpEntry(
        icon: Icons.add,
        title: l.helpVehicleNotesNewTitle,
        body: l.helpVehicleNotesNewBody,
      ),
      HelpEntry(
        icon: Icons.attach_file,
        title: l.helpVehicleNotesAttachTitle,
        body: l.helpVehicleNotesAttachBody,
      ),
      HelpEntry(
        icon: Icons.link_off,
        title: l.helpVehicleNotesDetachTitle,
        body: l.helpVehicleNotesDetachBody,
      ),
      HelpEntry(
        icon: Icons.touch_app_outlined,
        title: l.helpVehicleNotesOpenTitle,
        body: l.helpVehicleNotesOpenBody,
      ),
    ],
  ),
  HelpId.calendar => ScreenHelp(
    title: l.helpCalendarTitle,
    summary: l.helpCalendarSummary,
    entries: [
      HelpEntry(
        icon: Icons.add,
        title: l.helpCalendarAddTitle,
        body: l.helpCalendarAddBody,
      ),
      HelpEntry(
        icon: Icons.calendar_month_outlined,
        title: l.helpCalendarMonthTitle,
        body: l.helpCalendarMonthBody,
      ),
      HelpEntry(
        icon: Icons.today,
        title: l.helpCalendarTodayTitle,
        body: l.helpCalendarTodayBody,
      ),
      HelpEntry(
        icon: Icons.swipe,
        title: l.helpCalendarSwipeTitle,
        body: l.helpCalendarSwipeBody,
      ),
      HelpEntry(
        icon: Icons.touch_app_outlined,
        title: l.helpCalendarHoldTitle,
        body: l.helpCalendarHoldBody,
      ),
      HelpEntry(
        icon: Icons.flag_outlined,
        title: l.helpCalendarHolidaysMarksTitle,
        body: l.helpCalendarHolidaysMarksBody,
      ),
    ],
  ),
  HelpId.calendarEvent => ScreenHelp(
    title: l.helpCalendarEventTitle,
    summary: l.helpCalendarEventSummary,
    entries: [
      HelpEntry(
        icon: Icons.edit_outlined,
        title: l.helpCalendarEventEditTitle,
        body: l.helpCalendarEventEditBody,
      ),
      HelpEntry(
        icon: Icons.check,
        title: l.helpCalendarEventDoneTitle,
        body: l.helpCalendarEventDoneBody,
      ),
      HelpEntry(
        icon: Icons.check_circle_outline,
        title: l.helpCalendarEventApproveTitle,
        body: l.helpCalendarEventApproveBody,
      ),
      HelpEntry(
        icon: Icons.more_vert,
        title: l.helpCalendarEventDeleteTitle,
        body: l.helpCalendarEventDeleteBody,
      ),
      HelpEntry(
        icon: Icons.link,
        title: l.helpCalendarEventLinkedTitle,
        body: l.helpCalendarEventLinkedBody,
      ),
      HelpEntry(
        icon: Icons.directions_run,
        title: l.helpCalendarEventLoggedTitle,
        body: l.helpCalendarEventLoggedBody,
      ),
    ],
  ),
  HelpId.calendarEventEdit => ScreenHelp(
    title: l.helpCalendarEventEditScreenTitle,
    summary: l.helpCalendarEventEditScreenSummary,
    entries: [
      HelpEntry(
        icon: Icons.wb_sunny_outlined,
        title: l.helpCalendarEventEditAllDayTitle,
        body: l.helpCalendarEventEditAllDayBody,
      ),
      HelpEntry(
        icon: Icons.schedule,
        title: l.helpCalendarEventEditTimeTitle,
        body: l.helpCalendarEventEditTimeBody,
      ),
      HelpEntry(
        icon: Icons.repeat,
        title: l.helpCalendarEventEditRepeatTitle,
        body: l.helpCalendarEventEditRepeatBody,
      ),
      HelpEntry(
        icon: Icons.add_alert_outlined,
        title: l.helpCalendarEventEditRemindersTitle,
        body: l.helpCalendarEventEditRemindersBody,
      ),
      HelpEntry(
        icon: Icons.notification_important_outlined,
        title: l.helpCalendarEventEditTimeSensitiveTitle,
        body: l.helpCalendarEventEditTimeSensitiveBody,
      ),
      HelpEntry(
        icon: Icons.link,
        title: l.helpCalendarEventEditLinkedTitle,
        body: l.helpCalendarEventEditLinkedBody,
      ),
    ],
  ),
  HelpId.calendarReminders => ScreenHelp(
    title: l.helpCalendarRemindersTitle,
    summary: l.helpCalendarRemindersSummary,
    entries: [
      HelpEntry(
        icon: Icons.touch_app_outlined,
        title: l.helpCalendarRemindersOpenTitle,
        body: l.helpCalendarRemindersOpenBody,
      ),
      HelpEntry(
        icon: Icons.notifications_outlined,
        title: l.helpCalendarRemindersBellTitle,
        body: l.helpCalendarRemindersBellBody,
      ),
    ],
  ),
  HelpId.calendarHolidays => ScreenHelp(
    title: l.helpCalendarHolidaysTitle,
    summary: l.helpCalendarHolidaysSummary,
    entries: [
      HelpEntry(
        icon: Icons.add,
        title: l.helpCalendarHolidaysAddTitle,
        body: l.helpCalendarHolidaysAddBody,
      ),
      HelpEntry(
        icon: Icons.swipe,
        title: l.helpCalendarHolidaysRemoveTitle,
        body: l.helpCalendarHolidaysRemoveBody,
      ),
      HelpEntry(
        icon: Icons.edit_calendar_outlined,
        title: l.helpCalendarHolidaysMineTitle,
        body: l.helpCalendarHolidaysMineBody,
      ),
    ],
  ),
  HelpId.calendarMyHolidays => ScreenHelp(
    title: l.helpCalendarMyHolidaysTitle,
    summary: l.helpCalendarMyHolidaysSummary,
    entries: [
      HelpEntry(
        icon: Icons.add,
        title: l.helpCalendarMyHolidaysAddTitle,
        body: l.helpCalendarMyHolidaysAddBody,
      ),
      HelpEntry(
        icon: Icons.visibility_outlined,
        title: l.helpCalendarMyHolidaysHiddenTitle,
        body: l.helpCalendarMyHolidaysHiddenBody,
      ),
    ],
  ),
  HelpId.contacts => ScreenHelp(
    title: l.helpContactsTitle,
    summary: l.helpContactsSummary,
    entries: [
      HelpEntry(
        icon: Icons.add,
        title: l.helpContactsAddTitle,
        body: l.helpContactsAddBody,
      ),
      HelpEntry(
        icon: Icons.search,
        title: l.helpContactsSearchTitle,
        body: l.helpContactsSearchBody,
      ),
      HelpEntry(
        icon: Icons.sort_by_alpha,
        title: l.helpContactsSortTitle,
        body: l.helpContactsSortBody,
      ),
      HelpEntry(
        icon: Icons.person_outline,
        title: l.helpContactsSelfTitle,
        body: l.helpContactsSelfBody,
      ),
    ],
  ),
  HelpId.contactDetail => ScreenHelp(
    title: l.helpContactDetailTitle,
    summary: l.helpContactDetailSummary,
    entries: [
      HelpEntry(
        icon: Icons.call,
        title: l.helpContactDetailCallTitle,
        body: l.helpContactDetailCallBody,
      ),
      HelpEntry(
        icon: Icons.map_outlined,
        title: l.helpContactDetailMapTitle,
        body: l.helpContactDetailMapBody,
      ),
      HelpEntry(
        icon: Icons.edit_outlined,
        title: l.helpContactDetailEditTitle,
        body: l.helpContactDetailEditBody,
      ),
      HelpEntry(
        icon: Icons.delete_outline,
        title: l.helpContactDetailRemoveTitle,
        body: l.helpContactDetailRemoveBody,
      ),
      HelpEntry(
        icon: Icons.notifications_active,
        title: l.helpContactDetailRemindTitle,
        body: l.helpContactDetailRemindBody,
      ),
    ],
  ),
  HelpId.contactEdit => ScreenHelp(
    title: l.helpContactEditTitle,
    summary: l.helpContactEditSummary,
    entries: [
      HelpEntry(
        icon: Icons.person_outline,
        title: l.helpContactEditTypeTitle,
        body: l.helpContactEditTypeBody,
      ),
      HelpEntry(
        icon: Icons.translate,
        title: l.helpContactEditNameOptionsTitle,
        body: l.helpContactEditNameOptionsBody,
      ),
      HelpEntry(
        icon: Icons.language,
        title: l.helpContactEditEnglishNameTitle,
        body: l.helpContactEditEnglishNameBody,
      ),
      HelpEntry(
        icon: Icons.add,
        title: l.helpContactEditFieldsTitle,
        body: l.helpContactEditFieldsBody,
      ),
      HelpEntry(
        icon: Icons.public,
        title: l.helpContactEditAddressTitle,
        body: l.helpContactEditAddressBody,
      ),
      HelpEntry(
        icon: Icons.arrow_drop_down,
        title: l.helpContactEditRelationshipTitle,
        body: l.helpContactEditRelationshipBody,
      ),
      HelpEntry(
        icon: Icons.cake,
        title: l.helpContactEditBirthdayTitle,
        body: l.helpContactEditBirthdayBody,
      ),
      HelpEntry(
        icon: Icons.person_pin_outlined,
        title: l.helpContactEditSelfTitle,
        body: l.helpContactEditSelfBody,
      ),
    ],
  ),
  HelpId.cheatsheetWallet => ScreenHelp(
    title: l.helpCheatsheetWalletTitle,
    summary: l.helpCheatsheetWalletSummary,
    entries: [
      HelpEntry(
        icon: Icons.touch_app_outlined,
        title: l.helpCheatsheetWalletTilesTitle,
        body: l.helpCheatsheetWalletTilesBody,
      ),
      HelpEntry(
        icon: Icons.filter_list,
        title: l.helpCheatsheetWalletGroupsTitle,
        body: l.helpCheatsheetWalletGroupsBody,
      ),
      HelpEntry(
        icon: Icons.label_outline,
        title: l.helpCheatsheetWalletTagsTitle,
        body: l.helpCheatsheetWalletTagsBody,
      ),
      HelpEntry(
        icon: Icons.lock_outline,
        title: l.helpCheatsheetWalletLockTitle,
        body: l.helpCheatsheetWalletLockBody,
      ),
    ],
  ),
  HelpId.cheatsheetDetail => ScreenHelp(
    title: l.helpCheatsheetDetailTitle,
    summary: l.helpCheatsheetDetailSummary,
    entries: [
      HelpEntry(
        icon: Icons.list_alt,
        title: l.helpCheatsheetDetailFactsTitle,
        body: l.helpCheatsheetDetailFactsBody,
      ),
      HelpEntry(
        icon: Icons.format_list_numbered,
        title: l.helpCheatsheetDetailKeyPointsTitle,
        body: l.helpCheatsheetDetailKeyPointsBody,
      ),
      HelpEntry(
        icon: Icons.open_in_new,
        title: l.helpCheatsheetDetailOpenSourceTitle,
        body: l.helpCheatsheetDetailOpenSourceBody,
      ),
      HelpEntry(
        icon: Icons.image_outlined,
        title: l.helpCheatsheetDetailHeaderTitle,
        body: l.helpCheatsheetDetailHeaderBody,
      ),
      HelpEntry(
        icon: Icons.lock_outline,
        title: l.helpCheatsheetDetailLockTitle,
        body: l.helpCheatsheetDetailLockBody,
      ),
    ],
  ),
  HelpId.cheatsheetDesigner => ScreenHelp(
    title: l.helpCheatsheetDesignerTitle,
    summary: l.helpCheatsheetDesignerSummary,
    entries: [
      HelpEntry(
        icon: Icons.palette_outlined,
        title: l.helpCheatsheetDesignerLookTitle,
        body: l.helpCheatsheetDesignerLookBody,
      ),
      HelpEntry(
        icon: Icons.emoji_emotions_outlined,
        title: l.helpCheatsheetDesignerIconTitle,
        body: l.helpCheatsheetDesignerIconBody,
      ),
      HelpEntry(
        icon: Icons.add_photo_alternate_outlined,
        title: l.helpCheatsheetDesignerCoverTitle,
        body: l.helpCheatsheetDesignerCoverBody,
      ),
      HelpEntry(
        icon: Icons.format_list_numbered,
        title: l.helpCheatsheetDesignerLayoutTitle,
        body: l.helpCheatsheetDesignerLayoutBody,
      ),
      HelpEntry(
        icon: Icons.link,
        title: l.helpCheatsheetDesignerSourceTitle,
        body: l.helpCheatsheetDesignerSourceBody,
      ),
      HelpEntry(
        icon: Icons.add_reaction_outlined,
        title: l.helpCheatsheetDesignerRowEmojiTitle,
        body: l.helpCheatsheetDesignerRowEmojiBody,
      ),
      HelpEntry(
        icon: Icons.format_color_reset_outlined,
        title: l.helpCheatsheetDesignerResetTitle,
        body: l.helpCheatsheetDesignerResetBody,
      ),
    ],
  ),
  HelpId.noteDetail => ScreenHelp(
    title: l.helpNoteDetailTitle,
    summary: l.helpNoteDetailSummary,
    entries: [
      HelpEntry(
        icon: Icons.push_pin_outlined,
        title: l.helpNoteDetailPinTitle,
        body: l.helpNoteDetailPinBody,
      ),
      HelpEntry(
        icon: Icons.flag_outlined,
        title: l.helpNoteDetailFlagTitle,
        body: l.helpNoteDetailFlagBody,
      ),
      HelpEntry(
        icon: Icons.delete_outline,
        title: l.helpNoteDetailDeleteTitle,
        body: l.helpNoteDetailDeleteBody,
      ),
      HelpEntry(
        icon: Icons.restore,
        title: l.helpNoteDetailRestoreTitle,
        body: l.helpNoteDetailRestoreBody,
      ),
      HelpEntry(
        icon: Icons.open_in_full,
        title: l.helpNoteDetailExpandTitle,
        body: l.helpNoteDetailExpandBody,
      ),
      HelpEntry(
        icon: Icons.open_in_new,
        title: l.helpNoteDetailManageTitle,
        body: l.helpNoteDetailManageBody,
      ),
      HelpEntry(
        icon: Icons.smart_display_outlined,
        title: l.helpNoteDetailVideoLinkTitle,
        body: l.helpNoteDetailVideoLinkBody,
      ),
      HelpEntry(
        icon: Icons.videocam_outlined,
        title: l.helpNoteDetailVideoTitle,
        body: l.helpNoteDetailVideoBody,
      ),
    ],
  ),
  HelpId.notesRecentlyDeleted => ScreenHelp(
    title: l.helpNotesRecentlyDeletedTitle,
    summary: l.helpNotesRecentlyDeletedSummary,
    entries: [
      HelpEntry(
        icon: Icons.restore,
        title: l.helpNotesRecentlyDeletedRestoreTitle,
        body: l.helpNotesRecentlyDeletedRestoreBody,
      ),
      HelpEntry(
        icon: Icons.delete_forever,
        title: l.helpNotesRecentlyDeletedDeleteNowTitle,
        body: l.helpNotesRecentlyDeletedDeleteNowBody,
      ),
      HelpEntry(
        icon: Icons.delete_sweep,
        title: l.helpNotesRecentlyDeletedEmptyTitle,
        body: l.helpNotesRecentlyDeletedEmptyBody,
      ),
    ],
  ),
  HelpId.manageTags => ScreenHelp(
    title: l.helpManageTagsTitle,
    summary: l.helpManageTagsSummary,
    entries: [
      HelpEntry(
        icon: Icons.edit_outlined,
        title: l.helpManageTagsRenameTitle,
        body: l.helpManageTagsRenameBody,
      ),
      HelpEntry(
        icon: Icons.merge,
        title: l.helpManageTagsMergeTitle,
        body: l.helpManageTagsMergeBody,
      ),
      HelpEntry(
        icon: Icons.delete_outline,
        title: l.helpManageTagsDeleteTitle,
        body: l.helpManageTagsDeleteBody,
      ),
    ],
  ),
  HelpId.homeScreenSettings => ScreenHelp(
    title: l.helpHomeScreenSettingsTitle,
    summary: l.helpHomeScreenSettingsSummary,
    entries: [
      HelpEntry(
        icon: Icons.visibility_outlined,
        title: l.helpHomeScreenSettingsSwitchTitle,
        body: l.helpHomeScreenSettingsSwitchBody,
      ),
      HelpEntry(
        icon: Icons.lock_outline,
        title: l.helpHomeScreenSettingsLastTitle,
        body: l.helpHomeScreenSettingsLastBody,
      ),
    ],
  ),
  HelpId.videoStorage => ScreenHelp(
    title: l.helpVideoStorageTitle,
    summary: l.helpVideoStorageSummary,
    entries: [
      HelpEntry(
        icon: Icons.download_done_outlined,
        title: l.helpVideoStorageDownloadedTitle,
        body: l.helpVideoStorageDownloadedBody,
      ),
      HelpEntry(
        icon: Icons.offline_pin_outlined,
        title: l.helpVideoStorageKeptOfflineTitle,
        body: l.helpVideoStorageKeptOfflineBody,
      ),
      HelpEntry(
        icon: Icons.cell_tower,
        title: l.helpVideoStorageMobileDataTitle,
        body: l.helpVideoStorageMobileDataBody,
      ),
      HelpEntry(
        icon: Icons.delete_sweep_outlined,
        title: l.helpVideoStorageClearTitle,
        body: l.helpVideoStorageClearBody,
      ),
    ],
  ),
  HelpId.notesList => ScreenHelp(
    title: l.helpNotesListTitle,
    summary: l.helpNotesListSummary,
    entries: [
      HelpEntry(
        icon: Icons.tune,
        title: l.helpNotesListViewTitle,
        body: l.helpNotesListViewBody,
      ),
      HelpEntry(
        icon: Icons.push_pin,
        title: l.helpNotesListPinnedTitle,
        body: l.helpNotesListPinnedBody,
      ),
      HelpEntry(
        icon: Icons.calendar_today,
        title: l.helpNotesListDatesTitle,
        body: l.helpNotesListDatesBody,
      ),
      HelpEntry(
        icon: Icons.flag,
        title: l.helpNotesListFlagsTitle,
        body: l.helpNotesListFlagsBody,
      ),
      HelpEntry(
        icon: Icons.checklist,
        title: l.helpNotesListSelectTitle,
        body: l.helpNotesListSelectBody,
      ),
      HelpEntry(
        icon: Icons.search,
        title: l.helpNotesListSearchTitle,
        body: l.helpNotesListSearchBody,
      ),
      HelpEntry(
        icon: Icons.manage_search,
        title: l.helpNotesListTokensTitle,
        body: l.helpNotesListTokensBody,
      ),
      HelpEntry(
        icon: Icons.bookmark_add_outlined,
        title: l.helpNotesListSavedTitle,
        body: l.helpNotesListSavedBody,
      ),
      HelpEntry(
        icon: Icons.menu,
        title: l.helpNotesListFilterTitle,
        body: l.helpNotesListFilterBody,
      ),
      HelpEntry(
        icon: Icons.view_sidebar_outlined,
        title: l.helpNotesListSidebarTitle,
        body: l.helpNotesListSidebarBody,
      ),
      HelpEntry(
        icon: Icons.add,
        title: l.helpNotesListChipsTitle,
        body: l.helpNotesListChipsBody,
      ),
      HelpEntry(
        icon: Icons.swipe,
        title: l.helpNotesListSwipesTitle,
        body: l.helpNotesListSwipesBody,
      ),
      HelpEntry(
        icon: Icons.touch_app,
        title: l.helpNotesListLongPressTitle,
        body: l.helpNotesListLongPressBody,
      ),
      HelpEntry(
        icon: Icons.delete_outline,
        title: l.helpNotesListRecentlyDeletedTitle,
        body: l.helpNotesListRecentlyDeletedBody,
      ),
      HelpEntry(
        icon: Icons.label_outline,
        title: l.helpNotesListTagsTitle,
        body: l.helpNotesListTagsBody,
      ),
    ],
  ),
};
