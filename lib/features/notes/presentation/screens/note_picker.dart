import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/hmm_note.dart';
import '../../states/notes_list_state.dart';
import 'notes_list_screen.dart';

/// Opens the Notes screen full screen in pick mode and returns the note the
/// user taps, or null if they go back.
///
/// The Notes screen's search, tags and filters are shared state, so a search
/// typed here would otherwise still be applied when the user next opens
/// Notes. The query is put back as it was when the picker closes.
Future<HmmNote?> showNotePicker(
  BuildContext context, {
  bool Function(HmmNote note, String? catalogName)? canPick,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final notifier = container.read(notesListStateProvider.notifier);
  final saved = (await container.read(notesListStateProvider.future)).query;
  if (!context.mounted) return null;
  final platform = Theme.of(context).platform;
  final apple =
      platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
  Widget page(BuildContext routeContext) => NotesListScreen(
    onPick: (note) => Navigator.of(routeContext).pop(note),
    canPick: canPick,
  );
  final picked = await Navigator.of(context).push<HmmNote>(
    apple
        ? CupertinoPageRoute(builder: page, fullscreenDialog: true)
        : MaterialPageRoute(builder: page, fullscreenDialog: true),
  );
  notifier.setQuery(saved);
  return picked;
}
