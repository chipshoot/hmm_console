import 'package:flutter/material.dart';

import '../../states/notes_list_state.dart';

class SortSheet extends StatelessWidget {
  const SortSheet({super.key, required this.current, required this.onSelected});

  final NoteSort current;
  final ValueChanged<NoteSort> onSelected;

  static const _labels = {
    NoteSort.dateNewest: 'Date — newest first',
    NoteSort.dateOldest: 'Date — oldest first',
    NoteSort.lastModified: 'Last modified',
    NoteSort.subjectAZ: 'Subject — A → Z',
  };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in _labels.entries)
            ListTile(
              title: Text(entry.value),
              trailing: entry.key == current ? const Icon(Icons.check) : null,
              onTap: () {
                onSelected(entry.key);
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }
}
