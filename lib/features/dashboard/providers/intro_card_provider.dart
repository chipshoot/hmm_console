import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the first-run "Quick start" defaults card on the
/// dashboard has been acknowledged. Once seen, the card never reappears
/// — Settings is the place to revisit defaults afterwards.
class IntroCardSeenNotifier extends Notifier<bool> {
  static const _key = 'dashboard_intro_card_seen';

  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> markSeen() async {
    state = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}

final introCardSeenProvider = NotifierProvider<IntroCardSeenNotifier, bool>(
  () => IntroCardSeenNotifier(),
);
