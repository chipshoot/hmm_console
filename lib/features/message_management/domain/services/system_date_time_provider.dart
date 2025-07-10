import 'data_time_provider.dart';

class SystemDateTimeProvider implements DateTimeProvider {
  @override
  DateTime now() => DateTime.now();

  @override
  String getGreeting() {
    final hour = now().hour;

    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';

    return 'Good evening';
  }
}
