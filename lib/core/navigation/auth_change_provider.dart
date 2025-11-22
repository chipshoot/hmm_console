import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/features/auth/usecases/auth_state_change_usecase.dart';

final routerAuthStateProvider = StreamProvider(
  (ref) => ref.watch(authStateUseCaseProvider).isUserAuthenticated(),
);
