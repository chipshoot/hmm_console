import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../notes/presentation/widgets/attached_notes_section.dart';

class VehicleNotesScreen extends ConsumerWidget {
  const VehicleNotesScreen({super.key, required this.automobileId});

  /// The automobile's id IS its note id (automobiles are stored as notes).
  final int automobileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.recordsVehicleNotes)),
      body: SingleChildScrollView(
        child: AttachedNotesSection(parentId: automobileId, title: l.recordsNotes),
      ),
    );
  }
}
