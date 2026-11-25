import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/data_mode.dart';
import '../../../../core/i18n/enum_labels.dart';
import '../../../../l10n/gen/app_localizations.dart';
import 'hmm_account_section.dart';

/// The Data storage mode picker. A switch to Hmm cloud goes through the
/// sign-in guard; when it is cancelled the field is rebuilt so it shows the
/// old mode again (initialValue only applies on a field's first build).
class DataModeDropdown extends ConsumerStatefulWidget {
  const DataModeDropdown({super.key});

  @override
  ConsumerState<DataModeDropdown> createState() => _DataModeDropdownState();
}

class _DataModeDropdownState extends ConsumerState<DataModeDropdown> {
  int _redraws = 0;

  Future<void> _onChanged(DataMode? v, DataMode current) async {
    if (v == null || v == current) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final switched = await switchDataMode(context, ref, v);
    if (!mounted) return;
    if (!switched) {
      setState(() => _redraws++);
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text(l.settingsSwitchedToMode(v.displayName(l)))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final dataMode = ref.watch(dataModeProvider);
    return DropdownButtonFormField<DataMode>(
      key: ValueKey((dataMode, _redraws)),
      initialValue: dataMode,
      decoration: InputDecoration(
        labelText: l.settingsStorageMode,
        border: const OutlineInputBorder(),
      ),
      items: DataMode.values
          .map((m) => DropdownMenuItem(value: m, child: Text(m.displayName(l))))
          .toList(),
      onChanged: (v) => _onChanged(v, dataMode),
    );
  }
}
