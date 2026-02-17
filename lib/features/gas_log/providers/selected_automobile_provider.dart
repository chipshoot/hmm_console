import 'package:flutter_riverpod/flutter_riverpod.dart';

class SelectedAutomobileNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int? id) => state = id;
}

final selectedAutomobileIdProvider =
    NotifierProvider<SelectedAutomobileNotifier, int?>(
  () => SelectedAutomobileNotifier(),
);
