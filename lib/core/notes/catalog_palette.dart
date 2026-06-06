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
}
