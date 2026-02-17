import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/button.dart';
import '../../../../core/widgets/gaps.dart';
import '../../../../core/widgets/screen_scaffold.dart';
import '../../../../core/widgets/text_field.dart';
import '../../domain/entities/automobile.dart';
import '../../domain/validators/automobile_validator.dart';
import '../../states/create_automobile_state.dart';
import '../widgets/date_picker_field.dart';
import '../widgets/engine_type_dropdown.dart';
import '../widgets/fuel_type_dropdown.dart';
import '../widgets/ownership_status_dropdown.dart';

class AutomobileCreateScreen extends ConsumerStatefulWidget {
  const AutomobileCreateScreen({super.key});

  @override
  ConsumerState<AutomobileCreateScreen> createState() =>
      _AutomobileCreateScreenState();
}

class _AutomobileCreateScreenState
    extends ConsumerState<AutomobileCreateScreen> with AutomobileValidator {
  final _formKey = GlobalKey<FormState>();

  // Identity
  final _vinCtrl = TextEditingController();
  final _makerCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _trimCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();

  // Appearance
  final _colorCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();

  // Engine
  String _engineType = 'Gasoline';
  String _fuelType = 'Regular';
  final _tankCapacityCtrl = TextEditingController();
  final _cityMpgCtrl = TextEditingController();
  final _highwayMpgCtrl = TextEditingController();
  final _combinedMpgCtrl = TextEditingController();

  // Ownership
  final _meterReadingCtrl = TextEditingController();
  final _purchasePriceCtrl = TextEditingController();
  DateTime? _purchaseDate;
  String _ownershipStatus = 'Owned';

  // Notes
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _vinCtrl.dispose();
    _makerCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _trimCtrl.dispose();
    _yearCtrl.dispose();
    _colorCtrl.dispose();
    _plateCtrl.dispose();
    _tankCapacityCtrl.dispose();
    _cityMpgCtrl.dispose();
    _highwayMpgCtrl.dispose();
    _combinedMpgCtrl.dispose();
    _meterReadingCtrl.dispose();
    _purchasePriceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final createState = ref.watch(createAutomobileStateProvider);
    final isLoading = createState.isLoading;

    ref.listen<AsyncValue<Automobile?>>(createAutomobileStateProvider,
        (_, next) {
      if (next.hasValue && next.value != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle created')),
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

    return CommonScreenScaffold(
      title: 'New Vehicle',
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Identity ---
              _sectionTitle(context, 'Identity'),
              GapWidgets.h8,
              AppTextFormField(
                fieldController: _vinCtrl,
                fieldValidator: validateVin,
                label: 'VIN (17 characters)',
              ),
              GapWidgets.h16,
              AppTextFormField(
                fieldController: _makerCtrl,
                fieldValidator: validateMaker,
                label: 'Maker',
              ),
              GapWidgets.h16,
              AppTextFormField(
                fieldController: _brandCtrl,
                fieldValidator: validateBrand,
                label: 'Brand',
              ),
              GapWidgets.h16,
              AppTextFormField(
                fieldController: _modelCtrl,
                fieldValidator: validateModel,
                label: 'Model',
              ),
              GapWidgets.h16,
              Row(
                children: [
                  Expanded(
                    child: AppTextFormField(
                      fieldController: _trimCtrl,
                      fieldValidator: (_) => null,
                      label: 'Trim (optional)',
                    ),
                  ),
                  GapWidgets.w16,
                  Expanded(
                    child: AppTextFormField(
                      fieldController: _yearCtrl,
                      fieldValidator: validateYear,
                      label: 'Year',
                    ),
                  ),
                ],
              ),
              GapWidgets.h24,

              // --- Appearance ---
              _sectionTitle(context, 'Appearance'),
              GapWidgets.h8,
              Row(
                children: [
                  Expanded(
                    child: AppTextFormField(
                      fieldController: _colorCtrl,
                      fieldValidator: (_) => null,
                      label: 'Color (optional)',
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
              GapWidgets.h24,

              // --- Engine ---
              _sectionTitle(context, 'Engine'),
              GapWidgets.h8,
              EngineTypeDropdown(
                value: _engineType,
                onChanged: (v) =>
                    setState(() => _engineType = v ?? 'Gasoline'),
              ),
              GapWidgets.h16,
              FuelTypeDropdown(
                value: _fuelType,
                onChanged: (v) =>
                    setState(() => _fuelType = v ?? 'Regular'),
              ),
              GapWidgets.h16,
              AppTextFormField(
                fieldController: _tankCapacityCtrl,
                fieldValidator: (_) => null,
                label: 'Tank Capacity (optional)',
              ),
              GapWidgets.h16,
              Row(
                children: [
                  Expanded(
                    child: AppTextFormField(
                      fieldController: _cityMpgCtrl,
                      fieldValidator: (_) => null,
                      label: 'City MPG',
                    ),
                  ),
                  GapWidgets.w16,
                  Expanded(
                    child: AppTextFormField(
                      fieldController: _highwayMpgCtrl,
                      fieldValidator: (_) => null,
                      label: 'Hwy MPG',
                    ),
                  ),
                  GapWidgets.w16,
                  Expanded(
                    child: AppTextFormField(
                      fieldController: _combinedMpgCtrl,
                      fieldValidator: (_) => null,
                      label: 'Combined',
                    ),
                  ),
                ],
              ),
              GapWidgets.h24,

              // --- Ownership ---
              _sectionTitle(context, 'Ownership'),
              GapWidgets.h8,
              AppTextFormField(
                fieldController: _meterReadingCtrl,
                fieldValidator: validateMeterReading,
                label: 'Meter Reading (optional)',
              ),
              GapWidgets.h16,
              DatePickerField(
                selectedDate: _purchaseDate ?? DateTime.now(),
                onDateChanged: (d) => setState(() => _purchaseDate = d),
              ),
              GapWidgets.h16,
              AppTextFormField(
                fieldController: _purchasePriceCtrl,
                fieldValidator: (_) => null,
                label: 'Purchase Price (optional)',
              ),
              GapWidgets.h16,
              OwnershipStatusDropdown(
                value: _ownershipStatus,
                onChanged: (v) =>
                    setState(() => _ownershipStatus = v ?? 'Owned'),
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
                text: isLoading ? 'Creating...' : 'Create Vehicle',
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final automobile = Automobile(
      id: 0,
      vin: _vinCtrl.text,
      maker: _makerCtrl.text,
      brand: _brandCtrl.text,
      model: _modelCtrl.text,
      trim: _trimCtrl.text.isNotEmpty ? _trimCtrl.text : null,
      year: int.tryParse(_yearCtrl.text) ?? 0,
      color: _colorCtrl.text.isNotEmpty ? _colorCtrl.text : null,
      plate: _plateCtrl.text,
      engineType: _engineType,
      fuelType: _fuelType,
      fuelTankCapacity: double.tryParse(_tankCapacityCtrl.text) ?? 0,
      cityMPG: double.tryParse(_cityMpgCtrl.text) ?? 0,
      highwayMPG: double.tryParse(_highwayMpgCtrl.text) ?? 0,
      combinedMPG: double.tryParse(_combinedMpgCtrl.text) ?? 0,
      meterReading: int.tryParse(_meterReadingCtrl.text) ?? 0,
      purchaseDate: _purchaseDate,
      purchasePrice: double.tryParse(_purchasePriceCtrl.text),
      ownershipStatus: _ownershipStatus,
      isActive: true,
      notes: _notesCtrl.text.isNotEmpty ? _notesCtrl.text : null,
    );

    ref.read(createAutomobileStateProvider.notifier).create(automobile);
  }
}
