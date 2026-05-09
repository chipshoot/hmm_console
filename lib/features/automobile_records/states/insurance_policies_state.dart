import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/repository_providers.dart';
import '../domain/entities/auto_insurance_policy.dart';
import '_records_automobile_id_provider.dart';

class InsurancePoliciesState extends AsyncNotifier<List<AutoInsurancePolicy>> {
  @override
  Future<List<AutoInsurancePolicy>> build() async {
    final autoId = ref.watch(recordsAutomobileIdProvider);
    if (autoId == null) return [];
    return ref.watch(insuranceRepositoryModeProvider).getPolicies(autoId);
  }

  Future<void> refresh() async {
    final autoId = ref.read(recordsAutomobileIdProvider);
    if (autoId == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(insuranceRepositoryModeProvider).getPolicies(autoId),
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
    return ref.watch(insuranceRepositoryModeProvider).getActivePolicy(autoId);
  }

  Future<void> refresh() async {
    final autoId = ref.read(recordsAutomobileIdProvider);
    if (autoId == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(insuranceRepositoryModeProvider).getActivePolicy(autoId),
    );
  }
}

final activeInsurancePolicyStateProvider =
    AsyncNotifierProvider<ActiveInsurancePolicyState, AutoInsurancePolicy?>(
  () => ActiveInsurancePolicyState(),
);
