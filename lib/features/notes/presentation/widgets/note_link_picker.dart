import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/hmm_note.dart';
import '../../states/notes_list_state.dart';

/// Modal note picker for inserting a link. Returns the chosen note, or null.
Future<HmmNote?> showNoteLinkPicker(
  BuildContext context,
  WidgetRef ref, {
  int? excludeNoteId,
}) {
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
    final async = ref.watch(notesListStateProvider);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search notes',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Flexible(child: _list(async)),
          ],
        ),
      ),
    );
  }

  Widget _list(AsyncValue<NotesListData> async) {
    // Surface loading/error instead of silently collapsing to an empty list.
    if (async.isLoading && !async.hasValue) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (async.hasError && !async.hasValue) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text("Couldn't load notes")),
      );
    }
    final q = _query.trim().toLowerCase();
    final items = (async.value?.all ?? const <HmmNote>[])
        .where((n) => n.id != widget.excludeNoteId)
        .where((n) => q.isEmpty || n.subject.toLowerCase().contains(q))
        .toList();
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('No notes')),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: items.length,
      itemBuilder: (_, i) {
        final n = items[i];
        return ListTile(
          key: ValueKey(n.id),
          title: Text(n.subject),
          onTap: () => Navigator.of(context).pop(n),
        );
      },
    );
  }
}
