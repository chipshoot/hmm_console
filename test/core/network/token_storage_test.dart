import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_token_storage.dart';

void main() {
  late MockTokenStorage storage;

  setUp(() {
    storage = MockTokenStorage();
  });

  group('TokenStorage', () {
    test('save and retrieve tokens', () async {
      final expiry = DateTime.now().add(const Duration(hours: 1));
      await storage.saveTokens(
        accessToken: 'access_123',
        refreshToken: 'refresh_456',
        expiry: expiry,
      );

      expect(await storage.getAccessToken(), 'access_123');
      expect(await storage.getRefreshToken(), 'refresh_456');
      expect(await storage.getExpiry(), expiry);
    });

    test('clearTokens removes all tokens', () async {
      await storage.saveTokens(
        accessToken: 'access_123',
        refreshToken: 'refresh_456',
        expiry: DateTime.now().add(const Duration(hours: 1)),
      );

      await storage.clearTokens();

      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
      expect(await storage.getExpiry(), isNull);
    });

    test('hasValidToken returns false when no token', () async {
      expect(await storage.hasValidToken(), isFalse);
    });

    test('hasValidToken returns true for non-expired token', () async {
      await storage.saveTokens(
        accessToken: 'access_123',
        refreshToken: 'refresh_456',
        expiry: DateTime.now().add(const Duration(hours: 1)),
      );

      expect(await storage.hasValidToken(), isTrue);
    });

    test('hasValidToken returns false when token expires within 60s', () async {
      await storage.saveTokens(
        accessToken: 'access_123',
        refreshToken: 'refresh_456',
        expiry: DateTime.now().add(const Duration(seconds: 30)),
      );

      expect(await storage.hasValidToken(), isFalse);
    });

    test('hasValidToken returns false for expired token', () async {
      await storage.saveTokens(
        accessToken: 'access_123',
        refreshToken: 'refresh_456',
        expiry: DateTime.now().subtract(const Duration(hours: 1)),
      );

      expect(await storage.hasValidToken(), isFalse);
    });
  });
}
