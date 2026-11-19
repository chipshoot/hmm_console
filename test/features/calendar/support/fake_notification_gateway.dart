import 'package:hmm_console/features/calendar/notifications/notification_gateway.dart';
import 'package:hmm_console/features/calendar/notifications/reminder_plan.dart';

/// In-memory [NotificationGateway]: pending entries keyed by id.
class FakeNotificationGateway implements NotificationGateway {
  FakeNotificationGateway({this.granted = true});

  bool granted;
  final Map<int, PendingReminder> pendingById = {};
  final List<PlannedReminder> scheduled = [];
  final List<int> cancelled = [];
  void Function(String payload)? onTap;
  int badgeClears = 0;

  /// Every [setBadge] count, in order.
  final List<int> badgeSets = [];

  void addPending(int id, String? payload) =>
      pendingById[id] = PendingReminder(id: id, payload: payload);

  @override
  Future<void> initialize(void Function(String payload) onTap) async =>
      this.onTap = onTap;

  @override
  Future<List<PendingReminder>> pending() async => pendingById.values.toList();

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    pendingById.remove(id);
  }

  @override
  Future<void> schedule(PlannedReminder r) async {
    scheduled.add(r);
    pendingById[r.id] = PendingReminder(id: r.id, payload: r.payload);
  }

  @override
  Future<bool> requestPermission() async => granted;

  @override
  Future<bool> permissionGranted() async => granted;

  @override
  Future<void> setBadge(int count) async => badgeSets.add(count);

  @override
  Future<void> clearBadge() async => badgeClears++;
}
