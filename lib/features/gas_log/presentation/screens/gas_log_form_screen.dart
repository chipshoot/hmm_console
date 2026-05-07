import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/button.dart';
import '../../../../core/widgets/gaps.dart';
import '../../../../core/widgets/numeric_input.dart';
import '../../../../core/widgets/screen_scaffold.dart';
import '../../../../core/widgets/text_field.dart';
import '../../domain/entities/automobile.dart';
import '../../domain/entities/gas_log.dart';
import '../../domain/entities/gas_station.dart';
import '../../domain/services/unit_converter.dart';
import '../../domain/validators/gas_log_validator.dart';
import '../../../settings/providers/gas_log_settings_provider.dart';
import '../../providers/selected_automobile_provider.dart';
import '../../states/automobiles_state.dart';
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
  bool _totalPriceManuallyEdited = false;
  bool _odometerManuallyEdited = false;
  bool _distanceManuallyEdited = false;
  bool _isUpdatingOdometer = false;
  bool _isUpdatingDistance = false;
  bool _isHistorical = false;
  String? _odometerGapWarning;

  bool get _isEditing => widget.gasLogId != null;

  Automobile? get _selectedAutomobile {
    final autoId = ref.read(selectedAutomobileIdProvider);
    final autos = ref.read(automobilesStateProvider).value;
    if (autoId == null || autos == null) return null;
    return autos.where((a) => a.id == autoId).firstOrNull;
  }

  @override
  void initState() {
    super.initState();
    _fuelCtrl.addListener(_autoCalculateTotalPrice);
    _unitPriceCtrl.addListener(_autoCalculateTotalPrice);
    _totalPriceCtrl.addListener(_onTotalPriceChanged);
    _odometerCtrl.addListener(_updateOdometerGapWarning);
    _distanceCtrl.addListener(_updateOdometerGapWarning);
    _odometerCtrl.addListener(_onOdometerChanged);
    _distanceCtrl.addListener(_onDistanceChanged);
    if (_isEditing) {
      _populateForm();
    } else {
      // Default is real-time; pre-fill odometer from selected automobile
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final auto = _selectedAutomobile;
        if (auto != null && !_isHistorical) {
          _setOdometerWithoutNotify(auto.meterReading.toString());
          _odometerManuallyEdited = true;
        }
      });
    }
  }

  void _autoCalculateTotalPrice() {
    if (_totalPriceManuallyEdited) return;

    final fuel = double.tryParse(_fuelCtrl.text);
    final unitPrice = double.tryParse(_unitPriceCtrl.text);

    if (fuel == null && unitPrice == null) {
      _setTotalPriceWithoutNotify('0.00');
      return;
    }

    if (fuel != null && unitPrice != null) {
      _setTotalPriceWithoutNotify((fuel * unitPrice).toStringAsFixed(2));
    }
  }

  void _onTotalPriceChanged() {
    // Only mark as manually edited if the change came from user interaction,
    // not from our programmatic update via _setTotalPriceWithoutNotify.
    if (!_isUpdatingTotalPrice) {
      _totalPriceManuallyEdited = true;
    }
  }

  bool _isUpdatingTotalPrice = false;

  void _setTotalPriceWithoutNotify(String value) {
    _isUpdatingTotalPrice = true;
    _totalPriceCtrl.text = value;
    _isUpdatingTotalPrice = false;
  }

  void _updateOdometerGapWarning() {
    if (_isHistorical || _isEditing) {
      if (_odometerGapWarning != null) {
        setState(() => _odometerGapWarning = null);
      }
      return;
    }
    final auto = _selectedAutomobile;
    if (auto == null) return;
    final warning = warnOdometerGap(
      _odometerCtrl.text,
      _distanceCtrl.text,
      auto.meterReading,
    );
    if (warning != _odometerGapWarning) {
      setState(() => _odometerGapWarning = warning);
    }
  }

  void _onOdometerChanged() {
    if (_isUpdatingOdometer) return;
    _odometerManuallyEdited = true;
    if (_distanceManuallyEdited) return;

    final auto = _selectedAutomobile;
    if (auto == null) return;
    final odometer = double.tryParse(_odometerCtrl.text);
    if (odometer == null) return;

    final distance = odometer - auto.meterReading;
    if (distance >= 0) {
      _setDistanceWithoutNotify(distance.toStringAsFixed(1));
    }
  }

  void _onDistanceChanged() {
    if (_isUpdatingDistance) return;
    _distanceManuallyEdited = true;
    if (_odometerManuallyEdited) return;

    final auto = _selectedAutomobile;
    if (auto == null) return;
    final distance = double.tryParse(_distanceCtrl.text);
    if (distance == null || distance < 0) return;

    final odometer = auto.meterReading + distance;
    _setOdometerWithoutNotify(odometer.toStringAsFixed(0));
  }

  void _setOdometerWithoutNotify(String value) {
    _isUpdatingOdometer = true;
    _odometerCtrl.text = value;
    _isUpdatingOdometer = false;
  }

  void _setDistanceWithoutNotify(String value) {
    _isUpdatingDistance = true;
    _distanceCtrl.text = value;
    _isUpdatingDistance = false;
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

    // Mark as manually edited before populating so auto-calc doesn't
    // overwrite the stored values during form pre-fill.
    _totalPriceManuallyEdited = true;
    _odometerManuallyEdited = true;
    _distanceManuallyEdited = true;

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
    _fuelCtrl.removeListener(_autoCalculateTotalPrice);
    _unitPriceCtrl.removeListener(_autoCalculateTotalPrice);
    _totalPriceCtrl.removeListener(_onTotalPriceChanged);
    _odometerCtrl.removeListener(_updateOdometerGapWarning);
    _distanceCtrl.removeListener(_updateOdometerGapWarning);
    _odometerCtrl.removeListener(_onOdometerChanged);
    _distanceCtrl.removeListener(_onDistanceChanged);
    _odometerCtrl.dispose();
    _distanceCtrl.dispose();
    _fuelCtrl.dispose();
    _totalPriceCtrl.dispose();
    _unitPriceCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Widget _buildHistoricalToggle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor =
        _isHistorical ? Colors.amber : Colors.green;
    final bgColor = isDark
        ? accentColor.withValues(alpha: 0.15)
        : (_isHistorical ? Colors.amber.shade50 : Colors.green.shade50);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.4)),
      ),
      child: SwitchListTile(
        secondary: Icon(
          _isHistorical ? Icons.history : Icons.update,
          color: accentColor.shade700,
        ),
        title: Text(
          _isHistorical ? 'Historical Entry' : 'Live Entry',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: accentColor.shade700,
          ),
        ),
        subtitle: Text(
          _isHistorical
              ? 'Backfilling a past fill-up (won\'t update odometer)'
              : 'Recording a current fill-up (updates odometer)',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        activeThumbColor: Colors.amber,
        inactiveThumbColor: Colors.green,
        value: _isHistorical,
        onChanged: (v) {
          setState(() {
            _isHistorical = v;
            _odometerManuallyEdited = false;
            _distanceManuallyEdited = false;
            if (!v) {
              final auto = _selectedAutomobile;
              if (auto != null) {
                _setOdometerWithoutNotify(auto.meterReading.toString());
                _odometerManuallyEdited = true;
              }
            } else {
              _setOdometerWithoutNotify('');
              _setDistanceWithoutNotify('');
              _odometerGapWarning = null;
            }
          });
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
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
      // Tap anywhere outside a field to dismiss the keyboard. Important
      // because the iOS number pad has no Done/Return key — without this
      // there's no obvious way to close it after typing odometer/fuel/etc.
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
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
              if (!_isEditing) ...[
                GapWidgets.h8,
                _buildHistoricalToggle(context),
              ],
              GapWidgets.h16,
              AppTextFormField(
                fieldController: _odometerCtrl,
                fieldValidator: (value) {
                  if (!_isHistorical && !_isEditing) {
                    final auto = _selectedAutomobile;
                    if (auto != null) {
                      return validateOdometerAgainstMeter(
                          value, auto.meterReading);
                    }
                  }
                  return validateOdometer(value);
                },
                label: 'Odometer ($distLabel)',
                keyboardType: NumericInput.decimal.keyboardType,
                inputFormatters: NumericInput.decimal.formatters,
              ),
              if (_odometerGapWarning != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 12),
                  child: Text(
                    _odometerGapWarning!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.amber.shade700,
                        ),
                  ),
                ),
              GapWidgets.h16,
              AppTextFormField(
                fieldController: _distanceCtrl,
                fieldValidator: validateDistance,
                label: 'Distance ($distLabel)',
                keyboardType: NumericInput.decimal.keyboardType,
                inputFormatters: NumericInput.decimal.formatters,
              ),
              GapWidgets.h16,
              AppTextFormField(
                fieldController: _fuelCtrl,
                fieldValidator: validateFuel,
                label: 'Fuel ($fuelLabel)',
                keyboardType: NumericInput.decimal.keyboardType,
                inputFormatters: NumericInput.decimal.formatters,
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
                      keyboardType: NumericInput.decimal.keyboardType,
                      inputFormatters: NumericInput.decimal.formatters,
                    ),
                  ),
                  GapWidgets.w16,
                  Expanded(
                    child: AppTextFormField(
                      fieldController: _totalPriceCtrl,
                      fieldValidator: validatePrice,
                      label: 'Total Price ($currSymbol)',
                      keyboardType: NumericInput.decimal.keyboardType,
                      inputFormatters: NumericInput.decimal.formatters,
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
      ref
          .read(createGasLogStateProvider.notifier)
          .create(autoId, gasLog, isHistorical: _isHistorical);
    }
  }
}
