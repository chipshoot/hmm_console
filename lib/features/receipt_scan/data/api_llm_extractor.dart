import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../automobile_records/domain/entities/line_item_type.dart';
import '../domain/receipt_draft.dart';
import '../domain/receipt_extractor.dart';

/// Cloud extractor: uploads the receipt to `POST /v1/receipts/extract` (which
/// runs Claude vision) and parses the structured JSON back into a
/// [ReceiptDraft]. Used when the user selects the Cloud AI extractor mode.
class ApiLlmExtractor implements ReceiptExtractor {
  ApiLlmExtractor(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<ReceiptDraft> extract(ReceiptInput input) async {
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          input.bytes,
          filename: input.isPdf ? 'receipt.pdf' : 'receipt.jpg',
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

      final data = response.data;
      if (data is! Map) {
        throw const ReceiptExtractionException(
            'Unexpected response from the receipt service.');
      }
      return _fromJson(Map<String, dynamic>.from(data));
    } on ReceiptExtractionException {
      rethrow;
    } on DioException catch (e) {
      throw ReceiptExtractionException(_messageFor(e));
    } catch (e) {
      throw ReceiptExtractionException('Receipt extraction failed: $e');
    }
  }

  ReceiptDraft _fromJson(Map<String, dynamic> j) {
    final items = (j['lineItems'] as List?) ?? const [];
    final date = j['date'] as String?;
    return ReceiptDraft(
      source: ReceiptExtractorMode.cloudAi,
      shopName: j['shopName'] as String?,
      date: date != null ? DateTime.tryParse(date) : null,
      odometer: (j['odometer'] as num?)?.toInt(),
      tax: (j['tax'] as num?)?.toDouble(),
      total: (j['total'] as num?)?.toDouble(),
      currency: j['currency'] as String?,
      lineItems: [
        for (final it in items)
          if (it is Map)
            ReceiptLineItem(
              type: LineItemType.fromWire(it['type'] as String?),
              name: (it['name'] as String?) ?? '',
              quantity: (it['quantity'] as num?)?.toInt() ?? 1,
              unitCost: (it['unitCost'] as num?)?.toDouble(),
            ),
      ],
    );
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
}
