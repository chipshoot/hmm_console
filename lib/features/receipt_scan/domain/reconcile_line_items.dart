import 'receipt_draft.dart';

/// A line item after reconciliation, plus whether it was changed.
class ReconciledItem {
  const ReconciledItem(this.item, {required this.adjusted});
  final ReceiptLineItem item;
  final bool adjusted;
}

/// Deterministically corrects one scanned line item from its printed [amount],
/// the authoritative signal (quantity x unitCost == amount). Total and
/// side-effect free: a line it cannot reconcile is returned unchanged with
/// [ReconciledItem.adjusted] == false.
ReconciledItem reconcileLineItem(ReceiptLineItem li) {
  final a = li.amount;
  final u = li.unitCost;
  final q = li.quantity;

  // Only a finite, positive printed total is a usable signal (skip
  // discounts/credits and any non-finite garbage so this stays total).
  if (a == null || !a.isFinite || a <= 0) {
    return ReconciledItem(li, adjusted: false);
  }

  final tol = a * 0.01 > 0.01 ? a * 0.01 : 0.01;

  // Fix quantity when a usable (finite, positive) unit price is known.
  if (u != null && u.isFinite && u > 0) {
    final derived = (a / u).round();
    final clean = (derived * u - a).abs() <= tol;
    if (derived >= 1 && clean && derived != q) {
      return ReconciledItem(
        ReceiptLineItem(
            type: li.type,
            name: li.name,
            quantity: derived,
            unitCost: u,
            amount: a),
        adjusted: true,
      );
    }
    return ReconciledItem(li, adjusted: false);
  }

  // Fill a missing/zero unit price from amount / quantity.
  if (q > 0) {
    return ReconciledItem(
      ReceiptLineItem(
          type: li.type,
          name: li.name,
          quantity: q,
          unitCost: a / q,
          amount: a),
      adjusted: true,
    );
  }

  return ReconciledItem(li, adjusted: false);
}
