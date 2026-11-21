import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Generate an RFC 4122 v4 UUID using `Random.secure()`.
///
/// Stable cross-device record identity for sync — see the "Add UUIDs" note in
/// `docs/task_plan.md`. Kept inline rather than adding the `uuid` package
/// because v4 generation is ~10 lines.
String generateUuid() {
  final rand = Random.secure();
  final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
  bytes[6] = (bytes[6] & 0x0F) | 0x40; // Version 4
  bytes[8] = (bytes[8] & 0x3F) | 0x80; // Variant 1 (RFC 4122)
  String h(int i) => bytes[i].toRadixString(16).padLeft(2, '0');
  return '${h(0)}${h(1)}${h(2)}${h(3)}-'
      '${h(4)}${h(5)}-'
      '${h(6)}${h(7)}-'
      '${h(8)}${h(9)}-'
      '${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
}

/// RFC 4122 §4.3 name-based UUID (version 5, SHA-1). [namespace] is a
/// hyphenated UUID; [name] is hashed as UTF-8. Returns lowercase hyphenated.
String uuidV5(String namespace, String name) {
  final hex = namespace.replaceAll('-', '');
  final ns = <int>[
    for (var i = 0; i < 32; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ];
  final digest = sha1.convert([...ns, ...utf8.encode(name)]).bytes;
  final bytes = List<int>.from(digest.take(16));
  bytes[6] = (bytes[6] & 0x0F) | 0x50; // Version 5
  bytes[8] = (bytes[8] & 0x3F) | 0x80; // Variant 1
  String h(int i) => bytes[i].toRadixString(16).padLeft(2, '0');
  return '${h(0)}${h(1)}${h(2)}${h(3)}-'
      '${h(4)}${h(5)}-'
      '${h(6)}${h(7)}-'
      '${h(8)}${h(9)}-'
      '${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
}
