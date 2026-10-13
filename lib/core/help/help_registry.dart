import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import 'help_models.dart';

export 'help_models.dart';

/// Every screen that has a "?" help sheet. Adding a value without a case in
/// [helpFor] does not compile.
enum HelpId {
  automobileHub,
  vehicleNotes,
  contacts,
  contactDetail,
  contactEdit,
  cheatsheetWallet,
  cheatsheetDetail,
  cheatsheetDesigner,
}

ScreenHelp helpFor(HelpId id, AppLocalizations l) => switch (id) {
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
};
