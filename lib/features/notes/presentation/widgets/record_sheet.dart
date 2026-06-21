import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/attachments/picker/file_byte_source.dart';
import '../../../../core/data/attachments/picker/image_attachment_picker.dart'
    show kMaxAttachmentBytes;
import '../../../../core/data/attachments/recorder/audio_recorder.dart';

/// Opens the modal record sheet. Returns a pending audio pick on Stop, or
/// null on Cancel / dismiss / no permission.
Future<PickedFileBytes?> showRecordSheet(
    BuildContext context, WidgetRef ref) async {
  final recorder = ref.read(audioRecorderProvider);
  if (!await recorder.hasPermission()) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Microphone permission needed to record')));
    }
    return null;
  }
  try {
    await recorder.start();
  } catch (_) {
    await recorder.cancel();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start recording')));
    }
    return null;
  }
  if (!context.mounted) {
    await recorder.cancel();
    return null;
  }
  final pick = await showModalBottomSheet<PickedFileBytes?>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _RecordSheetBody(recorder: recorder),
  );
  // Dismissed without an explicit Stop/Cancel button → treat as cancel.
  if (pick == null) await recorder.cancel();
  return pick;
}

class _RecordSheetBody extends StatefulWidget {
  const _RecordSheetBody({required this.recorder});
  final AudioRecorderService recorder;

  @override
  State<_RecordSheetBody> createState() => _RecordSheetBodyState();
}

class _RecordSheetBodyState extends State<_RecordSheetBody> {
  Timer? _ticker;
  int _seconds = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
        const Duration(seconds: 1), (_) => setState(() => _seconds++));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String get _time {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _stop() async {
    if (_busy) return;
    setState(() => _busy = true);
    _ticker?.cancel();
    final rec = await widget.recorder.stop();
    if (!mounted) return;
    if (rec == null) {
      Navigator.of(context).pop(null);
      return;
    }
    if (rec.bytes.lengthInBytes > kMaxAttachmentBytes) {
      // Discard rather than fail at save time (recording lives only in memory).
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Recording is too long; please record a shorter one')));
      Navigator.of(context).pop(null);
      return;
    }
    Navigator.of(context).pop(PickedFileBytes(
      bytes: rec.bytes,
      originalName: 'recording-${DateTime.now().millisecondsSinceEpoch}.m4a',
      contentType: rec.contentType,
    ));
  }

  Future<void> _cancel() async {
    if (_busy) return;
    setState(() => _busy = true);
    _ticker?.cancel();
    await widget.recorder.cancel();
    if (mounted) Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.fiber_manual_record, color: Colors.red),
                const SizedBox(width: 8),
                Text('Recording…  $_time',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                    onPressed: _busy ? null : _cancel,
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: _busy ? null : _stop,
                    child: const Text('Stop')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
