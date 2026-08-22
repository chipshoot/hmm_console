import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/button.dart';
import '../../../../core/widgets/gaps.dart';
import '../../../../core/widgets/numeric_input.dart';
import '../../../../core/widgets/screen_scaffold.dart';
import '../../../../core/widgets/text_field.dart';
import '../../domain/entities/automobile.dart';
import '../../../settings/providers/gas_log_settings_provider.dart';
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

    final settings = ref.watch(gasLogSettingsProvider);
    final distLabel = settings.distanceUnit.label;
    final currSymbol = settings.currency.symbol;
    final l = AppLocalizations.of(context);

    ref.listen<AsyncValue<Automobile?>>(createAutomobileStateProvider,
        (_, next) {
      if (next.hasValue && next.value != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.vehicleCreated)),
        );
        context.pop();
      }
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.commonError('${next.error}')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    });

    return CommonScreenScaffold(
      title: l.vehicleNewTitle,
      // Tap outside any field to dismiss the keyboard. The iOS number pad
      // has no Done/Return key, so without this users have no obvious way
      // to close it after entering year/MPG/price.
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Identity ---
              _sectionTitle(context, l.sectionIdentity),
              GapWidgets.h8,
              AppTextFormField(
                fieldController: _vinCtrl,
                fieldValidator: (v) => validateVin(v, l),
                label: l.vehicleVin,
              ),
              GapWidgets.h16,
              AppTextFormField(
                fieldController: _makerCtrl,
                fieldValidator: (v) => validateMaker(v, l),
                label: l.vehicleMaker,
              ),
              GapWidgets.h16,
              AppTextFormField(
                fieldController: _brandCtrl,
                fieldValidator: (v) => validateBrand(v, l),
                label: l.vehicleBrand,
              ),
              GapWidgets.h16,
              AppTextFormField(
                fieldController: _modelCtrl,
                fieldValidator: (v) => validateModel(v, l),
                label: l.vehicleModel,
              ),
              GapWidgets.h16,
              Row(
                children: [
                  Expanded(
                    child: AppTextFormField(
                      fieldController: _trimCtrl,
                      fieldValidator: (_) => null,
                      label: l.vehicleTrim,
                    ),
                  ),
                  GapWidgets.w16,
                  Expanded(
                    child: AppTextFormField(
                      fieldController: _yearCtrl,
                      fieldValidator: (v) => validateYear(v, l),
                      label: l.vehicleYear,
                      keyboardType: NumericInput.integer.keyboardType,
                      inputFormatters: NumericInput.integer.formatters,
                    ),
                  ),
                ],
              ),
              GapWidgets.h24,

              // --- Appearance ---
              _sectionTitle(context, l.sectionAppearance),
              GapWidgets.h8,
              Row(
                children: [
                  Expanded(
                    child: AppTextFormField(
                      fieldController: _colorCtrl,
                      fieldValidator: (_) => null,
                      label: l.vehicleColorOptional,
                    ),
                  ),
                  GapWidgets.w16,
                  Expanded(
                    child: AppTextFormField(
                      fieldController: _plateCtrl,
                      fieldValidator: (v) => validatePlate(v, l),
                      label: l.vehiclePlate,
                    ),
                  ),
                ],
              ),
              GapWidgets.h24,

              // --- Engine ---
              _sectionTitle(context, l.sectionEngine),
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
                label: l.vehicleTankCapacity,
                keyboardType: NumericInput.decimal.keyboardType,
                inputFormatters: NumericInput.decimal.formatters,
              ),
              GapWidgets.h16,
              Row(
                children: [
                  Expanded(
                    child: AppTextFormField(
                      fieldController: _cityMpgCtrl,
                      fieldValidator: (_) => null,
                      label: l.vehicleCityMpg,
                      keyboardType: NumericInput.decimal.keyboardType,
                      inputFormatters: NumericInput.decimal.formatters,
                    ),
                  ),
                  GapWidgets.w16,
                  Expanded(
                    child: AppTextFormField(
                      fieldController: _highwayMpgCtrl,
                      fieldValidator: (_) => null,
                      label: l.vehicleHwyMpg,
                      keyboardType: NumericInput.decimal.keyboardType,
                      inputFormatters: NumericInput.decimal.formatters,
                    ),
                  ),
                  GapWidgets.w16,
                  Expanded(
                    child: AppTextFormField(
                      fieldController: _combinedMpgCtrl,
                      fieldValidator: (_) => null,
                      label: l.vehicleCombinedMpg,
                      keyboardType: NumericInput.decimal.keyboardType,
                      inputFormatters: NumericInput.decimal.formatters,
                    ),
                  ),
                ],
              ),
              GapWidgets.h24,

              // --- Ownership ---
              _sectionTitle(context, l.sectionOwnership),
              GapWidgets.h8,
              AppTextFormField(
                fieldController: _meterReadingCtrl,
                fieldValidator: (v) => validateMeterReading(v, l),
                label: l.vehicleMeterReading(distLabel),
                keyboardType: NumericInput.integer.keyboardType,
                inputFormatters: NumericInput.integer.formatters,
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
                label: l.vehiclePurchasePrice(currSymbol),
                keyboardType: NumericInput.decimal.keyboardType,
                inputFormatters: NumericInput.decimal.formatters,
              ),
              GapWidgets.h16,
              OwnershipStatusDropdown(
                value: _ownershipStatus,
                onChanged: (v) =>
                    setState(() => _ownershipStatus = v ?? 'Owned'),
              ),
              GapWidgets.h24,

              // --- Notes ---
              _sectionTitle(context, l.sectionNotes),
              GapWidgets.h8,
              AppTextFormField(
                fieldController: _notesCtrl,
                fieldValidator: (_) => null,
                label: l.vehicleNotesOptional,
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
