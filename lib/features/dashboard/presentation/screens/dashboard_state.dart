import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/features/auth/usecases/signout_usecase.dart';

final signOutStateProvider = Provider<Future<void>>((ref) {
  return ref.watch(signOutUseCaseProvider).signOut();
});
