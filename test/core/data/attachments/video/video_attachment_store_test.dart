import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/video/video_attachment_store.dart';
import 'package:hmm_console/core/data/attachments/video/video_picker.dart';
import 'package:hmm_console/core/data/vault/vault_file_store.dart';
import 'package:hmm_console/core/data/vault/vault_store.dart';

class _Vault implements IVaultStore {
  final puts = <String, String?>{};
  @override
  Future<void> putBytes(String p, Uint8List b, {String? contentType}) async =>
      puts[p] = contentType;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Files implements IVaultFileStore {
  final imported = <String>[];
  @override
  Future<void> importFile(String p, File source) async {
    imported.add(p);
    await source.delete();
  }

  @override
  Future<File?> localFile(String p) async => null;
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('vs'));
  tearDown(() => dir.deleteSync(recursive: true));

  PickedVideo pick({Uint8List? poster}) {
    final f = File('${dir.path}/a.mov')..writeAsBytesSync([1, 2, 3, 4]);
    return PickedVideo(
      tempPath: f.path,
      originalName: 'a.mov',
      contentType: 'video/quicktime',
      byteSize: 4,
      posterBytes: poster,
      durationMs: 1000,
    );
  }

  test('persist stores poster and video under one uuid', () async {
    final vault = _Vault();
    final files = _Files();
    final pk = pick(poster: Uint8List.fromList([9, 9]));
    final v = await VideoAttachmentStore(
      files: files,
      vault: vault,
    ).persist(noteId: 7, pick: pk);
    final re = RegExp(r'^attachments/note-7/([0-9a-f-]{36})\.(jpg|mov)$');
    final pm = re.firstMatch(v.poster!.path)!;
    final vm = re.firstMatch(v.video.path)!;
    expect(pm.group(1), vm.group(1));
    expect(vm.group(2), 'mov');
    expect(vault.puts, {v.poster!.path: 'image/jpeg'});
    expect(files.imported, [v.video.path]);
    expect(File(pk.tempPath).existsSync(), isFalse);
    expect(v.video.byteSize, 4);
    expect(v.durationMs, 1000);
  });

  test('no poster bytes means no poster and no putBytes', () async {
    final vault = _Vault();
    final v = await VideoAttachmentStore(
      files: _Files(),
      vault: vault,
    ).persist(noteId: 7, pick: pick());
    expect(v.poster, isNull);
    expect(vault.puts, isEmpty);
  });
}
