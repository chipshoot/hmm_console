import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import 'help_models.dart';

export 'help_models.dart';

/// Every screen that has a "?" help sheet. Adding a value without a case in
/// [helpFor] does not compile.
enum HelpId { automobileHub, vehicleNotes, contacts, contactDetail, contactEdit }

ScreenHelp helpFor(HelpId id, AppLocalizations l) => switch (id) {
      HelpId.automobileHub => ScreenHelp(
          title: l.helpAutomobileHubTitle,
          summary: l.helpAutomobileHubSummary,
          entries: [
            HelpEntry(
                icon: Icons.badge_outlined,
                title: l.helpAutomobileHubLicenceTitle,
                body: l.helpAutomobileHubLicenceBody),
            HelpEntry(
                icon: Icons.directions_car,
                title: l.helpAutomobileHubVehicleTitle,
                body: l.helpAutomobileHubVehicleBody),
            HelpEntry(
                icon: Icons.sticky_note_2_outlined,
                title: l.helpAutomobileHubNotesTitle,
                body: l.helpAutomobileHubNotesBody),
            HelpEntry(
                icon: Icons.local_gas_station_outlined,
                title: l.helpAutomobileHubFuelTitle,
                body: l.helpAutomobileHubFuelBody),
            HelpEntry(
                icon: Icons.settings,
                title: l.helpAutomobileHubManageTitle,
                body: l.helpAutomobileHubManageBody),
          ],
        ),
      HelpId.vehicleNotes => ScreenHelp(
          title: l.helpVehicleNotesTitle,
          summary: l.helpVehicleNotesSummary,
          entries: [
            HelpEntry(
                icon: Icons.add,
                title: l.helpVehicleNotesNewTitle,
                body: l.helpVehicleNotesNewBody),
            HelpEntry(
                icon: Icons.attach_file,
                title: l.helpVehicleNotesAttachTitle,
                body: l.helpVehicleNotesAttachBody),
            HelpEntry(
                icon: Icons.link_off,
                title: l.helpVehicleNotesDetachTitle,
                body: l.helpVehicleNotesDetachBody),
            HelpEntry(
                icon: Icons.touch_app_outlined,
                title: l.helpVehicleNotesOpenTitle,
                body: l.helpVehicleNotesOpenBody),
          ],
        ),
      HelpId.contacts => ScreenHelp(
          title: l.helpContactsTitle,
          summary: l.helpContactsSummary,
          entries: [
            HelpEntry(
                icon: Icons.add,
                title: l.helpContactsAddTitle,
                body: l.helpContactsAddBody),
            HelpEntry(
                icon: Icons.search,
                title: l.helpContactsSearchTitle,
                body: l.helpContactsSearchBody),
            HelpEntry(
                icon: Icons.person_outline,
                title: l.helpContactsSelfTitle,
                body: l.helpContactsSelfBody),
          ],
        ),
      HelpId.contactDetail => ScreenHelp(
          title: l.helpContactDetailTitle,
          summary: l.helpContactDetailSummary,
          entries: [
            HelpEntry(
                icon: Icons.call,
                title: l.helpContactDetailCallTitle,
                body: l.helpContactDetailCallBody),
            HelpEntry(
                icon: Icons.map_outlined,
                title: l.helpContactDetailMapTitle,
                body: l.helpContactDetailMapBody),
            HelpEntry(
                icon: Icons.edit_outlined,
                title: l.helpContactDetailEditTitle,
                body: l.helpContactDetailEditBody),
            HelpEntry(
                icon: Icons.delete_outline,
                title: l.helpContactDetailRemoveTitle,
                body: l.helpContactDetailRemoveBody),
          ],
        ),
      HelpId.contactEdit => ScreenHelp(
          title: l.helpContactEditTitle,
          summary: l.helpContactEditSummary,
          entries: [
            HelpEntry(
                icon: Icons.person_outline,
                title: l.helpContactEditTypeTitle,
                body: l.helpContactEditTypeBody),
            HelpEntry(
                icon: Icons.add,
                title: l.helpContactEditFieldsTitle,
                body: l.helpContactEditFieldsBody),
            HelpEntry(
                icon: Icons.public,
                title: l.helpContactEditAddressTitle,
                body: l.helpContactEditAddressBody),
            HelpEntry(
                icon: Icons.arrow_drop_down,
                title: l.helpContactEditRelationshipTitle,
                body: l.helpContactEditRelationshipBody),
            HelpEntry(
                icon: Icons.person_pin_outlined,
                title: l.helpContactEditSelfTitle,
                body: l.helpContactEditSelfBody),
          ],
        ),
    };
