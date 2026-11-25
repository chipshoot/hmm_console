import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/navigation/auth_change_provider.dart';
import 'package:hmm_console/core/settings/settings_controller.dart';

/// Whether the router must send the user to the Hmm login.
///
/// Only the Hmm cloud mode (`cloudApi`) needs a Hmm sign-in; local and
/// cloud-storage data work without one. Until settings have loaded the mode
/// is unknown (dataModeProvider falls back to local), so this holds off
/// rather than guessing.
///
/// It is one bool on purpose: the router provider watches it, and a
/// Provider only notifies when its value changes. A sign-in or sign-out in
/// local / cloudStorage leaves it false, so the GoRouter is not rebuilt and
/// the navigation stack survives.
final loginRequiredProvider = Provider<bool>((ref) {
  final settingsLoaded = ref.watch(settingsProvider.select((s) => s.hasValue));
  if (!settingsLoaded) return false;
  if (ref.watch(dataModeProvider) != DataMode.cloudApi) return false;
  return ref.watch(routerAuthStateProvider).value != true;
});

/// Where the router sends the user when a login is required, or null.
String? authGateRedirect({
  required bool loginRequired,
  required bool isAuthPath,
}) {
  if (loginRequired && !isAuthPath) return '/auth';
  return null;
}
