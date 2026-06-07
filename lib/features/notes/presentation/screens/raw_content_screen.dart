import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/note_detail_screen.dart' show noteDetailProvider;

String prettyContent(String? content) {
  if (content == null || content.trim().isEmpty) return '(no content)';
  try {
    return const JsonEncoder.withIndent('  ').convert(jsonDecode(content));
  } catch (_) {
    return content; // not JSON — show verbatim
  }
}

class RawContentScreen extends ConsumerWidget {
  const RawContentScreen({super.key, required this.noteId});
  final int noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(noteDetailProvider(noteId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raw content'),
        actions: [
          async.maybeWhen(
            data: (d) => IconButton(
              tooltip: 'Copy',
              icon: const Icon(Icons.copy),
              onPressed: () => Clipboard.setData(
                  ClipboardData(text: prettyContent(d.note.content))),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (d) {
          final version = d.note.version == null
              ? 'null'
              : '0x${d.note.version!.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  prettyContent(d.note.content),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
                const Divider(),
                Text('catalog: ${d.catalog?.name ?? '(none)'}'),
                Text('uuid: ${d.note.uuid}'),
                Text('version: $version'),
              ],
            ),
          );
        },
      ),
    );
  }
}
