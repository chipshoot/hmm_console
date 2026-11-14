import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/video/video_upload_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('round-trips entries and survives a fresh store', () async {
    await VideoUploadQueueStore().put(
      'p',
      const VideoUploadEntry(
        path: 'a.mp4',
        total: 25,
        session: 's1',
        sent: 10,
        mobileOk: true,
      ),
    );
    final read = await VideoUploadQueueStore().read('p');
    expect(read, hasLength(1));
    expect(read.single.path, 'a.mp4');
    expect(read.single.total, 25);
    expect(read.single.session, 's1');
    expect(read.single.sent, 10);
    expect(read.single.mobileOk, isTrue);
    expect(await VideoUploadQueueStore().read('other'), isEmpty);
  });

  test('put replaces by path and remove deletes', () async {
    final s = VideoUploadQueueStore();
    await s.put('p', const VideoUploadEntry(path: 'a', total: 1));
    await s.put('p', const VideoUploadEntry(path: 'a', total: 1, sent: 5));
    await s.put('p', const VideoUploadEntry(path: 'b', total: 2));
    final read = await s.read('p');
    expect(read, hasLength(2));
    expect(read.firstWhere((e) => e.path == 'a').sent, 5);
    await s.remove('p', 'a');
    expect((await s.read('p')).map((e) => e.path), ['b']);
  });

  test('bad JSON reads as empty', () async {
    SharedPreferences.setMockInitialValues({
      'video_upload_queue:p': '{not json',
    });
    expect(await VideoUploadQueueStore().read('p'), isEmpty);
  });
}
