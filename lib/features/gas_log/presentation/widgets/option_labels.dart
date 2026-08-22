import '../../../../l10n/gen/app_localizations.dart';

/// Display copy for the dropdown option strings.
///
/// The four gas-log dropdowns (fuel type, fuel grade, engine type, ownership)
/// each hold a `static const List<String>` and render the option with
/// `DropdownMenuItem(value: t, child: Text(t))` — so the text on screen *is*
/// the value written into the gas log / automobile record and sent to the API.
///
/// That makes them the same hazard as the settings units, in a worse form:
/// there is no enum here, so there is no `apiValue` to hide behind. Translating
/// `Text(t)` directly would write "汽油" into saved records and onto the wire,
/// and every consumer comparing against 'Gasoline' would silently stop
/// matching. Records written on a Chinese device would differ from ones written
/// on an English device for the same real-world choice.
///
/// So the split is: the lists stay the literal wire values, and this maps a
/// value to what the user reads. Nothing here is ever persisted.
///
/// Converting these to real enums with an `apiValue` would be a better design,
/// but it changes model field types across mappers, states and repositories —
/// a large refactor with real corruption risk and no user-visible gain. The
/// lookup gets the same protection for a fraction of the blast radius.
///
/// [optionLabel] falls back to the raw value for anything unrecognised. A value
/// from a newer client, or one already stored before this existed, then renders
/// as-is rather than blank — untranslated, but never invisible.
String optionLabel(String value, AppLocalizations l) => switch (value) {
      // Fuel type / grade
      'Regular' => l.optionRegular,
      'MidGrade' => l.optionMidGrade,
      'Premium' => l.optionPremium,
      'Diesel' => l.optionDiesel,
      'E85' => l.optionE85,
      'Electric' => l.optionElectric,
      'Other' => l.optionOther,
      // Engine type
      'Gasoline' => l.optionGasoline,
      'Hybrid' => l.optionHybrid,
      'PlugInHybrid' => l.optionPlugInHybrid,
      'Hydrogen' => l.optionHydrogen,
      'CNG' => l.optionCng,
      // Ownership status
      'Owned' => l.optionOwned,
      'Financed' => l.optionFinanced,
      'Leased' => l.optionLeased,
      'Company' => l.optionCompany,
      _ => value,
    };
