import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../automobile_records/domain/entities/line_item_type.dart';
import '../domain/receipt_draft.dart';
import '../domain/receipt_extractor.dart';

/// Cloud extractor: uploads the receipt to `POST /v1/receipts/extract` (which
/// runs Claude vision) and parses the structured draft back into a
/// [ReceiptDraft]. Used when the user selects the Cloud AI extractor mode.
///
/// Parsing is deliberately tolerant — a mistyped or missing field degrades to
/// null rather than discarding the whole draft (best-effort is the point).
class ApiLlmExtractor implements ReceiptExtractor {
  ApiLlmExtractor(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<ReceiptDraft> extract(ReceiptInput input) async {
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          input.bytes,
          filename: _filenameFor(input.contentType),
          contentType: DioMediaType.parse(input.contentType),
        ),
      });

      final response = await _apiClient.dio.post(
        '/receipts/extract',
        data: form,
        // LLM extraction is slower than a normal API call — override the
        // client's default 15s receive timeout.
        options: Options(receiveTimeout: const Duration(seconds: 60)),
      );

      return _fromJson(_asMap(response.data));
    } on ReceiptExtractionException {
      rethrow;
    } on DioException catch (e) {
      throw ReceiptExtractionException(_messageFor(e));
    } catch (_) {
      // Keep internal error detail out of the user-facing message.
      throw const ReceiptExtractionException(
          'Could not read the receipt. Please try again.');
    }
  }

  /// Accepts a decoded Map, or a JSON string body (the shared client only
  /// auto-decodes when the response is tagged `application/json`).
  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String && data.trim().isNotEmpty) {
      final decoded = jsonDecode(data);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    throw const ReceiptExtractionException(
        'Unexpected response from the receipt service.');
  }

  ReceiptDraft _fromJson(Map<String, dynamic> j) {
    final rawItems = j['lineItems'];
    final items = rawItems is List ? rawItems : const [];
    final date = _asString(j['date']);
    return ReceiptDraft(
      source: ReceiptExtractorMode.cloudAi,
      shopName: _asString(j['shopName']),
      date: date != null ? DateTime.tryParse(date) : null,
      odometer: _asNum(j['odometer'])?.toInt(),
      tax: _asNum(j['tax'])?.toDouble(),
      total: _asNum(j['total'])?.toDouble(),
      currency: _asString(j['currency']),
      lineItems: [
        for (final it in items)
          if (it is Map)
            ReceiptLineItem(
              type: LineItemType.fromWire(_asString(it['type'])),
              name: _asString(it['name']) ?? '',
              quantity: _asNum(it['quantity'])?.toInt() ?? 1,
              unitCost: _asNum(it['unitCost'])?.toDouble(),
            ),
      ],
    );
  }

  String _filenameFor(String contentType) {
    final ext = switch (contentType) {
      'image/png' => 'png',
      'image/heic' => 'heic',
      'image/webp' => 'webp',
      'application/pdf' => 'pdf',
      _ => 'jpg',
    };
    return 'receipt.$ext';
  }

  String _messageFor(DioException e) {
    final data = e.response?.data;
    if (data is Map &&
        data['errors'] is List &&
        (data['errors'] as List).isNotEmpty) {
      return (data['errors'] as List).first.toString();
    }
    return 'Could not reach the receipt extraction service.';
  }

  static String? _asString(dynamic v) => v is String ? v : null;

  static num? _asNum(dynamic v) => v is num ? v : null;
}
