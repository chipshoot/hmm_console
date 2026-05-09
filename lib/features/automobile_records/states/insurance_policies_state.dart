import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/insurance_repository.dart';
import '../domain/entities/auto_insurance_policy.dart';
import '_records_automobile_id_provider.dart';

class InsurancePoliciesState extends AsyncNotifier<List<AutoInsurancePolicy>> {
  @override
  Future<List<AutoInsurancePolicy>> build() async {
    final autoId = ref.watch(recordsAutomobileIdProvider);
    if (autoId == null) return [];
    return ref.watch(insuranceRepositoryProvider).getPolicies(autoId);
  }

  Future<void> refresh() async {
    final autoId = ref.read(recordsAutomobileIdProvider);
    if (autoId == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(insuranceRepositoryProvider).getPolicies(autoId),
    );
  }
}

final insurancePoliciesStateProvider =
    AsyncNotifierProvider<InsurancePoliciesState, List<AutoInsurancePolicy>>(
  () => InsurancePoliciesState(),
);

class ActiveInsurancePolicyState extends AsyncNotifier<AutoInsurancePolicy?> {
  @override
  Future<AutoInsurancePolicy?> build() async {
    final autoId = ref.watch(recordsAutomobileIdProvider);
    if (autoId == null) return null;
    return ref.watch(insuranceRepositoryProvider).getActivePolicy(autoId);
  }

  Future<void> refresh() async {
    final autoId = ref.read(recordsAutomobileIdProvider);
    if (autoId == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(insuranceRepositoryProvider).getActivePolicy(autoId),
    );
  }
}

final activeInsurancePolicyStateProvider =
    AsyncNotifierProvider<ActiveInsurancePolicyState, AutoInsurancePolicy?>(
  () => ActiveInsurancePolicyState(),
);
