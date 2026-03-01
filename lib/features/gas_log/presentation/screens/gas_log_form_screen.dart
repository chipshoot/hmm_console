import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/button.dart';
import '../../../../core/widgets/gaps.dart';
import '../../../../core/widgets/screen_scaffold.dart';
import '../../../../core/widgets/text_field.dart';
import '../../domain/entities/gas_log.dart';
import '../../domain/entities/gas_station.dart';
import '../../domain/services/unit_converter.dart';
import '../../domain/validators/gas_log_validator.dart';
import '../../../settings/providers/gas_log_settings_provider.dart';
import '../../providers/selected_automobile_provider.dart';
import '../../states/create_gas_log_state.dart';
import '../../states/gas_logs_state.dart';
import '../../states/update_gas_log_state.dart';
import '../widgets/date_picker_field.dart';
import '../widgets/fuel_grade_dropdown.dart';
import '../widgets/station_dropdown.dart';

class GasLogFormScreen extends ConsumerStatefulWidget {
  final int? gasLogId;

  const GasLogFormScreen({super.key, this.gasLogId});

  @override
  ConsumerState<GasLogFormScreen> createState() => _GasLogFormScreenState();
}

class _GasLogFormScreenState extends ConsumerState<GasLogFormScreen>
    with GasLogValidator {
  final _formKey = GlobalKey<FormState>();
  final _odometerCtrl = TextEditingController();
  final _distanceCtrl = TextEditingController();
  final _fuelCtrl = TextEditingController();
  final _totalPriceCtrl = TextEditingController();
  final _unitPriceCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _fuelGrade = 'Regular';
  bool _isFullTank = true;
  GasStation? _selectedStation;
  String? _initialStationName;

  bool get _isEditing => widget.gasLogId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _populateForm();
    }
  }

  void _populateForm() {
    final data = ref.read(gasLogsStateProvider).value;
    if (data == null) return;

    final gasLog = data.items
        .where((g) => g.id == widget.gasLogId)
        .firstOrNull;
    if (gasLog == null) return;

    final s = ref.read(gasLogSettingsProvider);
    final targetDist = s.distanceUnit.apiValue;
    final targetFuel = s.fuelUnit.apiValue;

    final odometer = UnitConverter.convertDistance(
        gasLog.odometer, gasLog.odometerUnit, targetDist);
    final distance = UnitConverter.convertDistance(
        gasLog.distance, gasLog.distanceUnit, targetDist);
    final fuel = UnitConverter.convertVolume(
        gasLog.fuel, gasLog.fuelUnit, targetFuel);

    _odometerCtrl.text = odometer.toStringAsFixed(0);
    _distanceCtrl.text = distance.toStringAsFixed(1);
    _fuelCtrl.text = fuel.toStringAsFixed(1);
    _totalPriceCtrl.text = gasLog.totalPrice.toStringAsFixed(2);
    _unitPriceCtrl.text = gasLog.unitPrice.toStringAsFixed(2);
    _commentCtrl.text = gasLog.comment ?? '';
    _selectedDate = gasLog.date;
    _fuelGrade = gasLog.fuelGrade;
    _isFullTank = gasLog.isFullTank;
    _initialStationName = gasLog.stationName;
    if (gasLog.stationName != null) {
      _selectedStation = GasStation(
        id: gasLog.stationId,
        name: gasLog.stationName!,
      );
    }
  }

  @override
  void dispose() {
    _odometerCtrl.dispose();
    _distanceCtrl.dispose();
    _fuelCtrl.dispose();
    _totalPriceCtrl.dispose();
    _unitPriceCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final createState = ref.watch(createGasLogStateProvider);
    final updateState = ref.watch(updateGasLogStateProvider);
    final isLoading = createState.isLoading || updateState.isLoading;

    ref.listen<AsyncValue<GasLog?>>(createGasLogStateProvider, (_, next) {
      if (!mounted) return;
      if (next.hasValue && next.value != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gas log created')),
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

    ref.listen<AsyncValue<GasLog?>>(updateGasLogStateProvider, (_, next) {
      if (!mounted) return;
      if (next.hasValue && next.value != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gas log updated')),
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

    final settings = ref.watch(gasLogSettingsProvider);
    final distLabel = settings.distanceUnit.label;
    final fuelLabel = settings.fuelUnit.label;
    final currSymbol = settings.currency.symbol;

    return CommonScreenScaffold(
      title: _isEditing ? 'Edit Gas Log' : 'New Gas Log',
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DatePickerField(
                selectedDate: _selectedDate,
                onDateChanged: (d) => setState(() => _selectedDate = d),
              ),
              GapWidgets.h16,
              AppTextFormField(
                fieldController: _odometerCtrl,
                fieldValidator: validateOdometer,
                label: 'Odometer ($distLabel)',
              ),
              GapWidgets.h16,
              AppTextFormField(
                fieldController: _distanceCtrl,
                fieldValidator: validateDistance,
                label: 'Distance ($distLabel)',
              ),
              GapWidgets.h16,
              AppTextFormField(
                fieldController: _fuelCtrl,
                fieldValidator: validateFuel,
                label: 'Fuel ($fuelLabel)',
              ),
              GapWidgets.h16,
              FuelGradeDropdown(
                value: _fuelGrade,
                onChanged: (v) =>
                    setState(() => _fuelGrade = v ?? 'Regular'),
              ),
              GapWidgets.h16,
              Row(
                children: [
                  Expanded(
                    child: AppTextFormField(
                      fieldController: _unitPriceCtrl,
                      fieldValidator: validatePrice,
                      label: 'Unit Price ($currSymbol/$fuelLabel)',
                    ),
                  ),
                  GapWidgets.w16,
                  Expanded(
                    child: AppTextFormField(
                      fieldController: _totalPriceCtrl,
                      fieldValidator: validatePrice,
                      label: 'Total Price ($currSymbol)',
                    ),
                  ),
                ],
              ),
              GapWidgets.h16,
              SwitchListTile(
                title: const Text('Full Tank'),
                value: _isFullTank,
                onChanged: (v) => setState(() => _isFullTank = v),
                contentPadding: EdgeInsets.zero,
              ),
              GapWidgets.h8,
              StationDropdown(
                initialValue: _initialStationName,
                onStationChanged: (station) {
                  _selectedStation = station;
                },
              ),
              GapWidgets.h16,
              AppTextFormField(
                fieldController: _commentCtrl,
                fieldValidator: (_) => null,
                label: 'Comment (optional)',
              ),
              GapWidgets.h24,
              HighlightButton(
                text: isLoading
                    ? 'Saving...'
                    : (_isEditing ? 'Update' : 'Create'),
                onPressed: isLoading ? () {} : _submit,
              ),
              GapWidgets.h24,
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedStation == null &&
        (_initialStationName == null || _initialStationName!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select or enter a gas station'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final autoId = ref.read(selectedAutomobileIdProvider);
    if (autoId == null) return;

    final s = ref.read(gasLogSettingsProvider);
    final gasLog = GasLog(
      id: widget.gasLogId,
      date: _selectedDate,
      automobileId: autoId,
      odometer: double.parse(_odometerCtrl.text),
      odometerUnit: s.distanceUnit.apiValue,
      distance: double.tryParse(_distanceCtrl.text) ?? 0,
      distanceUnit: s.distanceUnit.apiValue,
      fuel: double.parse(_fuelCtrl.text),
      fuelUnit: s.fuelUnit.apiValue,
      fuelGrade: _fuelGrade,
      isFullTank: _isFullTank,
      totalPrice: double.parse(_totalPriceCtrl.text),
      unitPrice: double.parse(_unitPriceCtrl.text),
      currency: s.currency.apiValue,
      stationId: _selectedStation?.id,
      stationName: _selectedStation?.name,
      comment: _commentCtrl.text.isNotEmpty ? _commentCtrl.text : null,
    );

    if (_isEditing) {
      ref
          .read(updateGasLogStateProvider.notifier)
          .updateGasLog(autoId, widget.gasLogId!, gasLog);
    } else {
      ref.read(createGasLogStateProvider.notifier).create(autoId, gasLog);
    }
  }
}
