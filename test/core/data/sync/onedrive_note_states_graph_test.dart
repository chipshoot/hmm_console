import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/sync/onedrive_graph_client.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'onedrive_test_fakes.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  const path =
      '/me/drive/special/approot:/users/SUB-1/note-states.json:/content';

  setUp(() {
    dio = Dio(BaseOptions(validateStatus: (_) => true));
    adapter = DioAdapter(dio: dio);
  });

  OneDriveGraphClient client() =>
      OneDriveGraphClient(FakeOneDriveAuth(), () async => 'SUB-1', dio: dio);

  test('getNoteStates returns the decoded body on 200', () async {
    adapter.onGet(
      path,
      (s) => s.reply(200, {
        'version': 1,
        'states': [
          {
            'noteUuid': 'n1',
            'isPinned': true,
            'flagColor': null,
            'lastModified': '2026-10-01T09:00:00.000Z',
          },
        ],
      }),
    );

    final doc = await client().getNoteStates();

    expect((doc!['states'] as List).single['noteUuid'], 'n1');
  });

  test(
    'getNoteStates returns null when note-states.json is absent (404)',
    () async {
      adapter.onGet(path, (s) => s.reply(404, null));

      expect(await client().getNoteStates(), isNull);
    },
  );

  test(
    'putNoteStates PUTs the document to the user-scoped note-states.json',
    () async {
      Map<String, dynamic>? captured;
      adapter.onPut(
        path,
        (s) => s.reply(200, {'ok': true}),
        data: Matchers.any,
      );
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            if (o.method == 'PUT' && o.path == path && o.data is Map) {
              captured = o.data as Map<String, dynamic>;
            }
            h.next(o);
          },
        ),
      );

      await client().putNoteStates({'version': 1, 'states': const []});

      expect(captured!['version'], 1);
    },
  );
}
