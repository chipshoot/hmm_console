import 'service_type.dart';

/// Recurring / upcoming maintenance schedule for a vehicle. Drives the
/// `AutomobileInfo.NextServiceDueDate` snapshot on the backend. Mirrors
/// the `AutoScheduledService` note served from
/// `/v1/automobiles/{autoId}/scheduled-services`.
class AutoScheduledService {
  const AutoScheduledService({
    required this.id,
    required this.automobileId,
    required this.name,
    this.type = ServiceType.other,
    this.intervalDays,
    this.intervalMileage,
    this.nextDueDate,
    this.nextDueMileage,
    this.isActive = true,
    this.notes,
    this.createdDate,
    this.lastModifiedDate,
  });

  final int id;
  final int automobileId;
  final String name;
  final ServiceType type;
  final int? intervalDays;
  final int? intervalMileage;
  final DateTime? nextDueDate;
  final int? nextDueMileage;
  final bool isActive;
  final String? notes;
  final DateTime? createdDate;
  final DateTime? lastModifiedDate;
}
