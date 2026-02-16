import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/button.dart';
import '../../../../core/widgets/gaps.dart';
import '../../../../core/widgets/screen_scaffold.dart';
import '../../../../core/widgets/text_field.dart';
import '../../domain/entities/automobile.dart';
import '../../domain/validators/automobile_validator.dart';
import '../../states/automobiles_state.dart';
import '../../states/update_automobile_state.dart';
import '../widgets/ownership_status_dropdown.dart';

class AutomobileEditScreen extends ConsumerStatefulWidget {
  final int automobileId;

  const AutomobileEditScreen({super.key, required this.automobileId});

  @override
  ConsumerState<AutomobileEditScreen> createState() =>
      _AutomobileEditScreenState();
}

class _AutomobileEditScreenState extends ConsumerState<AutomobileEditScreen>
    with AutomobileValidator {
  final _formKey = GlobalKey<FormState>();

  // Mutable fields
  final _colorCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _meterReadingCtrl = TextEditingController();
  String _ownershipStatus = 'Owned';

  // Insurance
  final _insuranceProviderCtrl = TextEditingController();
  final _insurancePolicyCtrl = TextEditingController();
  DateTime? _insuranceExpiryDate;
  DateTime? _registrationExpiryDate;

  // Service
  DateTime? _lastServiceDate;
  final _lastServiceMeterCtrl = TextEditingController();
  DateTime? _nextServiceDueDate;
  final _nextServiceDueMeterCtrl = TextEditingController();

  // Notes
  final _notesCtrl = TextEditingController();

  Automobile? _original;

  @override
  void initState() {
    super.initState();
    _populateForm();
  }

  void _populateForm() {
    final data = ref.read(automobilesStateProvider).value;
    if (data == null) return;

    final auto =
        data.where((a) => a.id == widget.automobileId).firstOrNull;
    if (auto == null) return;

    _original = auto;
    _colorCtrl.text = auto.color ?? '';
    _plateCtrl.text = auto.plate ?? '';
    _meterReadingCtrl.text = auto.meterReading.toString();
    _ownershipStatus = auto.ownershipStatus ?? 'Owned';
    _insuranceProviderCtrl.text = auto.insuranceProvider ?? '';
    _insurancePolicyCtrl.text = auto.insurancePolicyNumber ?? '';
    _insuranceExpiryDate = auto.insuranceExpiryDate;
    _registrationExpiryDate = auto.registrationExpiryDate;
    _lastServiceDate = auto.lastServiceDate;
    _lastServiceMeterCtrl.text =
        auto.lastServiceMeterReading?.toString() ?? '';
    _nextServiceDueDate = auto.nextServiceDueDate;
    _nextServiceDueMeterCtrl.text =
        auto.nextServiceDueMeterReading?.toString() ?? '';
    _notesCtrl.text = auto.notes ?? '';
  }

  @override
  void dispose() {
    _colorCtrl.dispose();
    _plateCtrl.dispose();
    _meterReadingCtrl.dispose();
    _insuranceProviderCtrl.dispose();
    _insurancePolicyCtrl.dispose();
    _lastServiceMeterCtrl.dispose();
    _nextServiceDueMeterCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final updateState = ref.watch(updateAutomobileStateProvider);
    final isLoading = updateState.isLoading;

    ref.listen<AsyncValue<void>>(updateAutomobileStateProvider, (_, next) {
      if (next.hasValue && !next.isLoading && !next.isRefreshing) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle updated')),
        );
        context.pop();
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

    if (_original == null) {
      return CommonScreenScaffold(
        title: 'Edit Vehicle',
        child: const Center(child: Text('Vehicle not found')),
      );
    }

    final orig = _original!;

    return CommonScreenScaffold(
      title: 'Edit Vehicle',
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Read-only immutable fields ---
              _sectionTitle(context, 'Vehicle Info (read-only)'),
              GapWidgets.h8,
              _readOnlyField('VIN', orig.vin ?? 'N/A'),
              _readOnlyField('Maker', orig.maker ?? 'N/A'),
              _readOnlyField('Brand', orig.brand ?? 'N/A'),
              _readOnlyField('Model', orig.model ?? 'N/A'),
              _readOnlyField('Year', orig.year > 0 ? '${orig.year}' : 'N/A'),
              _readOnlyField('Engine', orig.engineType ?? 'N/A'),
              _readOnlyField('Fuel', orig.fuelType ?? 'N/A'),
              GapWidgets.h24,

              // --- Mutable fields ---
              _sectionTitle(context, 'Editable Details'),
              GapWidgets.h8,
              Row(
                children: [
                  Expanded(
                    child: AppTextFormField(
                      fieldController: _colorCtrl,
                      fieldValidator: (_) => null,
                      label: 'Color',
                    ),
                  ),
                  GapWidgets.w16,
                  Expanded(
                    child: AppTextFormField(
                      fieldController: _plateCtrl,
                      fieldValidator: validatePlate,
                      label: 'Plate',
                    ),
                  ),
                ],
              ),
              GapWidgets.h16,
              AppTextFormField(
                fieldController: _meterReadingCtrl,
                fieldValidator: validateMeterReading,
                label: 'Meter Reading',
              ),
              GapWidgets.h16,
              OwnershipStatusDropdown(
                value: _ownershipStatus,
                onChanged: (v) =>
                    setState(() => _ownershipStatus = v ?? 'Owned'),
              ),
              GapWidgets.h24,

              // --- Insurance & Registration ---
              _sectionTitle(context, 'Insurance & Registration'),
              GapWidgets.h8,
              AppTextFormField(
                fieldController: _insuranceProviderCtrl,
                fieldValidator: (_) => null,
                label: 'Insurance Provider (optional)',
              ),
              GapWidgets.h16,
              AppTextFormField(
                fieldController: _insurancePolicyCtrl,
                fieldValidator: (_) => null,
                label: 'Policy Number (optional)',
              ),
              GapWidgets.h16,
              _optionalDatePicker(
                context,
                label: 'Insurance Expiry',
                date: _insuranceExpiryDate,
                onChanged: (d) =>
                    setState(() => _insuranceExpiryDate = d),
              ),
              GapWidgets.h16,
              _optionalDatePicker(
                context,
                label: 'Registration Expiry',
                date: _registrationExpiryDate,
                onChanged: (d) =>
                    setState(() => _registrationExpiryDate = d),
              ),
              GapWidgets.h24,

              // --- Service ---
              _sectionTitle(context, 'Service'),
              GapWidgets.h8,
              _optionalDatePicker(
                context,
                label: 'Last Service Date',
                date: _lastServiceDate,
                onChanged: (d) => setState(() => _lastServiceDate = d),
              ),
              GapWidgets.h16,
              AppTextFormField(
                fieldController: _lastServiceMeterCtrl,
                fieldValidator: validateMeterReading,
                label: 'Last Service Meter (optional)',
              ),
              GapWidgets.h16,
              _optionalDatePicker(
                context,
                label: 'Next Service Due',
                date: _nextServiceDueDate,
                onChanged: (d) =>
                    setState(() => _nextServiceDueDate = d),
              ),
              GapWidgets.h16,
              AppTextFormField(
                fieldController: _nextServiceDueMeterCtrl,
                fieldValidator: validateMeterReading,
                label: 'Next Service Meter (optional)',
              ),
              GapWidgets.h24,

              // --- Notes ---
              _sectionTitle(context, 'Notes'),
              GapWidgets.h8,
              AppTextFormField(
                fieldController: _notesCtrl,
                fieldValidator: (_) => null,
                label: 'Notes (optional)',
              ),
              GapWidgets.h24,

              HighlightButton(
                text: isLoading ? 'Saving...' : 'Save Changes',
                onPressed: isLoading ? () {} : _submit,
              ),
              GapWidgets.h24,
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _readOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  Widget _optionalDatePicker(
    BuildContext context, {
    required String label,
    required DateTime? date,
    required ValueChanged<DateTime?> onChanged,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (date != null)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onChanged(null),
                ),
              const Icon(Icons.calendar_today),
              const SizedBox(width: 12),
            ],
          ),
        ),
        child: Text(
          date != null
              ? '${date.month}/${date.day}/${date.year}'
              : 'Not set',
          style: TextStyle(
            color: date != null
                ? null
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final orig = _original!;
    final updated = Automobile(
      id: orig.id,
      vin: orig.vin,
      maker: orig.maker,
      brand: orig.brand,
      model: orig.model,
      trim: orig.trim,
      year: orig.year,
      color: _colorCtrl.text.isNotEmpty ? _colorCtrl.text : null,
      plate: _plateCtrl.text.isNotEmpty ? _plateCtrl.text : null,
      engineType: orig.engineType,
      fuelType: orig.fuelType,
      fuelTankCapacity: orig.fuelTankCapacity,
      cityMPG: orig.cityMPG,
      highwayMPG: orig.highwayMPG,
      combinedMPG: orig.combinedMPG,
      meterReading: int.tryParse(_meterReadingCtrl.text) ?? orig.meterReading,
      purchaseMeterReading: orig.purchaseMeterReading,
      purchaseDate: orig.purchaseDate,
      purchasePrice: orig.purchasePrice,
      ownershipStatus: _ownershipStatus,
      isActive: orig.isActive,
      soldDate: orig.soldDate,
      soldMeterReading: orig.soldMeterReading,
      soldPrice: orig.soldPrice,
      registrationExpiryDate: _registrationExpiryDate,
      insuranceExpiryDate: _insuranceExpiryDate,
      insuranceProvider: _insuranceProviderCtrl.text.isNotEmpty
          ? _insuranceProviderCtrl.text
          : null,
      insurancePolicyNumber: _insurancePolicyCtrl.text.isNotEmpty
          ? _insurancePolicyCtrl.text
          : null,
      lastServiceDate: _lastServiceDate,
      lastServiceMeterReading:
          int.tryParse(_lastServiceMeterCtrl.text),
      nextServiceDueDate: _nextServiceDueDate,
      nextServiceDueMeterReading:
          int.tryParse(_nextServiceDueMeterCtrl.text),
      notes: _notesCtrl.text.isNotEmpty ? _notesCtrl.text : null,
    );

    ref
        .read(updateAutomobileStateProvider.notifier)
        .updateAutomobile(widget.automobileId, updated);
  }
}
