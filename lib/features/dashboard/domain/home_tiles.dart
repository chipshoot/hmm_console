import '../../../domain/entities/app_function.dart';
import '../../../l10n/gen/app_localizations.dart';

/// The home-screen tiles, in display order. A tile's [AppFunction.route] is
/// its stable id (what the synced hidden set stores).
final List<AppFunction> homeTiles = [
  AppFunction(
    icon: "🚗",
    title: "Automobile",
    description: "Licence, vehicles, gas log",
    route: "automobile",
  ),
  AppFunction(
    icon: "💰",
    title: "Expenses",
    description: "Track spending",
    route: "expenses",
  ),
  AppFunction(
    icon: "📝",
    title: "Notes",
    description: "Quick notes",
    route: "notes",
  ),
  AppFunction(
    icon: "🃏",
    title: "Cheatsheets",
    description: "Quick-reference cards",
    route: "cheatsheets",
  ),
  AppFunction(
    icon: "📇",
    title: "Contacts",
    description: "People and places",
    route: "contacts",
  ),
  AppFunction(
    icon: "📅",
    title: "Calendar",
    description: "Schedule events",
    route: "calendar",
  ),
  AppFunction(
    icon: "🚶",
    title: "Activity",
    description: "Log activity",
    route: "activity",
  ),
  AppFunction(
    icon: "🩸",
    title: "Glucose",
    description: "Blood sugar",
    route: "glucose",
  ),
];

/// The name shown under a tile (and on the Home screen settings page).
String homeTileTitle(AppFunction function, AppLocalizations l) =>
    switch (function.route) {
      'contacts' => l.contactsTitle,
      'calendar' => l.dashboardCalendarTitle,
      'activity' => l.dashboardActivityTitle,
      'glucose' => l.glucoseTitle,
      _ => function.title,
    };
