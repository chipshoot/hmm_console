class ApiAutoScheduledService {
  const ApiAutoScheduledService({
    required this.id,
    required this.automobileId,
    required this.name,
    this.type = 'Other',
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
  final String type;
  final int? intervalDays;
  final int? intervalMileage;
  final DateTime? nextDueDate;
  final int? nextDueMileage;
  final bool isActive;
  final String? notes;
  final DateTime? createdDate;
  final DateTime? lastModifiedDate;

  factory ApiAutoScheduledService.fromJson(Map<String, dynamic> json) {
    return ApiAutoScheduledService(
      id: json['id'] as int,
      automobileId: json['automobileId'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'Other',
      intervalDays: json['intervalDays'] as int?,
      intervalMileage: json['intervalMileage'] as int?,
      nextDueDate: json['nextDueDate'] != null
          ? DateTime.parse(json['nextDueDate'] as String)
          : null,
      nextDueMileage: json['nextDueMileage'] as int?,
      isActive: json['isActive'] as bool? ?? true,
      notes: json['notes'] as String?,
      createdDate: json['createdDate'] != null
          ? DateTime.parse(json['createdDate'] as String)
          : null,
      lastModifiedDate: json['lastModifiedDate'] != null
          ? DateTime.parse(json['lastModifiedDate'] as String)
          : null,
    );
  }
}
