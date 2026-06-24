import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hmm_console/core/data/sync/onedrive_auth.dart';

/// Shared fakes for OneDrive Graph/provider tests — an auth that always has a
/// token, backed by an in-memory secure storage.
class FakeOneDriveAuth extends OneDriveAuth {
  FakeOneDriveAuth() : super(storage: NoopSecureStorage());

  @override
  Future<String?> getAccessToken() async => 'test-token';

  @override
  Future<bool> hasToken() async => true;
}

class NoopSecureStorage extends FlutterSecureStorage {
  NoopSecureStorage() : super();
  final _data = <String, String?>{};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data[key] = value;
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }
}
