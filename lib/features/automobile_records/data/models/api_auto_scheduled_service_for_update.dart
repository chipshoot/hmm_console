class ApiAutoScheduledServiceForUpdate {
  const ApiAutoScheduledServiceForUpdate({
    this.name,
    this.type,
    this.intervalDays,
    this.intervalMileage,
    this.nextDueDate,
    this.nextDueMileage,
    this.isActive,
    this.notes,
  });

  final String? name;
  final String? type;
  final int? intervalDays;
  final int? intervalMileage;
  final DateTime? nextDueDate;
  final int? nextDueMileage;
  final bool? isActive;
  final String? notes;

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (type != null) 'type': type,
        if (intervalDays != null) 'intervalDays': intervalDays,
        if (intervalMileage != null) 'intervalMileage': intervalMileage,
        if (nextDueDate != null)
          'nextDueDate': nextDueDate!.toUtc().toIso8601String(),
        if (nextDueMileage != null) 'nextDueMileage': nextDueMileage,
        if (isActive != null) 'isActive': isActive,
        if (notes != null) 'notes': notes,
      };
}
