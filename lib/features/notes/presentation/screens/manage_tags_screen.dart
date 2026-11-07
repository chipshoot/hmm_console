import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/local/local_tag_repository.dart';
import '../../../../core/data/repository_providers.dart';
import '../../../../core/help/help_button.dart';
import '../../../../core/help/help_registry.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../l10n/gen/app_localizations.dart';

bool _isApple(TargetPlatform p) =>
    p == TargetPlatform.iOS || p == TargetPlatform.macOS;

/// Live tags with their note totals (zero-note tags included).
final _tagUsageProvider = StreamProvider.autoDispose<List<TagUsage>>(
  (ref) => ref.watch(tagRepositoryProvider).watchTagUsage(),
);

enum _TagAction { rename, merge, delete }

/// Rename, merge or delete tags. Merge and Delete are permanent, so each
/// asks first and offers no Undo.
class ManageTagsScreen extends ConsumerWidget {
  const ManageTagsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    ref.listen(_tagUsageProvider, (_, next) {
      if (next.hasError) {
        // Type only: never log tag names.
        debugPrint('ManageTags: load failed (${next.error.runtimeType})');
      }
    });
    final async = ref.watch(_tagUsageProvider);
    final tags = async.value ?? const <TagUsage>[];

    return AppScaffold(
      title: l.notesManageTagsTitle,
      actions: const [HelpButton(helpId: HelpId.manageTags)],
      slivers: [
        if (async.hasError && !async.hasValue)
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyState(
              icon: Icons.error_outline,
              message: l.notesLoadFailed,
              actionLabel: l.notesRetry,
              onAction: () => ref.invalidate(_tagUsageProvider),
            ),
          )
        else if (async.isLoading && !async.hasValue)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator.adaptive()),
          )
        else if (tags.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyState(
              icon: Icons.label_outline,
              message: l.notesManageTagsEmpty,
            ),
          )
        else
          SliverList.builder(
            itemCount: tags.length,
            itemBuilder: (context, i) {
              final t = tags[i];
              return ListTile(
                key: ValueKey(t.id),
                leading: const Icon(Icons.label_outline),
                title: Text(
                  t.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(l.notesManageTagsCount(t.noteCount)),
                onTap: () => _onTap(context, ref, t, tags),
              );
            },
          ),
      ],
    );
  }
}

Future<void> _onTap(
  BuildContext context,
  WidgetRef ref,
  TagUsage tag,
  List<TagUsage> all,
) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final repo = ref.read(tagRepositoryProvider);
  final others = [
    for (final t in all)
      if (t.id != tag.id) t,
  ];

  void failed() => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(l.notesManageTagsFailed)));

  Future<void> guarded(Future<void> Function() write) async {
    try {
      await write();
    } catch (e) {
      // Type only: never log tag names.
      debugPrint('ManageTags: write failed (${e.runtimeType})');
      failed();
    }
  }

  final action = await _pickAction(context, l, hasOthers: others.isNotEmpty);
  if (action == null || !context.mounted) return;

  switch (action) {
    case _TagAction.rename:
      final name = await _askName(context, l, tag.name);
      if (name == null) return;
      try {
        await repo.renameTag(tag.id, name);
      } on TagNameTaken catch (taken) {
        if (!context.mounted) return;
        final ok = await _confirm(
          context,
          message: l.notesTagNameTaken(name),
          actionLabel: l.notesMergeTagAction,
        );
        if (!ok) return;
        await guarded(
          () => repo.mergeTags(keepId: taken.existingId, mergeId: tag.id),
        );
      } catch (e) {
        debugPrint('ManageTags: rename failed (${e.runtimeType})');
        failed();
      }
    case _TagAction.merge:
      final keep = await _pickTarget(context, l, others);
      if (keep == null || !context.mounted) return;
      final ok = await _confirm(
        context,
        message: l.notesMergeTagConfirm(tag.noteCount, tag.name, keep.name),
        actionLabel: l.notesMergeTagAction,
      );
      if (!ok) return;
      await guarded(() => repo.mergeTags(keepId: keep.id, mergeId: tag.id));
    case _TagAction.delete:
      final ok = await _confirm(
        context,
        message: l.notesDeleteTagConfirm(tag.name, tag.noteCount),
        actionLabel: l.commonDelete,
        destructive: true,
      );
      if (!ok) return;
      await guarded(() => repo.deleteTag(tag.id));
  }
}

/// The row's action sheet: a Cupertino action sheet on iOS and macOS, a
/// Material bottom sheet elsewhere.
Future<_TagAction?> _pickAction(
  BuildContext context,
  AppLocalizations l, {
  required bool hasOthers,
}) {
  if (_isApple(Theme.of(context).platform)) {
    return showCupertinoModalPopup<_TagAction>(
      context: context,
      builder: (c) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(c).pop(_TagAction.rename),
            child: Text(l.notesRenameTag),
          ),
          if (hasOthers)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(c).pop(_TagAction.merge),
              child: Text(l.notesMergeTag),
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(c).pop(_TagAction.delete),
            child: Text(l.notesDeleteTag),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(c).pop(),
          child: Text(l.commonCancel),
        ),
      ),
    );
  }
  return showModalBottomSheet<_TagAction>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(l.notesRenameTag),
            onTap: () => Navigator.of(c).pop(_TagAction.rename),
          ),
          if (hasOthers)
            ListTile(
              leading: const Icon(Icons.merge),
              title: Text(l.notesMergeTag),
              onTap: () => Navigator.of(c).pop(_TagAction.merge),
            ),
          ListTile(
            leading: Icon(
              Icons.delete_outline,
              color: Theme.of(c).colorScheme.error,
            ),
            title: Text(l.notesDeleteTag),
            onTap: () => Navigator.of(c).pop(_TagAction.delete),
          ),
        ],
      ),
    ),
  );
}

/// Picks the tag to merge into, from the other live tags.
Future<TagUsage?> _pickTarget(
  BuildContext context,
  AppLocalizations l,
  List<TagUsage> others,
) {
  if (_isApple(Theme.of(context).platform)) {
    return showCupertinoModalPopup<TagUsage>(
      context: context,
      builder: (c) => CupertinoActionSheet(
        title: Text(l.notesMergeTag),
        actions: [
          for (final t in others)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(c).pop(t),
              child: Text(t.name),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(c).pop(),
          child: Text(l.commonCancel),
        ),
      ),
    );
  }
  return showModalBottomSheet<TagUsage>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(c).size.height * 0.6,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final t in others)
              ListTile(
                leading: const Icon(Icons.label_outline),
                title: Text(t.name),
                onTap: () => Navigator.of(c).pop(t),
              ),
          ],
        ),
      ),
    ),
  );
}

/// The Rename dialog; returns the normalized new name, or null on cancel.
Future<String?> _askName(
  BuildContext context,
  AppLocalizations l,
  String current,
) {
  final apple = _isApple(Theme.of(context).platform);
  return apple
      ? showCupertinoDialog<String>(
          context: context,
          builder: (_) => _RenameDialog(current: current, apple: true),
        )
      : showDialog<String>(
          context: context,
          builder: (_) => _RenameDialog(current: current, apple: false),
        );
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.current, required this.apple});
  final String current;
  final bool apple;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.current,
  )..addListener(() => setState(() {}));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? get _valid {
    final n = normalizeTagName(_controller.text);
    return n == null || n == widget.current ? null : n;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final valid = _valid;
    void save() => Navigator.of(context).pop(valid);
    if (widget.apple) {
      return CupertinoAlertDialog(
        title: Text(l.notesRenameTagTitle),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(controller: _controller, autofocus: true),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.commonCancel),
          ),
          CupertinoDialogAction(
            onPressed: valid == null ? null : save,
            child: Text(l.commonSave),
          ),
        ],
      );
    }
    return AlertDialog(
      title: Text(l.notesRenameTagTitle),
      content: TextField(controller: _controller, autofocus: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.commonCancel),
        ),
        TextButton(
          onPressed: valid == null ? null : save,
          child: Text(l.commonSave),
        ),
      ],
    );
  }
}

/// A confirmation with Cancel and [actionLabel]. Cupertino on iOS and macOS,
/// Material elsewhere.
Future<bool> _confirm(
  BuildContext context, {
  required String message,
  required String actionLabel,
  bool destructive = false,
}) async {
  final l = AppLocalizations.of(context);
  final apple = _isApple(Theme.of(context).platform);
  final Future<bool?> pending = apple
      ? showCupertinoDialog<bool>(
          context: context,
          builder: (c) => CupertinoAlertDialog(
            content: Text(message),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(c).pop(false),
                child: Text(l.commonCancel),
              ),
              CupertinoDialogAction(
                isDestructiveAction: destructive,
                onPressed: () => Navigator.of(c).pop(true),
                child: Text(actionLabel),
              ),
            ],
          ),
        )
      : showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(c).pop(false),
                child: Text(l.commonCancel),
              ),
              TextButton(
                style: destructive
                    ? TextButton.styleFrom(
                        foregroundColor: Theme.of(c).colorScheme.error,
                      )
                    : null,
                onPressed: () => Navigator.of(c).pop(true),
                child: Text(actionLabel),
              ),
            ],
          ),
        );
  return await pending ?? false;
}
