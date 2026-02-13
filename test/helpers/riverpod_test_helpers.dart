import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Creates a [ProviderContainer] and registers a teardown to dispose it
/// after the test. Pass overrides inline to the returned container.
ProviderContainer createContainer() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

/// Wraps a widget in [ProviderScope] and [MaterialApp] for widget testing.
Widget createTestApp({required Widget child}) {
  return ProviderScope(
    child: MaterialApp(home: child),
  );
}
