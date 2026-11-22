import 'package:flutter/widgets.dart';

import '../../../l10n/gen/app_localizations.dart';
import 'activity.dart';

/// One kind of activity. Ids are `<area>.<name>`.
class ActivityKind {
  const ActivityKind({
    required this.id,
    required this.icon,
    required this.label,
    this.defaultIntensity,
    this.offersDistance = false,
  });

  final String id;
  final IconData icon;
  final String Function(AppLocalizations) label;
  final ActivityIntensity? defaultIntensity;
  final bool offersDistance;

  /// The part of [id] before the first dot.
  String get area {
    final dot = id.indexOf('.');
    return dot < 0 ? id : id.substring(0, dot);
  }
}

class ActivityKindRegistry {
  const ActivityKindRegistry(List<ActivityKind> kinds) : _kinds = kinds;

  final List<ActivityKind> _kinds;

  List<ActivityKind> get all => List.unmodifiable(_kinds);

  ActivityKind? byId(String id) {
    for (final k in _kinds) {
      if (k.id == id) return k;
    }
    return null;
  }

  /// Areas in first-seen order.
  List<String> get areas {
    final seen = <String>[];
    for (final k in _kinds) {
      if (!seen.contains(k.area)) seen.add(k.area);
    }
    return seen;
  }

  List<ActivityKind> inArea(String area) =>
      _kinds.where((k) => k.area == area).toList();
}

String activityAreaLabel(String area, AppLocalizations l) => switch (area) {
  'health' => l.activityAreaHealth,
  'reading' => l.activityAreaReading,
  'development' => l.activityAreaDevelopment,
  _ => area,
};
