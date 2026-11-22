import 'dart:async';

import 'package:hmm_console/features/activity/contract/i_activity_repository.dart';
import 'package:hmm_console/features/activity/domain/activity.dart';

/// In-memory repository for screen tests. `changes()` is broadcast and
/// never emits on subscribe.
class FakeActivityRepository implements IActivityRepository {
  FakeActivityRepository([Iterable<Activity> seed = const []]) {
    for (final a in seed) {
      _items[a.id] = a;
    }
  }

  final Map<String, Activity> _items = {};
  final _changes = StreamController<void>.broadcast();

  @override
  Future<List<Activity>> activitiesBetween(
    DateTime from,
    DateTime to, {
    Set<String>? areas,
  }) async {
    final f = from.toUtc();
    final t = to.toUtc();
    return [
      for (final a in _items.values)
        if (!a.start.utc.isBefore(f) &&
            a.start.utc.isBefore(t) &&
            (areas == null || areas.contains(a.area)))
          a,
    ]..sort((x, y) => y.start.utc.compareTo(x.start.utc));
  }

  @override
  Future<Activity?> getActivity(String id) async => _items[id];

  @override
  Future<Activity> saveActivity(Activity a) async {
    final now = DateTime.now().toUtc();
    final saved = a.copyWith(
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        now.millisecondsSinceEpoch ~/ 1000 * 1000,
        isUtc: true,
      ),
    );
    _items[saved.id] = saved;
    _changes.add(null);
    return saved;
  }

  @override
  Future<void> deleteActivity(String id) async {
    if (_items.remove(id) != null) _changes.add(null);
  }

  @override
  Stream<void> changes() => _changes.stream;
}
