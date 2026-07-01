import '../domain/receipt_draft.dart';

/// Pure heuristic parser over OCR text. Fills the scalar fields it can find and
/// always returns a [ReceiptDraft] (never throws). Does not itemize — line
/// items are unreliable from raw OCR text, so [ReceiptDraft.lineItems] is empty.
class ReceiptTextParser {
  const ReceiptTextParser();

  static final _amount = RegExp(r'(\d+[.,]\d{2})');
  static final _isoDate = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})');
  static final _slashDate = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{2,4})');
  static final _taxLine =
      RegExp(r'\b(tax|gst|hst|vat|pst)\b', caseSensitive: false);
  static final _totalLine =
      RegExp(r'\b(total|amount due|balance)\b', caseSensitive: false);
  static final _subtotalLine =
      RegExp(r'\bsub\s*total\b', caseSensitive: false);

  ReceiptDraft parse(String text) {
    try {
      final lines = text
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      return ReceiptDraft(
        source: ReceiptExtractorMode.onDevice,
        rawText: text,
        shopName: lines.isEmpty ? null : lines.first,
        date: _findDate(text),
        tax: _lastAmountWhere(lines, (l) => _taxLine.hasMatch(l)),
        total: _lastAmountWhere(
          lines,
          (l) => _totalLine.hasMatch(l) && !_subtotalLine.hasMatch(l),
        ),
      );
    } catch (_) {
      return ReceiptDraft(source: ReceiptExtractorMode.onDevice, rawText: text);
    }
  }

  DateTime? _findDate(String text) {
    final iso = _isoDate.firstMatch(text);
    if (iso != null) {
      final d = _date(iso.group(1), iso.group(2), iso.group(3));
      if (d != null) return d;
    }
    final slash = _slashDate.firstMatch(text);
    if (slash != null) {
      // month/day/year
      var year = int.tryParse(slash.group(3) ?? '');
      if (year != null && year < 100) year += 2000;
      return _date(year?.toString(), slash.group(1), slash.group(2));
    }
    return null;
  }

  DateTime? _date(String? y, String? m, String? d) {
    final year = int.tryParse(y ?? '');
    final month = int.tryParse(m ?? '');
    final day = int.tryParse(d ?? '');
    if (year == null || month == null || day == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(year, month, day);
  }

  double? _lastAmountWhere(List<String> lines, bool Function(String) test) {
    double? found;
    for (final line in lines) {
      if (!test(line)) continue;
      final amt = _amountIn(line);
      if (amt != null) found = amt;
    }
    return found;
  }

  double? _amountIn(String line) {
    final m = _amount.firstMatch(line);
    if (m == null) return null;
    return double.tryParse(m.group(1)!.replaceAll(',', '.'));
  }
}
