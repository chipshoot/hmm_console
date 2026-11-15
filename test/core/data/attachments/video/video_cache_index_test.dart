import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/video/video_cache_index.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('touch then lastUsed round-trips across a new index', () {
    final at = DateTime.fromMillisecondsSinceEpoch(1700000000000);
    VideoCacheIndex(prefs).touch('attachments/n/a.mov', at);
    expect(VideoCacheIndex(prefs).lastUsed('attachments/n/a.mov'), at);
    expect(VideoCacheIndex(prefs).lastUsed('attachments/n/b.mov'), isNull);
  });

  test('setKept adds and removes, and survives a new index', () async {
    final i = VideoCacheIndex(prefs);
    await i.setKept('a.mov', true);
    expect(VideoCacheIndex(prefs).isKept('a.mov'), isTrue);
    expect(VideoCacheIndex(prefs).keptOffline, {'a.mov'});
    await i.setKept('a.mov', false);
    expect(VideoCacheIndex(prefs).isKept('a.mov'), isFalse);
  });

  test('forget drops the last-used entry and keeps the kept mark', () async {
    final i = VideoCacheIndex(prefs);
    i.touch('a.mov');
    await i.setKept('a.mov', true);
    await i.forget('a.mov');
    expect(i.lastUsed('a.mov'), isNull);
    expect(i.isKept('a.mov'), isTrue);
  });
}
