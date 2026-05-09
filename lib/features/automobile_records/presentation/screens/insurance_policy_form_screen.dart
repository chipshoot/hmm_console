import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/button.dart';
import '../../../../core/widgets/screen_scaffold.dart';
import '../../../../core/widgets/text_field.dart';
import '../../data/repositories/insurance_repository.dart';
import '../../domain/entities/auto_insurance_policy.dart';
import '../../states/_records_automobile_id_provider.dart';
import '../../states/mutate_insurance_policy_state.dart';
import '../widgets/optional_date_picker.dart';

class InsurancePolicyFormScreen extends ConsumerStatefulWidget {
  const InsurancePolicyFormScreen({
    super.key,
    required this.automobileId,
    this.policyId,
  });

  final int automobileId;
  final int? policyId;

  bool get isEdit => policyId != null;

  @override
  ConsumerState<InsurancePolicyFormScreen> createState() =>
      _InsurancePolicyFormScreenState();
}

class _InsurancePolicyFormScreenState
    extends ConsumerState<InsurancePolicyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _providerCtrl = TextEditingController();
  final _policyNumberCtrl = TextEditingController();
  final _premiumCtrl = TextEditingController();
  final _deductibleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _currency = 'CAD';
  DateTime? _effective;
  DateTime? _expiry;
  bool _isActive = true;

  bool _loading = false;
  AutoInsurancePolicy? _existing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(recordsAutomobileIdProvider.notifier)
          .set(widget.automobileId);
      if (widget.isEdit) _loadExisting();
    });
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    try {
      final policy = await ref
          .read(insuranceRepositoryProvider)
          .getPolicyById(widget.automobileId, widget.policyId!);
      _existing = policy;
      _providerCtrl.text = policy.provider;
      _policyNumberCtrl.text = policy.policyNumber;
      _premiumCtrl.text = policy.premium.toStringAsFixed(2);
      _deductibleCtrl.text = policy.deductible?.toStringAsFixed(2) ?? '';
      _notesCtrl.text = policy.notes ?? '';
      _currency = policy.currency;
      _effective = policy.effectiveDate;
      _expiry = policy.expiryDate;
      _isActive = policy.isActive;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _providerCtrl.dispose();
    _policyNumberCtrl.dispose();
    _premiumCtrl.dispose();
    _deductibleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mutationState = ref.watch(mutateInsurancePolicyStateProvider);
    final saving = mutationState.isLoading;

    ref.listen<AsyncValue<void>>(mutateInsurancePolicyStateProvider, (_, next) {
      if (next.hasValue && !next.isLoading && !next.isRefreshing) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEdit ? 'Policy updated' : 'Policy added'),
          ),
        );
        if (mounted) context.pop();
      }
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${next.error}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    });

    return CommonScreenScaffold(
      title: widget.isEdit ? 'Edit Insurance Policy' : 'Add Insurance Policy',
      child: _loading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextFormField(
                      fieldController: _providerCtrl,
                      fieldValidator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                      label: 'Provider',
                    ),
                    const SizedBox(height: 16),
                    AppTextFormField(
                      fieldController: _policyNumberCtrl,
                      fieldValidator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                      label: 'Policy number',
                    ),
                    const SizedBox(height: 16),
                    OptionalDatePicker(
                      label: 'Effective date',
                      date: _effective,
                      onChanged: (d) => setState(() => _effective = d),
                    ),
                    const SizedBox(height: 16),
                    OptionalDatePicker(
                      label: 'Expiry date',
                      date: _expiry,
                      onChanged: (d) => setState(() => _expiry = d),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: AppTextFormField(
                            fieldController: _premiumCtrl,
                            fieldValidator: _validateAmount,
                            label: 'Premium',
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            inputFormatters: [_decimalFormatter],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: AppTextFormField(
                            fieldController:
                                TextEditingController(text: _currency),
                            fieldValidator: (_) => null,
                            label: 'CCY',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AppTextFormField(
                      fieldController: _deductibleCtrl,
                      fieldValidator: (v) =>
                          (v == null || v.isEmpty) ? null : _validateAmount(v),
                      label: 'Deductible (optional)',
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [_decimalFormatter],
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Active'),
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                    const SizedBox(height: 16),
                    AppTextFormField(
                      fieldController: _notesCtrl,
                      fieldValidator: (_) => null,
                      label: 'Notes',
                    ),
                    const SizedBox(height: 24),
                    HighlightButton(
                      text: saving
                          ? 'Saving...'
                          : (widget.isEdit ? 'Save Changes' : 'Add Policy'),
                      onPressed: saving ? () {} : _submit,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  String? _validateAmount(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final n = double.tryParse(v);
    if (n == null) return 'Invalid number';
    if (n < 0) return 'Cannot be negative';
    return null;
  }

  static final _decimalFormatter =
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_effective == null || _expiry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Effective and expiry dates are required')),
      );
      return;
    }
    if (!_effective!.isBefore(_expiry!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Effective date must be before expiry date')),
      );
      return;
    }

    final policy = AutoInsurancePolicy(
      id: _existing?.id ?? 0,
      automobileId: widget.automobileId,
      provider: _providerCtrl.text.trim(),
      policyNumber: _policyNumberCtrl.text.trim(),
      effectiveDate: _effective!,
      expiryDate: _expiry!,
      premium: double.parse(_premiumCtrl.text),
      currency: _currency,
      deductible: _deductibleCtrl.text.trim().isEmpty
          ? null
          : double.parse(_deductibleCtrl.text),
      coverage: _existing?.coverage ?? const [],
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      isActive: _isActive,
    );

    final notifier = ref.read(mutateInsurancePolicyStateProvider.notifier);
    if (widget.isEdit) {
      await notifier.edit(widget.automobileId, _existing!.id, policy);
    } else {
      await notifier.create(widget.automobileId, policy);
    }
  }
}
