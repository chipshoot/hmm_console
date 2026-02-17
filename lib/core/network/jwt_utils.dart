import 'dart:convert';

Map<String, dynamic> decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) {
    throw FormatException('Invalid JWT token');
  }

  final payload = parts[1];
  final normalized = base64Url.normalize(payload);
  final decoded = utf8.decode(base64Url.decode(normalized));
  return json.decode(decoded) as Map<String, dynamic>;
}
