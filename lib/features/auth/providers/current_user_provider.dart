import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/features/auth/data/models/current_user.dart';

class CurrentUserNotifier extends Notifier<CurrentUserDataModel?> {
  @override
  CurrentUserDataModel? build() => null;

  void setUser(CurrentUserDataModel? user) {
    state = user;
  }
}

final currentUserProvider =
    NotifierProvider<CurrentUserNotifier, CurrentUserDataModel?>(
  CurrentUserNotifier.new,
);
