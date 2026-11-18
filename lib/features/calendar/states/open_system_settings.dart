import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens this app's page in the system Settings, or null when the platform
/// cannot (so the UI hides the action).
///
/// iOS launches `app-settings:` (UIApplication.openSettingsURLString).
/// Android has no such URL scheme and `url_launcher` cannot open the app's
/// notification settings, so the action is hidden there (Android is the
/// secondary platform; the banner text still explains what to do).
final openSystemSettingsProvider = Provider<Future<bool> Function()?>((ref) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
  return () => launchUrl(Uri.parse('app-settings:'));
});
