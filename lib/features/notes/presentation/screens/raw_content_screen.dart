import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RawContentScreen extends ConsumerWidget {
  const RawContentScreen({super.key, required this.noteId});
  final int noteId;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Scaffold(body: Center(child: Text('Raw $noteId')));
}
