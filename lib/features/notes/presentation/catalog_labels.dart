import '../../../core/notes/catalog_palette.dart';
import '../../../l10n/gen/app_localizations.dart';

/// Localized display labels for note catalogs and domains.
///
/// [CatalogPalette] maps a *persisted* catalog name — `'General'`,
/// `'Hmm.AutomobileMan.GasLog'` — to a colour and an English label. The names
/// are storage; the labels are not. Unlike the settings units or the gas-log
/// dropdowns, nothing here is ever written back, so these are safe to
/// translate outright. The palette itself is left untouched: it still owns the
/// colours and the name→style mapping, and its English labels remain the
/// fallback.
///
/// [catalogLabel] falls back to `CatalogPalette.styleFor(name).displayName`,
/// which for an unknown catalog is its last dotted segment. A catalog added by
/// a newer client therefore shows something readable rather than blank —
/// untranslated, but never empty.
String catalogLabel(String? catalogName, AppLocalizations l) =>
    switch (catalogName) {
      kGeneralCatalogName => l.catalogGeneral,
      'Hmm.AutomobileMan.GasLog' => l.catalogGasLog,
      'Hmm.AutomobileMan.AutomobileInfo' => l.catalogAutomobile,
      'Hmm.AutomobileMan.AutoInsurancePolicy' => l.catalogInsurance,
      'Hmm.AutomobileMan.AutoScheduledService' => l.catalogScheduledService,
      'Hmm.AutomobileMan.ServiceRecord' => l.catalogServiceRecord,
      null => l.catalogNote,
      _ => CatalogPalette.styleFor(catalogName).displayName,
    };

/// Localized label for a domain key (see `CatalogPalette.domainKeyFor`).
String domainLabel(String domainKey, AppLocalizations l) => switch (domainKey) {
      'AutomobileMan' => l.domainAutomobile,
      kGeneralCatalogName => l.domainGeneral,
      'Other' => l.domainOther,
      _ => CatalogPalette.domainStyle(domainKey).displayName,
    };

/// Display label for a subsystem anchor note.
///
/// The anchor's stored `subject` is an English literal set at creation
/// (`ensureSubsystemAnchor(..., displayName: 'Automobile')`) and must stay that
/// way — it is persisted and synced, and the anchor is looked up by a
/// deterministic uuid rather than by subject. This maps the anchor to what the
/// user should read instead of rendering the stored subject directly.
///
/// Unknown anchors fall back to their stored subject, so a subsystem added
/// later still shows up.
String subsystemLabel(String subject, AppLocalizations l) => switch (subject) {
      'Automobile' => l.notesSubsystemAutomobile,
      _ => subject,
    };
