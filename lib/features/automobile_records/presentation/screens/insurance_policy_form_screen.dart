import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/dio_error_message.dart';
import '../../../../core/widgets/button.dart';
import '../../../../core/widgets/screen_scaffold.dart';
import '../../../../core/widgets/text_field.dart';
import '../../../../core/data/repository_providers.dart';
import '../../../../core/contact_block/contact_info.dart';
import '../../../../core/contact_block/widgets/contact_info_editor.dart';
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

  /// Embedded contact blocks, edited in place. The form owns the list; each
  /// editor reports changes rather than holding its own copy.
  List<ContactInfo> _contacts = [];
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
          .read(insuranceRepositoryModeProvider)
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
      _contacts = List.of(policy.contacts);
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
    final l = AppLocalizations.of(context);
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
            content: Text(dioErrorMessage(next.error!)),
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
                      label: l.recordsProvider,
                    ),
                    const SizedBox(height: 16),
                    AppTextFormField(
                      fieldController: _policyNumberCtrl,
                      fieldValidator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                      label: l.recordsPolicyNumberLabel,
                    ),
                    const SizedBox(height: 16),
                    OptionalDatePicker(
                      label: l.recordsEffectiveDate,
                      date: _effective,
                      onChanged: (d) => setState(() => _effective = d),
                    ),
                    const SizedBox(height: 16),
                    OptionalDatePicker(
                      label: l.recordsExpiryDate,
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
                            label: l.recordsPremium,
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
                            label: l.recordsCurrencyShort,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AppTextFormField(
                      fieldController: _deductibleCtrl,
                      fieldValidator: (v) =>
                          (v == null || v.isEmpty) ? null : _validateAmount(v),
                      label: l.recordsDeductible,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [_decimalFormatter],
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: Text(l.recordsActive),
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                    const SizedBox(height: 16),
                    AppTextFormField(
                      fieldController: _notesCtrl,
                      fieldValidator: (_) => null,
                      label: l.recordsNotes,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l.contactBlockTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        TextButton.icon(
                          key: const Key('addContactButton'),
                          icon: const Icon(Icons.add),
                          label: Text(l.contactBlockAdd),
                          onPressed: () => setState(
                            () => _contacts = [
                              ..._contacts,
                              const ContactInfo(role: ContactRoles.agent),
                            ],
                          ),
                        ),
                      ],
                    ),
                    for (var i = 0; i < _contacts.length; i++)
                      Padding(
                        // Keyed by index so removing one does not carry the
                        // next block's controllers into the removed slot.
                        key: ValueKey('contactBlock_$i'),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ContactInfoEditor(
                          value: _contacts[i],
                          onChanged: (c) {
                            final next = List.of(_contacts);
                            next[i] = c;
                            _contacts = next;
                          },
                          onRemove: () => setState(() {
                            final next = List.of(_contacts);
                            next.removeAt(i);
                            _contacts = next;
                          }),
                        ),
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
    final l = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (_effective == null || _expiry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(l.recordsDatesRequired)),
      );
      return;
    }
    if (!_effective!.isBefore(_expiry!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(l.recordsDateOrderInvalid)),
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
      contacts: _contacts,
    );

    final notifier = ref.read(mutateInsurancePolicyStateProvider.notifier);
    if (widget.isEdit) {
      await notifier.edit(widget.automobileId, _existing!.id, policy);
    } else {
      await notifier.create(widget.automobileId, policy);
    }
  }
}
