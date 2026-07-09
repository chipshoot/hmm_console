import '../../domain/entities/auto_insurance_policy.dart';
import '../../domain/entities/auto_scheduled_service.dart';
import '../../domain/entities/coverage_item.dart';
import '../../domain/entities/line_item_type.dart';
import '../../domain/entities/part_item.dart';
import '../../domain/entities/service_record.dart';
import '../../domain/entities/service_type.dart';
import '../models/api_auto_insurance_policy.dart';
import '../models/api_auto_insurance_policy_for_create.dart';
import '../models/api_auto_insurance_policy_for_update.dart';
import '../models/api_auto_scheduled_service.dart';
import '../models/api_auto_scheduled_service_for_create.dart';
import '../models/api_auto_scheduled_service_for_update.dart';
import '../models/api_coverage_item.dart';
import '../models/api_part_item.dart';
import '../models/api_service_record.dart';
import '../models/api_service_record_for_create.dart';
import '../models/api_service_record_for_update.dart';

class AutomobileRecordsApiMapper {
  // ----- Insurance -----

  static AutoInsurancePolicy insuranceFromApi(ApiAutoInsurancePolicy api) {
    return AutoInsurancePolicy(
      id: api.id,
      automobileId: api.automobileId,
      provider: api.provider,
      policyNumber: api.policyNumber,
      effectiveDate: api.effectiveDate,
      expiryDate: api.expiryDate,
      premium: api.premium,
      currency: api.currency ?? 'CAD',
      deductible: api.deductible,
      coverage: api.coverage.map(_coverageFromApi).toList(),
      notes: api.notes,
      isActive: api.isActive,
      createdDate: api.createdDate,
      lastModifiedDate: api.lastModifiedDate,
    );
  }

  static ApiAutoInsurancePolicyForCreate insuranceToCreate(
      AutoInsurancePolicy p) {
    return ApiAutoInsurancePolicyForCreate(
      provider: p.provider,
      policyNumber: p.policyNumber,
      effectiveDate: p.effectiveDate,
      expiryDate: p.expiryDate,
      premium: p.premium,
      currency: p.currency,
      deductible: p.deductible,
      coverage: p.coverage.map(_coverageToApi).toList(),
      notes: p.notes,
      isActive: p.isActive,
    );
  }

  static ApiAutoInsurancePolicyForUpdate insuranceToUpdate(
      AutoInsurancePolicy p) {
    return ApiAutoInsurancePolicyForUpdate(
      provider: p.provider,
      policyNumber: p.policyNumber,
      effectiveDate: p.effectiveDate,
      expiryDate: p.expiryDate,
      premium: p.premium,
      currency: p.currency,
      deductible: p.deductible,
      coverage: p.coverage.map(_coverageToApi).toList(),
      notes: p.notes,
      isActive: p.isActive,
    );
  }

  static CoverageItem _coverageFromApi(ApiCoverageItem c) => CoverageItem(
        type: c.type,
        limit: c.limit,
        deductible: c.deductible,
        currency: c.currency ?? 'CAD',
      );

  static ApiCoverageItem _coverageToApi(CoverageItem c) => ApiCoverageItem(
        type: c.type,
        limit: c.limit,
        deductible: c.deductible,
        currency: c.currency,
      );

  // ----- Service record -----

  static ServiceRecord serviceFromApi(ApiServiceRecord api) {
    return ServiceRecord(
      id: api.id,
      automobileId: api.automobileId,
      date: api.date,
      mileage: api.mileage,
      type: ServiceType.fromWire(api.type),
      name: api.name,
      referenceNumber: api.referenceNumber,
      description: api.description,
      cost: api.cost,
      tax: api.tax,
      currency: api.currency ?? 'CAD',
      shopName: api.shopName,
      parts: api.parts.map(_partFromApi).toList(),
      notes: api.notes,
      createdDate: api.createdDate,
    );
  }

  static ApiServiceRecordForCreate serviceToCreate(ServiceRecord r) {
    return ApiServiceRecordForCreate(
      date: r.date,
      mileage: r.mileage,
      type: r.type.wireValue,
      name: r.name,
      referenceNumber: r.referenceNumber,
      description: r.description,
      cost: r.cost,
      tax: r.tax,
      currency: r.currency,
      shopName: r.shopName,
      parts: r.parts.map(_partToApi).toList(),
      notes: r.notes,
    );
  }

  static ApiServiceRecordForUpdate serviceToUpdate(ServiceRecord r) {
    return ApiServiceRecordForUpdate(
      date: r.date,
      mileage: r.mileage,
      type: r.type.wireValue,
      name: r.name,
      referenceNumber: r.referenceNumber,
      description: r.description,
      cost: r.cost,
      tax: r.tax,
      currency: r.currency,
      shopName: r.shopName,
      parts: r.parts.map(_partToApi).toList(),
      notes: r.notes,
    );
  }

  static PartItem _partFromApi(ApiPartItem p) => PartItem(
        type: LineItemType.fromWire(p.type),
        name: p.name,
        quantity: p.quantity,
        unitCost: p.unitCost,
        currency: p.currency ?? 'CAD',
      );

  static ApiPartItem _partToApi(PartItem p) => ApiPartItem(
        type: p.type.wireName,
        name: p.name,
        quantity: p.quantity,
        unitCost: p.unitCost,
        currency: p.currency,
      );

  // ----- Scheduled service -----

  static AutoScheduledService scheduleFromApi(ApiAutoScheduledService api) {
    return AutoScheduledService(
      id: api.id,
      automobileId: api.automobileId,
      name: api.name,
      type: ServiceType.fromWire(api.type),
      intervalDays: api.intervalDays,
      intervalMileage: api.intervalMileage,
      nextDueDate: api.nextDueDate,
      nextDueMileage: api.nextDueMileage,
      isActive: api.isActive,
      notes: api.notes,
      createdDate: api.createdDate,
      lastModifiedDate: api.lastModifiedDate,
    );
  }

  static ApiAutoScheduledServiceForCreate scheduleToCreate(
      AutoScheduledService s) {
    return ApiAutoScheduledServiceForCreate(
      name: s.name,
      type: s.type.wireValue,
      intervalDays: s.intervalDays,
      intervalMileage: s.intervalMileage,
      nextDueDate: s.nextDueDate,
      nextDueMileage: s.nextDueMileage,
      isActive: s.isActive,
      notes: s.notes,
    );
  }

  static ApiAutoScheduledServiceForUpdate scheduleToUpdate(
      AutoScheduledService s) {
    return ApiAutoScheduledServiceForUpdate(
      name: s.name,
      type: s.type.wireValue,
      intervalDays: s.intervalDays,
      intervalMileage: s.intervalMileage,
      nextDueDate: s.nextDueDate,
      nextDueMileage: s.nextDueMileage,
      isActive: s.isActive,
      notes: s.notes,
    );
  }
}
