// Every icon button must be an HmmIconButton, which cannot be built without a
// localized tooltip. Files that predate it are allow-listed with their count;
// phase 3 of docs/superpowers/specs/2026-09-27-in-app-help-design.md empties
// this list. Never add to it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _allowed = <String, int>{
  'lib/core/contact_block/widgets/contact_info_editor.dart': 1,
  'lib/core/data/attachments/widgets/attachments_section.dart': 3,
  'lib/core/widgets/editable_info_card.dart': 1,
  'lib/features/automobile_records/presentation/screens/automobile_hub_screen.dart': 2,
  'lib/features/automobile_records/presentation/screens/insurance_policies_screen.dart': 2,
  'lib/features/automobile_records/presentation/screens/scheduled_services_screen.dart': 2,
  'lib/features/automobile_records/presentation/screens/service_record_form_screen.dart': 1,
  'lib/features/automobile_records/presentation/screens/service_records_screen.dart': 2,
  'lib/features/automobile_records/presentation/widgets/optional_date_picker.dart': 1,
  'lib/features/automobile_records/presentation/widgets/service_line_item_row.dart': 1,
  'lib/features/cheatsheet/presentation/screens/cheatsheet_designer_screen.dart': 2,
  'lib/features/cheatsheet/presentation/screens/cheatsheet_detail_screen.dart': 3,
  'lib/features/cheatsheet/presentation/screens/cheatsheet_wallet_screen.dart': 1,
  'lib/features/cheatsheet/presentation/widgets/source_picker.dart': 1,
  'lib/features/driver_licence/presentation/screens/driver_licence_screen.dart': 2,
  'lib/features/gas_log/presentation/screens/automobile_edit_screen.dart': 2,
  'lib/features/gas_log/presentation/screens/automobile_management_screen.dart': 1,
  'lib/features/gas_log/presentation/screens/gas_log_list_screen.dart': 2,
  'lib/features/gas_log/presentation/screens/gas_station_management_screen.dart': 1,
  'lib/features/gas_log/presentation/widgets/gas_log_list_tile.dart': 1,
  'lib/features/gas_log/presentation/widgets/manageable_automobile_tile.dart': 1,
  'lib/features/gas_log/presentation/widgets/manageable_gas_station_tile.dart': 2,
  'lib/features/gas_log/presentation/widgets/station_dropdown.dart': 2,
  'lib/features/launcher/presentation/launcher_manage_screen.dart': 2,
  'lib/features/notes/presentation/screens/notes_list_screen.dart': 4,
  'lib/features/notes/presentation/screens/raw_content_screen.dart': 1,
  'lib/features/notes/presentation/widgets/media_toolbar.dart': 6,
  'lib/features/notes/presentation/widgets/note_audio_card.dart': 2,
};

// `\b` keeps HmmIconButton( out; PlatformIconButton( is matched explicitly.
final _raw =
    RegExp(r'\bIconButton(\(|\.filled|\.outlined)|PlatformIconButton\(');

Map<String, int> _scan() {
  final found = <String, int>{};
  for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
    final path = f.path.replaceAll(r'\', '/');
    if (!path.endsWith('.dart') ||
        path.contains('/l10n/gen/') ||
        path.endsWith('core/widgets/hmm_icon_button.dart')) {
      continue;
    }
    final n = _raw.allMatches(f.readAsStringSync()).length;
    if (n > 0) found[path] = n;
  }
  return found;
}

void main() {
  test('icon buttons go through HmmIconButton', () {
    final found = _scan();
    final offenders = [
      for (final e in found.entries)
        if (e.value > (_allowed[e.key] ?? 0))
          '${e.key}: ${e.value} raw (allowed ${_allowed[e.key] ?? 0})',
    ];
    expect(offenders, isEmpty,
        reason: 'Use HmmIconButton (lib/core/widgets/hmm_icon_button.dart) '
            'with a localized tooltip.');
  });

  test('allow-list shrinks as files are cleaned', () {
    final found = _scan();
    final stale = [
      for (final e in _allowed.entries)
        if ((found[e.key] ?? 0) < e.value)
          '${e.key}: allowed ${e.value}, now ${found[e.key] ?? 0} — lower it',
    ];
    expect(stale, isEmpty);
  });
}
