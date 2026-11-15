import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/video/keep_offline.dart';
import 'package:hmm_console/core/data/attachments/video/video_cache_index.dart';
import 'package:hmm_console/core/data/attachments/video/video_downloads.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late VideoCacheIndex index;
  late List<String> fetched;
  late Set<String> local;
  late bool network;
  late VideoFetchOutcome outcome;
  late bool fetchThrows;
  // Null: every kept path is still referenced by a note.
  Set<String>? referenced;
  late KeepOffline keep;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    index = VideoCacheIndex(await SharedPreferences.getInstance());
    fetched = [];
    local = {};
    network = true;
    outcome = VideoFetchOutcome.failed;
    fetchThrows = false;
    referenced = null;
    keep = KeepOffline(
      index: index,
      fetch: (p) async {
        fetched.add(p);
        if (fetchThrows) throw StateError('network');
        return VideoFetchResult(outcome);
      },
      isLocal: (p) async => local.contains(p),
      mayUseNetwork: () async => network,
      referencedPaths: () async => referenced ?? index.keptOffline,
    );
  });

  test('set true on a video not on the device starts a fetch', () async {
    await keep.set('a.mp4', true);
    expect(index.isKept('a.mp4'), isTrue);
    expect(fetched, ['a.mp4']);
  });

  group('a download started by ticking Keep offline', () {
    Future<int> tick() async {
      var reported = 0;
      await keep.set('a.mp4', true, onFetchFailed: () => reported++);
      await pumpEventQueue();
      return reported;
    }

    test('reports a failed download', () async {
      outcome = VideoFetchOutcome.failed;
      expect(await tick(), 1);
      expect(index.isKept('a.mp4'), isTrue);
    });

    test('reports a download that throws', () async {
      fetchThrows = true;
      expect(await tick(), 1);
    });

    test('does not report a finished, cancelled or still-uploading '
        'download', () async {
      for (final o in [
        VideoFetchOutcome.ready,
        VideoFetchOutcome.cancelled,
        VideoFetchOutcome.stillUploading,
      ]) {
        outcome = o;
        expect(await tick(), 0, reason: '$o');
      }
    });
  });

  test('set true on a local video does not fetch', () async {
    local.add('a.mp4');
    await keep.set('a.mp4', true);
    expect(index.isKept('a.mp4'), isTrue);
    expect(fetched, isEmpty);
  });

  test('set false unmarks and does not delete the file', () async {
    local.add('a.mp4');
    await keep.set('a.mp4', true);
    await keep.set('a.mp4', false);
    expect(index.isKept('a.mp4'), isFalse);
    expect(local, contains('a.mp4'));
    expect(fetched, isEmpty);
  });

  test('fetchMissing does nothing when the network is not allowed', () async {
    await index.setKept('a.mp4', true);
    network = false;
    expect(await keep.fetchMissing(), 0);
    expect(fetched, isEmpty);
  });

  test('fetchMissing fetches only kept paths that are not local', () async {
    await index.setKept('a.mp4', true);
    await index.setKept('b.mp4', true);
    local.add('b.mp4');
    expect(await keep.fetchMissing(), 1);
    expect(fetched, ['a.mp4']);
  });

  test(
    'fetchMissing unmarks and skips kept paths no note references',
    () async {
      await index.setKept('a.mp4', true);
      await index.setKept('gone.mp4', true);
      referenced = {'a.mp4'};
      expect(await keep.fetchMissing(), 1);
      expect(fetched, ['a.mp4']);
      expect(index.isKept('gone.mp4'), isFalse);
      expect(index.isKept('a.mp4'), isTrue);
    },
  );
}
