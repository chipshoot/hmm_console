import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The device's region (ISO alpha-2, e.g. `CN`), or null when the locale has
/// none. Seeds the country code of a NEW phone row; overridden in tests.
final deviceRegionProvider = Provider<String?>(
  (ref) => PlatformDispatcher.instance.locale.countryCode,
);
