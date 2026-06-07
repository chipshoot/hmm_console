import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NoteDetailScreen extends ConsumerWidget {
  const NoteDetailScreen({super.key, required this.noteId});
  final int noteId;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Scaffold(body: Center(child: Text('Note $noteId')));
}
