import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/button.dart';
import '../../../../core/widgets/gaps.dart';
import '../../../../core/widgets/screen_scaffold.dart';
import '../../../../core/widgets/text_field.dart';
import '../../domain/entities/gas_log.dart';
import '../../domain/validators/gas_log_validator.dart';
import '../../providers/selected_automobile_provider.dart';
import '../../states/create_gas_log_state.dart';
import '../../states/gas_logs_state.dart';
import '../../states/update_gas_log_state.dart';
import '../widgets/date_picker_field.dart';
import '../widgets/fuel_grade_dropdown.dart';

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
  final _stationCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _fuelGrade = 'Regular';
  bool _isFullTank = true;

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

    _odometerCtrl.text = gasLog.odometer.toStringAsFixed(0);
    _distanceCtrl.text = gasLog.distance.toStringAsFixed(1);
    _fuelCtrl.text = gasLog.fuel.toStringAsFixed(1);
    _totalPriceCtrl.text = gasLog.totalPrice.toStringAsFixed(2);
    _unitPriceCtrl.text = gasLog.unitPrice.toStringAsFixed(2);
    _stationCtrl.text = gasLog.stationName ?? '';
    _commentCtrl.text = gasLog.comment ?? '';
    _selectedDate = gasLog.date;
    _fuelGrade = gasLog.fuelGrade;
    _isFullTank = gasLog.isFullTank;
  }

  @override
  void dispose() {
    _odometerCtrl.dispose();
    _distanceCtrl.dispose();
    _fuelCtrl.dispose();
    _totalPriceCtrl.dispose();
    _unitPriceCtrl.dispose();
    _stationCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final createState = ref.watch(createGasLogStateProvider);
    final updateState = ref.watch(updateGasLogStateProvider);
    final isLoading = createState.isLoading || updateState.isLoading;

    ref.listen<AsyncValue<GasLog?>>(createGasLogStateProvider, (_, next) {
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
                label: 'Odometer',
              ),
              GapWidgets.h16,
              AppTextFormField(
                fieldController: _distanceCtrl,
                fieldValidator: validateDistance,
                label: 'Distance',
              ),
              GapWidgets.h16,
              AppTextFormField(
                fieldController: _fuelCtrl,
                fieldValidator: validateFuel,
                label: 'Fuel (gallons)',
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
                      label: 'Unit Price',
                    ),
                  ),
                  GapWidgets.w16,
                  Expanded(
                    child: AppTextFormField(
                      fieldController: _totalPriceCtrl,
                      fieldValidator: validatePrice,
                      label: 'Total Price',
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
              AppTextFormField(
                fieldController: _stationCtrl,
                fieldValidator: (_) => null,
                label: 'Station Name (optional)',
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

    final autoId = ref.read(selectedAutomobileIdProvider);
    if (autoId == null) return;

    final gasLog = GasLog(
      id: widget.gasLogId,
      date: _selectedDate,
      automobileId: autoId,
      odometer: double.parse(_odometerCtrl.text),
      distance: double.tryParse(_distanceCtrl.text) ?? 0,
      fuel: double.parse(_fuelCtrl.text),
      fuelGrade: _fuelGrade,
      isFullTank: _isFullTank,
      totalPrice: double.parse(_totalPriceCtrl.text),
      unitPrice: double.parse(_unitPriceCtrl.text),
      stationName: _stationCtrl.text.isNotEmpty ? _stationCtrl.text : null,
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
