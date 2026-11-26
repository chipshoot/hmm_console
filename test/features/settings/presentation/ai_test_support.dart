import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/llm/llm_dio.dart';
import 'package:hmm_console/core/llm/llm_key_store.dart';
import 'package:hmm_console/core/theme/theme.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory key store: no platform channel.
class FakeKeys extends LlmKeyStore {
  FakeKeys();
  final keys = <String, String>{};
  final consent = <String, String>{};

  @override
  Future<String?> readKey(String id) async => keys[id];
  @override
  Future<void> writeKey(String id, String key) async {
    final t = key.trim();
    if (t.isEmpty) {
      keys.remove(id);
    } else {
      keys[id] = t;
    }
  }

  @override
  Future<void> deleteKey(String id) async => keys.remove(id);
  @override
  Future<bool> hasKey(String id) async => keys[id]?.isNotEmpty ?? false;
  @override
  Future<bool> hasConsent(String id, String host) async =>
      consent[id] == host;
  @override
  Future<void> setConsent(String id, String host) async =>
      consent[id] = host;
  @override
  Future<void> deleteConsent(String id) async => consent.remove(id);
  @override
  Future<void> sweepOrphans(Set<String> liveIds) async {}
}

class RecordedRequest {
  RecordedRequest(this.method, this.uri, this.headers);
  final String method;
  final Uri uri;
  final Map<String, dynamic> headers;
}

/// Replies `status` with `body` to every request and records them.
class FakeHttp implements HttpClientAdapter {
  int status = 200;
  Object body = {'ok': true};
  final requests = <RecordedRequest>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(RecordedRequest(options.method, options.uri, options.headers));
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class AiHarness {
  AiHarness(this.keys, this.http, this.container);
  final FakeKeys keys;
  final FakeHttp http;
  final ProviderContainer container;
}

Future<AiHarness> pumpAi(
  WidgetTester t,
  Widget home, {
  Map<String, Object> prefs = const {},
  Map<String, String> savedKeys = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  // Tall enough that the whole edit form is built (lazy slivers).
  t.view.physicalSize = const Size(800, 3000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final keys = FakeKeys()..keys.addAll(savedKeys);
  final http = FakeHttp();
  final dio = Dio()..httpClientAdapter = http;
  final c = ProviderContainer(
    overrides: [
      llmKeyStoreProvider.overrideWithValue(keys),
      llmDioProvider.overrideWithValue(dio),
    ],
  );
  addTearDown(c.dispose);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        // The static theme caches its platform; follow the test override.
        theme: AppTheme.lightThemeData.copyWith(
          platform: defaultTargetPlatform,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
  await t.pumpAndSettle();
  return AiHarness(keys, http, c);
}

/// A widget test that runs as [platform] and always resets the override
/// before the framework checks its invariants.
void platformTest(
  String description,
  TargetPlatform platform,
  Future<void> Function(WidgetTester t) body,
) {
  testWidgets(description, (t) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body(t);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
