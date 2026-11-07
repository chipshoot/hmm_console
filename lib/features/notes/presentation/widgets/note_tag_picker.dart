import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/local/local_tag_repository.dart';
import '../../../../core/data/repository_providers.dart';
import '../../../../l10n/gen/app_localizations.dart';

/// How a tag stands over the notes being edited: on all of them, on some of
/// them (only possible for several notes), or on none.
enum TagMark { all, some, none }

/// What the picker changed: tag ids to add to every note and tag ids to
/// remove from every note. Tags left as `some` appear in neither set.
typedef TagPickResult = ({Set<int> add, Set<int> remove});

bool _isApple(TargetPlatform p) =>
    p == TargetPlatform.iOS || p == TargetPlatform.macOS;

/// Pick tags for one or more notes in a modal bottom sheet. [initial] lists
/// only the tags that are `all` or `some` (absent means none). Returns null
/// on Cancel or dismiss, and an empty add/remove when nothing changed. Tags
/// are read through `tagRepositoryProvider` inside the sheet.
Future<TagPickResult?> showNoteTagPicker(
  BuildContext context, {
  required Map<int, TagMark> initial,
}) => showModalBottomSheet<TagPickResult>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _TagPickerSheet(initial: initial),
);

class _TagPickerSheet extends ConsumerStatefulWidget {
  const _TagPickerSheet({required this.initial});

  final Map<int, TagMark> initial;

  @override
  ConsumerState<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends ConsumerState<_TagPickerSheet> {
  late final Map<int, TagMark> _marks = Map.of(widget.initial);
  late final Stream<List<TagUsage>> _tags = ref
      .read(tagRepositoryProvider)
      .watchTagUsage();
  final _controller = TextEditingController();
  String _query = '';
  bool _creating = false;
  bool _createFailed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  TagMark _markOf(int id) => _marks[id] ?? TagMark.none;

  void _toggle(int id) => setState(() {
    _marks[id] = _markOf(id) == TagMark.all ? TagMark.none : TagMark.all;
  });

  TagPickResult _result() {
    final add = <int>{};
    final remove = <int>{};
    final ids = {...widget.initial.keys, ..._marks.keys};
    for (final id in ids) {
      final before = widget.initial[id] ?? TagMark.none;
      final after = _markOf(id);
      if (after == before) continue;
      if (after == TagMark.all) add.add(id);
      if (after == TagMark.none) remove.add(id);
    }
    return (add: add, remove: remove);
  }

  Future<void> _create(String name) async {
    if (_creating) return;
    final repo = ref.read(tagRepositoryProvider);
    setState(() {
      _creating = true;
      _createFailed = false;
    });
    try {
      final tag = await repo.ensureTag(name);
      if (!mounted) return;
      setState(() {
        _marks[tag.id] = TagMark.all;
        _controller.clear();
        _query = '';
      });
    } catch (e) {
      debugPrint('NoteTagPicker: create failed (${e.runtimeType})');
      if (mounted) setState(() => _createFailed = true);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final apple = _isApple(Theme.of(context).platform);
    final media = MediaQuery.of(context);
    final normalized = normalizeTagName(_query);

    final search = apple
        ? CupertinoSearchTextField(
            controller: _controller,
            placeholder: l.notesTagPickerHint,
            onChanged: (v) => setState(() => _query = v),
          )
        : TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: l.notesTagPickerHint,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          );

    Widget cancel(String text) => apple
        ? CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.of(context).pop(),
            child: Text(text),
          )
        : TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(text),
          );
    Widget done(String text) => apple
        ? CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _creating
                ? null
                : () => Navigator.of(context).pop(_result()),
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          )
        : TextButton(
            onPressed: _creating
                ? null
                : () => Navigator.of(context).pop(_result()),
            child: Text(text),
          );

    return AnimatedPadding(
      duration: const Duration(milliseconds: 100),
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.8),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    cancel(l.commonCancel),
                    Expanded(
                      child: Text(
                        l.notesTagPickerTitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    done(l.commonDone),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: search,
              ),
              if (_createFailed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    l.notesTagCreateFailed,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Flexible(
                child: StreamBuilder<List<TagUsage>>(
                  stream: _tags,
                  builder: (context, snap) {
                    final all = snap.data ?? const <TagUsage>[];
                    final needle = (normalized ?? _query.trim()).toLowerCase();
                    final shown = needle.isEmpty
                        ? all
                        : [
                            for (final t in all)
                              if (t.name.toLowerCase().contains(needle)) t,
                          ];
                    final exists =
                        normalized != null &&
                        all.any(
                          (t) =>
                              t.name.toLowerCase() == normalized.toLowerCase(),
                        );
                    final canCreate = normalized != null && !exists;
                    return ListView(
                      shrinkWrap: true,
                      children: [
                        if (canCreate)
                          _createRow(
                            apple,
                            l.notesTagCreate(normalized),
                            () => _create(normalized),
                          ),
                        for (final t in shown) _tagRow(apple, t),
                        if (all.isEmpty && _query.isEmpty && snap.hasData)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              l.notesTagPickerEmpty,
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _createRow(bool apple, String label, VoidCallback onTap) => apple
      ? CupertinoListTile(
          leading: const Icon(CupertinoIcons.add_circled),
          title: Text(label),
          onTap: onTap,
        )
      : ListTile(
          leading: const Icon(Icons.add_circle_outline),
          title: Text(label),
          onTap: onTap,
        );

  Widget _tagRow(bool apple, TagUsage t) {
    final mark = _markOf(t.id);
    if (!apple) {
      return CheckboxListTile(
        tristate: true,
        value: switch (mark) {
          TagMark.all => true,
          TagMark.some => null,
          TagMark.none => false,
        },
        title: Text(t.name),
        controlAffinity: ListTileControlAffinity.leading,
        onChanged: (_) => _toggle(t.id),
      );
    }
    return CupertinoListTile(
      title: Text(t.name),
      trailing: switch (mark) {
        TagMark.all => const Icon(CupertinoIcons.check_mark),
        TagMark.some => const Icon(CupertinoIcons.minus),
        TagMark.none => null,
      },
      onTap: () => _toggle(t.id),
    );
  }
}
