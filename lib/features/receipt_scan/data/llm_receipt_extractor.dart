import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../../core/llm/contract/contract.dart';
import '../../../core/llm/llm_client.dart';
import '../domain/receipt_draft.dart';
import '../domain/receipt_extractor.dart';
import 'receipt_llm_schema.dart';

/// Reads a receipt through the user's own AI provider (the `receipts`
/// purpose of the LLM module). [LlmException]s propagate unchanged so the UI
/// can offer consent or a localized message.
class LlmReceiptExtractor implements ReceiptExtractor {
  LlmReceiptExtractor(
    this._client, {
    Future<Uint8List> Function(Uint8List)? compress,
  }) : _compress = compress ?? defaultReceiptCompress;

  final LlmClient _client;
  final Future<Uint8List> Function(Uint8List) _compress;

  @override
  Future<ReceiptDraft> extract(ReceiptInput input) async {
    // The client guards too; refusing here avoids compressing for nothing.
    if (input.sensitive) throw const LlmSensitiveRefused();
    final LlmPart part;
    if (input.isPdf) {
      part = DocumentPart(input.bytes);
    } else {
      part = ImagePart(await _compress(input.bytes), 'image/jpeg');
    }
    final response = await _client.complete(
      LlmRequest(
        system: receiptLlmPrompt,
        messages: [
          LlmMessage(role: LlmRole.user, parts: [part]),
        ],
        responseSchema: receiptLlmSchema,
        containsSensitive: input.sensitive,
        maxTokens: 4096,
      ),
      purpose: 'receipts',
    );
    final json = response.json;
    if (json == null) throw const LlmBadResponse('no json');
    return receiptDraftFromJson(
      Map<String, dynamic>.from(json),
      ReceiptExtractorMode.provider,
    );
  }
}

const _maxImageBytes = 4 * 1024 * 1024;

/// JPEG, long side at most 2000 px, quality stepped down from 85 by 15 to a
/// floor of 40 until the result is under 4 MB.
Future<Uint8List> defaultReceiptCompress(Uint8List bytes) async {
  var out = bytes;
  for (var q = 85; q >= 40; q -= 15) {
    out = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 2000,
      minHeight: 2000,
      quality: q,
      format: CompressFormat.jpeg,
    );
    if (out.length < _maxImageBytes) return out;
  }
  return out;
}
