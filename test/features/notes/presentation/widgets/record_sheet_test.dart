import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/picker/file_byte_source.dart';
import 'package:hmm_console/core/data/attachments/recorder/audio_recorder.dart';
import 'package:hmm_console/features/notes/presentation/widgets/record_sheet.dart';

class _FakeRecorder implements AudioRecorderService {
  _FakeRecorder({this.permission = true});
  final bool permission;
  bool started = false;
  @override
  Future<bool> hasPermission() async => permission;
  @override
  Future<void> start() async => started = true;
  @override
  Future<AudioRecording?> stop() async =>
      AudioRecording(bytes: Uint8List.fromList([1, 2, 3]), fileName: 'rec.m4a');
  @override
  Future<void> cancel() async {}
}

Widget _harness(_FakeRecorder rec, void Function(PickedFileBytes?) onResult) {
  return ProviderScope(
    overrides: [audioRecorderProvider.overrideWithValue(rec)],
    child: MaterialApp(
      home: Scaffold(
        body: Consumer(builder: (context, ref, _) {
          return ElevatedButton(
            onPressed: () async => onResult(await showRecordSheet(context, ref)),
            child: const Text('go'),
          );
        }),
      ),
    ),
  );
}

void main() {
  testWidgets('Stop returns an audio PickedFileBytes', (tester) async {
    final rec = _FakeRecorder();
    PickedFileBytes? result;
    await tester.pumpWidget(_harness(rec, (r) => result = r));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(rec.started, isTrue);
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.contentType, 'audio/mp4');
  });

  testWidgets('permission denied returns null without recording',
      (tester) async {
    final rec = _FakeRecorder(permission: false);
    PickedFileBytes? result;
    var called = false;
    await tester.pumpWidget(_harness(rec, (r) {
      result = r;
      called = true;
    }));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(rec.started, isFalse);
    expect(called, isTrue);
    expect(result, isNull);
  });
}
