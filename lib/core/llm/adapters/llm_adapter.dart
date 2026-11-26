import 'package:dio/dio.dart';

import '../contract/contract.dart';
import '../engines/llm_engine.dart';

/// Translates the provider-neutral contract to one provider wire format.
/// Adapters throw only [LlmException]s. With a response schema they return
/// the raw JSON text in [LlmResponse.text] and leave `json` null; the client
/// validates it.
abstract interface class LlmAdapter {
  WireFormat get format;

  Future<LlmResponse> complete(
    LlmEngine engine,
    String? key,
    LlmRequest request, {
    required String model,
    CancelToken? cancel,
  });

  Stream<LlmEvent> stream(
    LlmEngine engine,
    String? key,
    LlmRequest request, {
    required String model,
    CancelToken? cancel,
  });
}

/// Joins [base] and [path] with exactly one slash between them.
Uri joinUrl(String base, String path) {
  final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  final p = path.startsWith('/') ? path.substring(1) : path;
  return Uri.parse('$b/$p');
}
