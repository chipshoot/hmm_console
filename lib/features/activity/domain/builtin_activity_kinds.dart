import 'package:flutter/material.dart';

import 'activity.dart';
import 'activity_kind.dart';

final List<ActivityKind> builtinActivityKinds = [
  ActivityKind(
    id: 'health.walk',
    icon: Icons.directions_walk,
    label: (l) => l.activityKindWalk,
    defaultIntensity: ActivityIntensity.moderate,
    offersDistance: true,
  ),
  ActivityKind(
    id: 'health.run',
    icon: Icons.directions_run,
    label: (l) => l.activityKindRun,
    defaultIntensity: ActivityIntensity.vigorous,
    offersDistance: true,
  ),
  ActivityKind(
    id: 'health.cycling',
    icon: Icons.directions_bike,
    label: (l) => l.activityKindCycling,
    defaultIntensity: ActivityIntensity.moderate,
    offersDistance: true,
  ),
  ActivityKind(
    id: 'health.swim',
    icon: Icons.pool,
    label: (l) => l.activityKindSwim,
    defaultIntensity: ActivityIntensity.moderate,
    offersDistance: true,
  ),
  ActivityKind(
    id: 'health.gym',
    icon: Icons.fitness_center,
    label: (l) => l.activityKindGym,
    defaultIntensity: ActivityIntensity.moderate,
  ),
  ActivityKind(
    id: 'health.yoga',
    icon: Icons.self_improvement,
    label: (l) => l.activityKindYoga,
    defaultIntensity: ActivityIntensity.moderate,
  ),
  ActivityKind(
    id: 'health.other',
    icon: Icons.more_horiz,
    label: (l) => l.activityKindOther,
  ),
  ActivityKind(
    id: 'reading.reading',
    icon: Icons.menu_book,
    label: (l) => l.activityKindReading,
  ),
  ActivityKind(
    id: 'development.coding',
    icon: Icons.code,
    label: (l) => l.activityKindCoding,
  ),
];
