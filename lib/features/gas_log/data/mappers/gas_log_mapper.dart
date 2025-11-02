import '../../domain/entities/gas_log.dart';
import '../../data/model/gas_log_record.dart';

/// Mapper class to convert between domain model (GasLog) and data model (GasLogRecord)
class GasLogMapper {
  /// Convert from domain model (GasLog) to data model (GasLogRecord)
  static GasLogRecord toRecord(GasLog gasLog) {
    // Ensure the ID is non-nullable. If it's null, this indicates a new record
    // that hasn't been saved yet. The repository will assign a new ID.
    // However, to satisfy the non-nullable requirement of GasLogRecord,
    // we must provide a valid string. An empty string can signify a new record.
    return GasLogRecord(
      id: gasLog.id ?? '', // Provide a non-null ID
      odometer: gasLog.odometer,
      distance: gasLog.distance,
      gas: gasLog.gas,
      price: gasLog.price,
      date: gasLog.date,
      gasStation: gasLog.gasStation ?? '',
      comment: gasLog.comment ?? '',
    );
  }

  /// Convert from data model (GasLogRecord) to domain model (GasLog)
  static GasLog fromRecord(GasLogRecord record) {
    return GasLog(
      id: record.id,
      odometer: record.odometer,
      distance: record.distance,
      gas: record.gas,
      price: record.price,
      date: record.date,
      gasStation: record.gasStation?.isEmpty == true ? null : record.gasStation,
      comment: record.comment?.isEmpty == true ? null : record.comment,
    );
  }

  /// Convert list of domain models to data models
  static List<GasLogRecord> toRecordList(List<GasLog> gasLogs) {
    return gasLogs.map((gasLog) => toRecord(gasLog)).toList();
  }

  /// Convert list of data models to domain models
  static List<GasLog> fromRecordList(List<GasLogRecord> records) {
    return records.map((record) => fromRecord(record)).toList();
  }

  /// Create a new GasLog from parameters (for UI)
  static GasLog createNewGasLog({
    required String odometer,
    required double distance,
    required double gas,
    required double price,
    required DateTime date,
    String? gasStation,
    String? comment,
  }) {
    return GasLog(
      id: null, // Will be generated when saved
      odometer: odometer,
      distance: distance,
      gas: gas,
      price: price,
      date: date,
      gasStation: gasStation,
      comment: comment,
    );
  }
}
