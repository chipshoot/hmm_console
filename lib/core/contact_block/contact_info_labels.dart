import '../../l10n/gen/app_localizations.dart';

/// Display copy for a stored contact role.
///
/// The split is load-bearing. `ContactInfo.role` is PERSISTED in the owning
/// note's JSON and syncs across devices, so localizing it at the source would
/// write display text into stored data: the same record would read differently
/// per device language, and a value saved on a Chinese device would not match
/// anything on an English one. See `lib/core/i18n/enum_labels.dart`, where
/// exactly this mistake was found and fixed.
///
/// Unknown roles fall back to the raw stored value, so a role written by a
/// newer client - or typed by the user - reads as itself rather than vanishing.
String contactRoleLabel(String role, AppLocalizations l) => switch (role) {
      'agent' => l.contactRoleAgent,
      'doctor' => l.contactRoleDoctor,
      'hospital' => l.contactRoleHospital,
      'pharmacy' => l.contactRolePharmacy,
      'emergency' => l.contactRoleEmergency,
      'friend' => l.contactRoleFriend,
      'family' => l.contactRoleFamily,
      'other' => l.contactRoleOther,
      _ => role,
    };
