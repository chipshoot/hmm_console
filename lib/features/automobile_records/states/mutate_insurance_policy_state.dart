import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/repository_providers.dart';
import '../domain/entities/auto_insurance_policy.dart';
import 'insurance_policies_state.dart';

/// Tracks the in-flight create / edit / delete operation for insurance
/// policies. Screens listen to this to drive snackbars / loading
/// indicators. After every successful mutation we invalidate the list
/// state for the affected automobile so it refetches.
class MutateInsurancePolicyState extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<AutoInsurancePolicy?> create(
      int autoId, AutoInsurancePolicy policy) async {
    state = const AsyncValue.loading();
    AutoInsurancePolicy? created;
    state = await AsyncValue.guard(() async {
      created = await ref
          .read(insuranceRepositoryModeProvider)
          .createPolicy(autoId, policy);
    });
    if (state.hasValue) _invalidate();
    return created;
  }

  Future<void> edit(int autoId, int id, AutoInsurancePolicy policy) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref
        .read(insuranceRepositoryModeProvider)
        .updatePolicy(autoId, id, policy));
    if (state.hasValue) _invalidate();
  }

  Future<void> delete(int autoId, int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
        () => ref.read(insuranceRepositoryModeProvider).deletePolicy(autoId, id));
    if (state.hasValue) _invalidate();
  }

  void _invalidate() {
    ref.invalidate(insurancePoliciesStateProvider);
    ref.invalidate(activeInsurancePolicyStateProvider);
  }
}

final mutateInsurancePolicyStateProvider =
    AsyncNotifierProvider<MutateInsurancePolicyState, void>(
  () => MutateInsurancePolicyState(),
);
