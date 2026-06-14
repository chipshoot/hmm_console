import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/attached_notes_section.dart';

class SubsystemNotesScreen extends ConsumerWidget {
  const SubsystemNotesScreen({
    super.key,
    required this.anchorId,
    required this.anchorName,
  });

  final int anchorId;
  final String anchorName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('$anchorName notes')),
      body: SingleChildScrollView(
        child:
            AttachedNotesSection(parentId: anchorId, title: '$anchorName notes'),
      ),
    );
  }
}
