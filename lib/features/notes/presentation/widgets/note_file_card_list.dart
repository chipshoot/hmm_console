import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/data/attachments/attachment_providers.dart';
import '../../../../core/data/attachments/attachment_ref.dart';
import '../../../../core/data/attachments/picker/file_byte_source.dart';
import '../util/open_attachment.dart';
import 'note_audio_card.dart';
import 'note_file_card.dart';

/// Renders saved file refs + pending picks. Audio (`audio/*`) renders as a
/// [NoteAudioCard]; everything else (PDF) as a [NoteFileCard].
class NoteFileCardList extends ConsumerWidget {
  const NoteFileCardList({
    super.key,
    required this.saved,
    this.pending = const [],
    this.onRemovePending,
    this.readOnly = false,
  });

  final List<AttachmentRef> saved;
  final List<PickedFileBytes> pending;
  final void Function(int index)? onRemovePending;
  final bool readOnly;

  static bool _isAudio(String contentType) => contentType.startsWith('audio/');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (saved.isEmpty && pending.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in saved) _savedCard(context, ref, s),
        for (var i = 0; i < pending.length; i++) _pendingCard(i),
      ],
    );
  }

  Widget _savedCard(BuildContext context, WidgetRef ref, AttachmentRef s) {
    final name =
        s is VaultRef ? (s.originalName ?? p.basename(s.path)) : 'file';
    final contentType = s is VaultRef ? s.contentType : '';
    if (_isAudio(contentType)) {
      return NoteAudioCard(
        name: name,
        readOnly: true,
        resolvePath: () => _refToTempPath(ref, s, name),
      );
    }
    return NoteFileCard(
      name: name,
      byteSize: s is VaultRef ? s.byteSize : 0,
      readOnly: true,
      onOpen: () async {
        final err = await openAttachment(ref, s);
        if (err != null && context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(err)));
        }
      },
    );
  }

  Widget _pendingCard(int i) {
    final pick = pending[i];
    final remove = (readOnly || onRemovePending == null)
        ? null
        : () => onRemovePending!(i);
    if (_isAudio(pick.contentType ?? '')) {
      return NoteAudioCard(
        name: pick.originalName,
        readOnly: readOnly,
        onRemove: remove,
        resolvePath: () => _bytesToTempPath(pick),
      );
    }
    return NoteFileCard(
      name: pick.originalName,
      byteSize: pick.bytes.length,
      readOnly: readOnly,
      onRemove: remove,
    );
  }

  /// Resolve a saved ref's bytes to a per-ref temp file path (mirrors the
  /// open_attachment temp-dir keying so same-named files don't collide).
  Future<String> _refToTempPath(
      WidgetRef ref, AttachmentRef attachment, String name) async {
    final resolver = await ref.read(attachmentResolverProvider.future);
    final bytes = await resolver.resolve(attachment);
    if (bytes == null) throw StateError('audio not available');
    final key = attachment is VaultRef
        ? attachment.path.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_')
        : 'misc';
    final dir = await getTemporaryDirectory();
    final outDir = Directory(p.join(dir.path, 'note-audio', key));
    await outDir.create(recursive: true);
    final file = File(p.join(outDir.path, name));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<String> _bytesToTempPath(PickedFileBytes pick) async {
    final dir = await getTemporaryDirectory();
    final outDir = Directory(p.join(dir.path, 'note-audio-pending'));
    await outDir.create(recursive: true);
    final file = File(p.join(outDir.path, pick.originalName));
    await file.writeAsBytes(pick.bytes);
    return file.path;
  }
}
