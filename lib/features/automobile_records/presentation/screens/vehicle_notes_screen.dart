import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/help/help_button.dart';
import '../../../../core/help/help_registry.dart';
import '../../../../core/notes/catalog_palette.dart';
import '../../../gas_log/states/automobiles_state.dart';
import '../../../notes/presentation/widgets/attached_notes_section.dart';
import '../../../notes/states/attached_notes_state.dart';

class VehicleNotesScreen extends ConsumerWidget {
  const VehicleNotesScreen({super.key, required this.automobileId});

  /// The automobile's id IS its note id (automobiles are stored as notes),
  /// which is why a note attached to it reads as an automobile note.
  final int automobileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final name = ref
        .watch(automobilesStateProvider)
        .value
        ?.where((a) => a.id == automobileId)
        .firstOrNull
        ?.displayName;

    return Scaffold(
      appBar: AppBar(
        title: Text(name ?? l.recordsVehicleNotes),
        actions: const [HelpButton(helpId: HelpId.vehicleNotes)],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (name != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  l.vehicleNotesDomainCaption(name),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color:
                            CatalogPalette.domainStyle('AutomobileMan').color,
                      ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: FilledButton.icon(
                onPressed: () async {
                  await context.push('/notes/new?parent=$automobileId');
                  ref.invalidate(attachedNotesProvider(automobileId));
                },
                icon: const Icon(Icons.add),
                label: Text(l.vehicleNotesNew),
              ),
            ),
            AttachedNotesSection(
              parentId: automobileId,
              title: l.recordsNotes,
              showAdd: false,
            ),
          ],
        ),
      ),
    );
  }
}
