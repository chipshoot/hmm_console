// The router's auth stream must start from the real session check (which
// refreshes an expired access token) and report a session the IdP ended.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/network/idp_token_service.dart';
import 'package:hmm_console/features/auth/data/data/auth_data_source.dart';


class _FakeIdp implements IdpTokenService {
  _FakeIdp(this.result);
  final SessionCheck result;
  final ended = StreamController<void>.broadcast();

  @override
  Future<SessionCheck> checkSession({
    Duration timeout = const Duration(seconds: 5),
  }) async =>
      result;

  @override
  Stream<void> get sessionEnded => ended.stream;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<List<bool>> _states(_FakeIdp idp, {Future<void> Function()? then}) async {
  final container = ProviderContainer(
    overrides: [
      idpTokenServiceProvider.overrideWithValue(idp),
    ],
  );
  addTearDown(container.dispose);
  final seen = <bool>[];
  final sub = container
      .read(authRemoteDataSource)
      .isUserAuthenticated()
      .listen(seen.add);
  addTearDown(sub.cancel);
  await pumpEventQueue();
  await then?.call();
  await pumpEventQueue();
  return seen;
}

void main() {
  test('starts signed in after a successful refresh', () async {
    expect(await _states(_FakeIdp(SessionCheck.signedIn)), [true]);
  });

  test('starts signed in when offline with a stored session', () async {
    expect(await _states(_FakeIdp(SessionCheck.offline)), [true]);
  });

  test('starts signed out when the check says so', () async {
    expect(await _states(_FakeIdp(SessionCheck.signedOut)), [false]);
  });

  test('a session the IdP ends is reported as signed out', () async {
    final idp = _FakeIdp(SessionCheck.signedIn);
    expect(
      await _states(idp, then: () async => idp.ended.add(null)),
      [true, false],
    );
  });
}
