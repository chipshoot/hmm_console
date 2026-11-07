import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/local/local_tag_repository.dart';
import '../../../../core/data/repository_providers.dart';
import '../../../../l10n/gen/app_localizations.dart';

const int _maxSuggestions = 6;

/// Tags of one note, by name: removable chips followed by a text field with
/// suggestions from the live tags. Names (not ids) because a new tag is only
/// created when the note is saved.
///
/// Enter, a comma, or tapping a suggestion commits a name. A name equal to a
/// chosen one (case-insensitive) or one `normalizeTagName` rejects is
/// ignored. Live tags are read lazily, on the first keystroke.
class NoteTagField extends ConsumerStatefulWidget {
  const NoteTagField({
    super.key,
    required this.names,
    required this.onChanged,
    this.enabled = true,
  });

  final List<String> names;
  final ValueChanged<List<String>> onChanged;

  /// False hides nothing but blocks edits (chips cannot be added or removed).
  final bool enabled;

  @override
  ConsumerState<NoteTagField> createState() => NoteTagFieldState();
}

class NoteTagFieldState extends ConsumerState<NoteTagField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  StreamSubscription<Map<int, String>>? _sub;
  List<String> _live = const [];

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _listenLive() {
    if (_sub != null) return;
    _sub = ref.read(tagRepositoryProvider).watchLiveTagNames().listen((m) {
      if (mounted) setState(() => _live = m.values.toList());
    }, onError: (Object e) => debugPrint('tag suggestions: ${e.runtimeType}'));
  }

  bool _has(String name) =>
      widget.names.any((n) => n.toLowerCase() == name.toLowerCase());

  void _commit(String raw) {
    final name = normalizeTagName(raw);
    if (name == null || _has(name)) return;
    widget.onChanged([...widget.names, name]);
  }

  void _onText(String text) {
    _listenLive();
    if (text.contains(',')) {
      final parts = text.split(',');
      for (final p in parts.take(parts.length - 1)) {
        _commit(p);
      }
      _controller.value = TextEditingValue(
        text: parts.last,
        selection: TextSelection.collapsed(offset: parts.last.length),
      );
    }
    setState(() {});
  }

  /// Commits whatever is typed but not yet committed (call before saving).
  void commitPending() {
    if (_controller.text.trim().isEmpty) return;
    _commit(_controller.text);
    _controller.clear();
  }

  void _submit(String text) {
    _commit(text);
    _controller.clear();
    setState(() {});
    _focus.requestFocus();
  }

  List<String> _suggestions() {
    final q = _controller.text.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final pool = _live.where((n) => !_has(n)).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final prefix = pool.where((n) => n.toLowerCase().startsWith(q));
    final contains = pool.where(
      (n) => !n.toLowerCase().startsWith(q) && n.toLowerCase().contains(q),
    );
    return [...prefix, ...contains].take(_maxSuggestions).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final suggestions = _suggestions();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final n in widget.names)
              InputChip(
                label: Text(n),
                visualDensity: VisualDensity.compact,
                deleteButtonTooltipMessage: l.notesEditorRemoveTag(n),
                onDeleted: widget.enabled
                    ? () => widget.onChanged(
                        widget.names.where((x) => x != n).toList(),
                      )
                    : null,
              ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 120, maxWidth: 220),
              child: IntrinsicWidth(
                child: TextField(
                  controller: _controller,
                  enabled: widget.enabled,
                  focusNode: _focus,
                  onChanged: _onText,
                  onSubmitted: _submit,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: l.notesEditorTagsHint,
                    labelText: l.notesEditorTagsLabel,
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (suggestions.isNotEmpty)
          Wrap(
            spacing: 6,
            children: [
              for (final s in suggestions)
                ActionChip(
                  label: Text(s),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _submit(s),
                ),
            ],
          ),
      ],
    );
  }
}
