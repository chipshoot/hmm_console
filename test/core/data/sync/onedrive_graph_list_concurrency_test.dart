// The attachment listing walks OneDrive one folder per request. Sequentially,
// that is one round-trip per note that has an attachment — the phase measured
// at 2.1s of a 2.8s sync on the device, growing with every scan added.
//
// Correctness alone cannot tell a parallel walk from a sequential one: both
// return the same set. So this test injects latency per request and observes
// how many are in flight at once. That number IS the fix.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/sync/onedrive_graph_client.dart';

import 'onedrive_test_fakes.dart';

/// A fake Graph tree: folder path -> children. Files carry no 'folder' key.
Map<String, dynamic> _folder(String name) => {'name': name, 'folder': {'childCount': 1}};
Map<String, dynamic> _file(String name) => {'name': name, 'file': {}};

void main() {
  late Dio dio;
  late int inFlight;
  late int peakInFlight;
  late int requests;

  /// Twenty note folders under attachments/, each with one file — the shape
  /// of a real vault after a few months of scans.
  final tree = <String, List<Map<String, dynamic>>>{
    'vault': [_folder('attachments')],
    'vault/attachments': [for (var i = 0; i < 20; i++) _folder('note-$i')],
    for (var i = 0; i < 20; i++) 'vault/attachments/note-$i': [_file('scan-$i.jpg')],
  };

  setUp(() {
    inFlight = 0;
    peakInFlight = 0;
    requests = 0;
    dio = Dio(BaseOptions(validateStatus: (_) => true));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) async {
      requests++;
      inFlight++;
      if (inFlight > peakInFlight) peakInFlight = inFlight;
      // Every folder listing costs a round-trip. Long enough that sequential
      // and parallel walks are unmistakably different in wall-clock time.
      await Future<void>.delayed(const Duration(milliseconds: 30));
      inFlight--;

      final m = RegExp(r'users/SUB-1/(.*):/children$').firstMatch(o.path);
      final children = m == null ? null : tree[m.group(1)!];
      h.resolve(Response(
        requestOptions: o,
        statusCode: children == null ? 404 : 200,
        data: children == null ? null : {'value': children},
      ));
    }));
  });

  OneDriveGraphClient client() =>
      OneDriveGraphClient(FakeOneDriveAuth(), () async => 'SUB-1', dio: dio);

  test('lists every file across 20 note folders', () async {
    final paths = await client().listAttachments();

    expect(paths, hasLength(20));
    expect(paths, contains('attachments/note-0/scan-0.jpg'));
    expect(paths, contains('attachments/note-19/scan-19.jpg'));
    // 1 (vault) + 1 (attachments) + 20 (notes) — no folder listed twice.
    expect(requests, 22);
  });

  test('sibling folders are listed CONCURRENTLY, not one at a time', () async {
    await client().listAttachments();

    // Sequential: peak is 1, always. The 20 note folders are siblings with
    // no dependency between them, so they can all be in flight together.
    expect(peakInFlight, greaterThan(1),
        reason: 'a sequential walk never has more than one request in flight');
  });

  test('a wide tree finishes in far less than the sum of its round-trips',
      () async {
    final sw = Stopwatch()..start();
    await client().listAttachments();
    sw.stop();

    // 22 requests x 30ms = 660ms if sequential. The walk has three levels,
    // so the floor is ~90ms; anything under half the sequential cost proves
    // the siblings overlapped.
    expect(sw.elapsedMilliseconds, lessThan(330),
        reason: '22 x 30ms sequential would be ~660ms');
  });

  test('one failing subfolder fails the WHOLE listing, never a partial set',
      () async {
    // The orchestrator treats every referenced file missing from the listing
    // as "not on remote" and pushes it again — harmless — but a file it
    // believes IS gone gets treated as deleted. A silently partial listing
    // from one 500 would therefore look like mass deletion. The sequential
    // walk threw on the first bad folder; the parallel one must too.
    dio.interceptors.clear();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) async {
      final m = RegExp(r'users/SUB-1/(.*):/children$').firstMatch(o.path);
      final path = m?.group(1);
      if (path == 'vault/attachments/note-7') {
        h.resolve(Response(requestOptions: o, statusCode: 500,
            data: {'error': {'message': 'boom'}}));
        return;
      }
      final children = path == null ? null : tree[path];
      h.resolve(Response(
        requestOptions: o,
        statusCode: children == null ? 404 : 200,
        data: children == null ? null : {'value': children},
      ));
    }));

    await expectLater(client().listAttachments(), throwsA(anything));
  });
}
