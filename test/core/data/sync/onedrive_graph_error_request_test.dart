// A Graph 400 said only "invalidRequest: Invalid request" — Graph's generic
// rejection, which names neither the reason nor the request. The failing
// request had to be reconstructed from source. The exception must carry the
// request it came from, so the next report answers "what was sent?" itself.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/sync/onedrive_graph_client.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'onedrive_test_fakes.dart';

void main() {
  const manifestPath =
      '/me/drive/special/approot:/users/SUB-1/manifest.json:/content';

  late Dio dio;
  late DioAdapter adapter;

  setUp(() {
    dio = Dio(BaseOptions(
      baseUrl: 'https://graph.microsoft.com/v1.0',
      validateStatus: (_) => true,
    ));
    adapter = DioAdapter(dio: dio);
  });

  OneDriveGraphClient client() =>
      OneDriveGraphClient(FakeOneDriveAuth(), () async => 'SUB-1', dio: dio);

  test('a rejected request names its method and URL', () async {
    adapter.onGet(
      manifestPath,
      (server) => server.reply(400, {
        'error': {'code': 'invalidRequest', 'message': 'Invalid request.'},
      }),
    );

    final error = await client()
        .getManifest()
        .then<Object?>((_) => null, onError: (Object e) => e);

    expect(error, isA<OneDriveGraphException>());
    final graphError = error! as OneDriveGraphException;
    expect(graphError.request,
        'GET https://graph.microsoft.com/v1.0$manifestPath');
    // The text the user copies off the sync card is toString(), so the
    // request must be in it — alongside Graph's body, not instead of it.
    expect(graphError.toString(), contains(graphError.request!));
    expect(graphError.toString(), contains('invalidRequest'));
  });

  test('an exception raised before any request names none', () {
    const e = OneDriveGraphException(statusCode: 401, message: 'Not signed in');
    expect(e.request, isNull);
    expect(e.toString(), 'OneDriveGraphException(401): Not signed in');
  });
}
