import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_button.dart';
import '../../../../core/help/help_registry.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/glucose_range.dart';
import '../../domain/glucose_units.dart';
import '../../states/glucose_settings_providers.dart';
import '../widgets/glucose_unit_toggle.dart';

/// Target range (low and high, read in the display unit), the display unit,
/// and on iOS the per-device Apple Health import switch.
class GlucoseRangeScreen extends ConsumerStatefulWidget {
  const GlucoseRangeScreen({super.key});

  @override
  ConsumerState<GlucoseRangeScreen> createState() => _GlucoseRangeScreenState();
}

enum _RangeProblem { value, order }

class _GlucoseRangeScreenState extends ConsumerState<GlucoseRangeScreen> {
  final _low = TextEditingController();
  final _high = TextEditingController();
  bool _seeded = false;
  bool _saving = false;

  /// The unit low and high are read in. Null until a stored range or a
  /// tap sets it; then it follows the display unit.
  GlucoseUnit? _rangeUnit;
  ProviderSubscription<GlucoseRange?>? _rangeSub;

  @override
  void initState() {
    super.initState();
    // The range hydrates from prefs after the first build.
    _rangeSub = ref.listenManual<GlucoseRange?>(
      glucoseRangeProvider,
      (_, range) => _seed(range),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _rangeSub?.close();
    _low.dispose();
    _high.dispose();
    super.dispose();
  }

  bool get _isApple => Theme.of(context).platform == TargetPlatform.iOS;

  /// Fills the fields once from a stored range, exactly as stored and in
  /// its own unit. Typing first wins over a late hydration.
  void _seed(GlucoseRange? range) {
    if (_seeded || range == null) return;
    if (_low.text.isNotEmpty || _high.text.isNotEmpty) return;
    _seeded = true;
    _rangeUnit = range.unit;
    _low.text = _plain(range.low);
    _high.text = _plain(range.high);
    if (mounted) setState(() {});
  }

  String _plain(num v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';

  num? _parse(String t) => num.tryParse(t.trim().replaceAll(',', '.'));

  /// Null when the fields hold a savable range (or are not yet complete).
  _RangeProblem? _problem(GlucoseUnit unit) {
    final low = _parse(_low.text);
    final high = _parse(_high.text);
    if (low == null || high == null) return null;
    if (!isValidTypedValue(GlucoseValue(low, unit)) ||
        !isValidTypedValue(GlucoseValue(high, unit))) {
      return _RangeProblem.value;
    }
    return low >= high ? _RangeProblem.order : null;
  }

  bool _canSave(GlucoseUnit unit) =>
      _parse(_low.text) != null &&
      _parse(_high.text) != null &&
      _problem(unit) == null;

  Future<void> _save(GlucoseUnit unit) async {
    if (_saving || !_canSave(unit)) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(glucoseRangeProvider.notifier);
    final range = GlucoseRange(
      low: _parse(_low.text)!,
      high: _parse(_high.text)!,
      unit: unit,
    );
    setState(() => _saving = true);
    try {
      await notifier.set(range);
      if (!mounted) return;
      await Navigator.of(context).maybePop();
    } catch (e) {
      debugPrint('glucoseRange: save failed (${e.runtimeType})');
      messenger.showSnackBar(SnackBar(content: Text(l.glucoseRangeSaveFailed)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clear() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(glucoseRangeProvider.notifier);
    try {
      await notifier.clear();
      if (!mounted) return;
      _low.clear();
      _high.clear();
      setState(() {});
    } catch (e) {
      debugPrint('glucoseRange: clear failed (${e.runtimeType})');
      messenger.showSnackBar(SnackBar(content: Text(l.glucoseRangeSaveFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final displayUnit = ref.watch(glucoseDisplayUnitProvider);
    final unit = _rangeUnit ?? displayUnit;
    final range = ref.watch(glucoseRangeProvider);
    final problem = _problem(unit);
    final bounds = glucoseTypedBounds(unit);
    final errorText = switch (problem) {
      _RangeProblem.value => l.glucoseValueOutOfRange(
        '${bounds.min}',
        '${bounds.max}',
        unit.wire,
      ),
      _RangeProblem.order => l.glucoseRangeOrderError,
      null => null,
    };

    Widget field(String key, TextEditingController c, String label) => Expanded(
      child: TextField(
        key: Key(key),
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        decoration: InputDecoration(
          labelText: label,
          suffixText: unit.wire,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l.helpGlucoseRangeTitle),
        actions: [
          TextButton(
            key: const Key('glucose-range-save'),
            onPressed: _canSave(unit) && !_saving ? () => _save(unit) : null,
            child: Text(l.glucoseRangeSave),
          ),
          const HelpButton(helpId: HelpId.glucoseRange),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _label(Icons.track_changes, l.helpGlucoseRangeTitle),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  field('glucose-range-low', _low, l.glucoseRangeLow),
                  const SizedBox(width: 12),
                  field('glucose-range-high', _high, l.glucoseRangeHigh),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: glucoseUnitToggle(
                key: const Key('glucose-range-unit'),
                apple: _isApple,
                unit: unit,
                onChanged: (u) => setState(() => _rangeUnit = u),
              ),
            ),
            if (errorText != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  errorText,
                  key: const Key('glucose-range-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (range != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: TextButton(
                    key: const Key('glucose-range-clear'),
                    onPressed: _clear,
                    child: Text(l.glucoseRangeClear),
                  ),
                ),
              ),
            const Divider(),
            _label(Icons.straighten, l.glucoseDisplayUnitLabel),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: glucoseUnitToggle(
                apple: _isApple,
                unit: displayUnit,
                onChanged: (u) =>
                    ref.read(glucoseDisplayUnitProvider.notifier).set(u),
              ),
            ),
            if (_isApple) ...[
              const Divider(),
              SwitchListTile.adaptive(
                key: const Key('glucose-import-on-device'),
                secondary: const Icon(Icons.favorite_border),
                title: Text(l.glucoseImportOnDeviceLabel),
                value: ref.watch(glucoseImportOnDeviceProvider),
                onChanged: (v) =>
                    ref.read(glucoseImportOnDeviceProvider.notifier).set(v),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _label(IconData icon, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text(text, style: Theme.of(context).textTheme.titleSmall),
      ],
    ),
  );
}
