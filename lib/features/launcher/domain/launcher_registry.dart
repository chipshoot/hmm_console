import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';
import 'launcher_destination.dart';

/// Single source of truth for launcher destinations. Seeded from the
/// existing GoRouter named routes.
///
/// ## Three kinds of string, three different rules
///
/// * **`id`** (`'gasLog'`) — the persisted key. Favorites are stored as a list
///   of these and aliases map *alias → id*, so an id must never change and is
///   never shown to anyone. Same for `routeName`.
/// * **`title`** — display only, so it is translated.
/// * **`synonyms`** — neither. They are *input vocabulary*: the matcher builds
///   its haystack from `[title, ...synonyms]` and tests what the user typed
///   against it.
///
/// That last one is why the Chinese terms below are **added to** the English
/// ones rather than replacing them. Swapping the list per locale would mean a
/// bilingual user running a Chinese UI could no longer find "Gas Log" by typing
/// `gas` — and search vocabulary has no reason to be exclusive. Both languages
/// match in either locale.
///
/// The English title is repeated inside `synonyms` for the same reason: once
/// `title` is localized it is the *Chinese* word that lands in the haystack, so
/// without this the English name would stop matching in a Chinese UI.
List<LauncherDestination> launcherDestinations(AppLocalizations l) => [
      LauncherDestination(
        id: 'vehicles',
        title: l.launcherDestVehicles,
        synonyms: const [
          'Vehicles',
          'car', 'vehicle', 'auto', 'automobile', 'garage', 'manage cars',
          '车辆', '汽车', '车库', '我的车',
        ],
        icon: Icons.directions_car,
        routeName: 'automobileManagement',
      ),
      LauncherDestination(
        id: 'gasLog',
        title: l.launcherDestGasLog,
        synonyms: const [
          'Gas Log',
          'gas', 'fuel', 'fill-up', 'petrol', 'mileage', 'fuel log',
          '加油', '加油记录', '油耗', '燃油',
        ],
        icon: Icons.local_gas_station,
        routeName: 'gasLogList',
        needsVehicle: true,
        usesVehiclePathId: false, // scopes via selectedAutomobileIdProvider
      ),
      LauncherDestination(
        id: 'serviceRecords',
        title: l.launcherDestServiceLog,
        synonyms: const [
          'Service Log',
          'service', 'maintenance', 'repair', 'car service', 'service record',
          '保养', '维修', '维修记录', '保养记录',
        ],
        icon: Icons.build,
        routeName: 'serviceRecords',
        needsVehicle: true,
        usesVehiclePathId: true,
      ),
      LauncherDestination(
        id: 'scheduledServices',
        title: l.launcherDestScheduledServices,
        synonyms: const [
          'Scheduled Services',
          'scheduled', 'reminder', 'upcoming service', 'maintenance schedule',
          '保养计划', '提醒', '计划',
        ],
        icon: Icons.event,
        routeName: 'scheduledServices',
        needsVehicle: true,
        usesVehiclePathId: true,
      ),
      LauncherDestination(
        id: 'insurance',
        title: l.launcherDestInsurance,
        synonyms: const [
          'Insurance',
          'insurance', 'policy', 'coverage',
          '保险', '保单',
        ],
        icon: Icons.shield,
        routeName: 'insurancePolicies',
        needsVehicle: true,
        usesVehiclePathId: true,
      ),
      LauncherDestination(
        id: 'vehicleNotes',
        title: l.launcherDestVehicleNotes,
        synonyms: const [
          'Vehicle Notes',
          'vehicle notes', 'car notes',
          '车辆备注', '车辆笔记',
        ],
        icon: Icons.note_alt,
        routeName: 'vehicleNotes',
        needsVehicle: true,
        usesVehiclePathId: true,
      ),
      LauncherDestination(
        id: 'notes',
        title: l.launcherDestNotes,
        synonyms: const [
          'Notes',
          'note', 'notes', 'journal', 'memo',
          '笔记', '备注', '日志',
        ],
        icon: Icons.description,
        routeName: 'notesList',
      ),
      LauncherDestination(
        id: 'gasStations',
        title: l.launcherDestGasStations,
        synonyms: const [
          'Gas Stations',
          'station', 'gas station', 'fuel station', 'discount',
          '加油站', '油站', '折扣',
        ],
        icon: Icons.ev_station,
        routeName: 'gasStationManagement',
      ),
      LauncherDestination(
        id: 'cheatsheets',
        title: l.launcherDestCheatsheets,
        synonyms: const [
          'Cheatsheets',
          'cheatsheet',
          'cheat sheet',
          'card',
          'cards',
          'wallet',
          'quick reference',
          'reference',
          '速查卡', '卡片', '卡包', '速查',
        ],
        icon: Icons.style_outlined,
        routeName: 'cheatsheets',
      ),
      LauncherDestination(
        // Literal id and routeName: favorites persist by id, so a
        // locale-dependent one would orphan every favorite the moment the UI
        // language changed. Only the title is localized, and the English
        // terms stay in synonyms so a bilingual user on a Chinese UI can
        // still type "licence".
        id: 'driverLicence',
        title: l.launcherDestLicence,
        synonyms: const [
          'Licence',
          'licence',
          'license',
          "driver's licence",
          'drivers license',
          'driving licence',
          'dl',
          'id',
          '驾驶证', '驾照', '驾驶执照',
        ],
        icon: Icons.badge_outlined,
        routeName: 'driverLicence',
      ),
      LauncherDestination(
        id: 'settings',
        title: l.launcherDestSettings,
        synonyms: const [
          'Settings',
          'settings', 'preferences', 'config', 'options',
          '设置', '偏好', '配置',
        ],
        icon: Icons.settings,
        routeName: 'settings',
      ),
    ];

/// id -> destination lookup for resolving favorites/recents/aliases.
///
/// Keyed by the stable ids, so a favorite saved in one language resolves in the
/// other; only the resulting `title` differs.
Map<String, LauncherDestination> launcherDestinationsById(
  AppLocalizations l,
) =>
    {for (final d in launcherDestinations(l)) d.id: d};
