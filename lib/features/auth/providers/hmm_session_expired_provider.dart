import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/core/network/idp_token_service.dart';
import 'package:hmm_console/core/network/token_storage.dart';

/// The email of a Hmm session the IdP ended ('' when unknown), or null when
/// none has. Re-read whenever the session changes: it is set when a refresh
/// token is refused, and cleared by signing in, signing out or dismissing
/// the notice.
final hmmSessionExpiredProvider = StreamProvider<String?>((ref) async* {
  final idp = ref.watch(idpTokenServiceProvider);
  final storage = ref.watch(tokenStorageProvider);
  yield await storage.getExpiredSession();
  await for (final _ in idp.sessionChanges) {
    yield await storage.getExpiredSession();
  }
});
