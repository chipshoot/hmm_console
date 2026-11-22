import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/activity_kind.dart';
import '../domain/builtin_activity_kinds.dart';

/// The single registration point: future subsystems append their kinds here.
final activityKindRegistryProvider = Provider<ActivityKindRegistry>(
  (ref) => ActivityKindRegistry([...builtinActivityKinds]),
);
