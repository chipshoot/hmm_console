import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/hmm_note.dart';
import '../../states/notes_list_state.dart';

/// Modal note picker for inserting a link. Returns the chosen note, or null.
Future<HmmNote?> showNoteLinkPicker(BuildContext context, WidgetRef ref,
    {int? excludeNoteId}) {
  return showModalBottomSheet<HmmNote>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _NoteLinkPicker(excludeNoteId: excludeNoteId),
  );
}

class _NoteLinkPicker extends ConsumerStatefulWidget {
  const _NoteLinkPicker({this.excludeNoteId});
  final int? excludeNoteId;
  @override
  ConsumerState<_NoteLinkPicker> createState() => _NoteLinkPickerState();
}

class _NoteLinkPickerState extends ConsumerState<_NoteLinkPicker> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final all = ref.watch(notesListStateProvider).value?.all ?? const [];
    final q = _query.trim().toLowerCase();
    final items = all
        .where((n) => n.id != widget.excludeNoteId)
        .where((n) => q.isEmpty || n.subject.toLowerCase().contains(q))
        .toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                    hintText: 'Search notes', prefixIcon: Icon(Icons.search)),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final n in items)
                    ListTile(
                      title: Text(n.subject),
                      onTap: () => Navigator.of(context).pop(n),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
