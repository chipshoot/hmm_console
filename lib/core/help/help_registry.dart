import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import 'help_models.dart';

export 'help_models.dart';

/// Every screen that has a "?" help sheet. Adding a value without a case in
/// [helpFor] does not compile.
enum HelpId { automobileHub, vehicleNotes }

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
    };
