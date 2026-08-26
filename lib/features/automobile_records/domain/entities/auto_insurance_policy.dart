import '../../../../core/contact_block/contact_info.dart';
import '../../../../core/data/attachments/attachment_ref.dart';
import 'coverage_item.dart';

/// Auto insurance policy attached to a vehicle. Mirrors the backend
/// `AutoInsurancePolicy` note entity served from
/// `/v1/automobiles/{autoId}/insurance-policies`.
class AutoInsurancePolicy {
  AutoInsurancePolicy({
    required this.id,
    required this.automobileId,
    required this.provider,
    required this.policyNumber,
    required this.effectiveDate,
    required this.expiryDate,
    required this.premium,
    this.currency = 'CAD',
    this.deductible,
    this.coverage = const [],
    this.notes,
    this.isActive = true,
    this.createdDate,
    this.lastModifiedDate,
    this.contacts = const [],
    NoteAttachments? attachments,
  }) : attachments = attachments ?? NoteAttachments.empty;

  final int id;
  final int automobileId;
  final String provider;
  final String policyNumber;
  final DateTime effectiveDate;
  final DateTime expiryDate;
  final double premium;
  final String currency;
  final double? deductible;
  final List<CoverageItem> coverage;
  final String? notes;
  final bool isActive;
  final DateTime? createdDate;
  final DateTime? lastModifiedDate;

  /// Embedded contact blocks - typically the agent, but a policy may carry a
  /// claims line too. Shares the shape, editor and renderer used elsewhere; see
  /// `lib/core/contact_block/`. Not a reference to a contact record: these
  /// travel with the policy and are deleted with it.
  final List<ContactInfo> contacts;

  /// Read-through projection of the owning note's attachments column, same as
  /// `ServiceRecord`. local/cloudStorage only - the API has no attachment
  /// support for policies.
  final NoteAttachments attachments;

  bool get isCurrentlyActive {
    final now = DateTime.now().toUtc();
    return isActive &&
        effectiveDate.isBefore(now.add(const Duration(milliseconds: 1))) &&
        expiryDate.isAfter(now);
  }
}
