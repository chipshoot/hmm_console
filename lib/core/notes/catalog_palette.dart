import 'package:flutter/material.dart';

/// Catalog name for free-form user notes.
const String kGeneralCatalogName = 'General';

class CatalogStyle {
  const CatalogStyle(this.displayName, this.color);
  final String displayName;
  final Color color;
}

class CatalogPalette {
  const CatalogPalette._();

  static const Color _default = Color(0xFF8E8E93);

  static const Map<String, CatalogStyle> _known = {
    kGeneralCatalogName: CatalogStyle('General', Color(0xFF34C759)),
    'Hmm.AutomobileMan.GasLog': CatalogStyle('Gas Log', Color(0xFFFFD60A)),
    'Hmm.AutomobileMan.AutomobileInfo':
        CatalogStyle('Automobile', Color(0xFF0A84FF)),
    'Hmm.AutomobileMan.AutoInsurancePolicy':
        CatalogStyle('Insurance', Color(0xFFFF9F0A)),
    'Hmm.AutomobileMan.AutoScheduledService':
        CatalogStyle('Scheduled Service', Color(0xFFBF5AF2)),
    'Hmm.AutomobileMan.ServiceRecord':
        CatalogStyle('Service Record', Color(0xFFFF453A)),
  };

  static CatalogStyle styleFor(String? catalogName) {
    if (catalogName == null) return const CatalogStyle('Note', _default);
    final known = _known[catalogName];
    if (known != null) return known;
    final seg = catalogName.split('.').last;
    return CatalogStyle(seg.isEmpty ? catalogName : seg, _default);
  }

  // ---- Domain grouping --------------------------------------------------
  // Catalog names are namespaced as `<prefix>.<DomainMan>.<Entity>`
  // (e.g. `Hmm.AutomobileMan.GasLog`). The middle segment is the domain, so
  // every automobile-related catalog groups under one "Automobile" domain.
  // Names without that shape (e.g. `General`) are their own domain.

  static const Map<String, Color> _domainColors = {
    'AutomobileMan': Color(0xFF0A84FF), // Automobile
    kGeneralCatalogName: Color(0xFF34C759), // General
  };

  /// Domain key for a catalog name. `Hmm.AutomobileMan.GasLog` -> `AutomobileMan`;
  /// `General` -> `General`; null -> `Other`.
  static String domainKeyFor(String? catalogName) {
    if (catalogName == null || catalogName.isEmpty) return 'Other';
    final parts = catalogName.split('.');
    return parts.length >= 3 ? parts[parts.length - 2] : catalogName;
  }

  /// Friendly label + color for a domain key. Strips a trailing "Man"
  /// (`AutomobileMan` -> `Automobile`).
  static CatalogStyle domainStyle(String domainKey) {
    final name = domainKey.endsWith('Man') && domainKey.length > 3
        ? domainKey.substring(0, domainKey.length - 3)
        : domainKey;
    return CatalogStyle(name, _domainColors[domainKey] ?? _default);
  }
}
