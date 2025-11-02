import 'package:hive/hive.dart';
import '../../domain/entities/gas_log.dart';
import '../model/gas_log_record.dart';
import '../mappers/gas_log_mapper.dart';
import 'i_gas_log_repository.dart';

class GasLogHiveRepository implements IGasLogRepository {
  static const String _boxName = 'gasLogs';

  Box<GasLogRecord> get _box => Hive.box<GasLogRecord>(_boxName);

  /// Initialize the Hive box
  static Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<GasLogRecord>(_boxName);
    }
  }

  @override
  Future<List<GasLog>> getGasLogs() async {
    try {
      // Get all gas log records and convert to domain models
      final records = _box.values.toList();
      records.sort((a, b) => b.date.compareTo(a.date));
      return GasLogMapper.fromRecordList(records);
    } catch (e) {
      throw Exception('Failed to get gas logs: $e');
    }
  }

  @override
  Future<GasLog> getGasLog(String id) async {
    try {
      // Use the ID as the key for a direct, efficient lookup
      final gasLogRecord = _box.get(id);
      if (gasLogRecord == null) {
        throw Exception('Gas log with id $id not found');
      }
      return GasLogMapper.fromRecord(gasLogRecord);
    } catch (e) {
      throw Exception('Failed to get gas log: $e');
    }
  }

  @override
  Future<GasLog> finGasLogByDate(DateTime date) async {
    try {
      // Find gas log record by exact date match and convert to domain model
      final gasLogRecord = _box.values.firstWhere(
        (record) => _isSameDay(record.date, date),
        orElse: () => throw Exception(
          'Gas log for date ${date.toIso8601String()} not found',
        ),
      );
      return GasLogMapper.fromRecord(gasLogRecord);
    } catch (e) {
      throw Exception('Failed to find gas log by date: $e');
    }
  }

  @override
  Future<String> saveGasLog(GasLog gasLog) async {
    try {
      // If the gas log has no ID, generate one. Otherwise, use the existing one
      final id = gasLog.id?.isNotEmpty == true ? gasLog.id! : _generateId();

      // Create a new GasLog instance with the definitive ID
      final gasLogWithId = gasLog.copyWith(id: id);

      // Convert to a Hive record and save it using the ID as the key
      // This handles both creating new records and updating existing ones
      final recordToSave = GasLogMapper.toRecord(gasLogWithId);

      // Ensure the record has the same ID as the key for consistency
      final finalRecord = recordToSave.copyWith(id: id);
      await _box.put(id, finalRecord);

      return id;
    } catch (e) {
      throw Exception('Failed to save gas log: $e');
    }
  }

  @override
  Future<bool> deleteGasLog(String id) async {
    try {
      // Use the ID as the key for a direct, efficient deletion
      if (!_box.containsKey(id)) {
        return false; // Record not found
      }
      await _box.delete(id);
      return true;
    } catch (e) {
      throw Exception('Failed to delete gas log: $e');
    }
  }

  /// Additional utility methods

  /// Get gas logs within a date range
  Future<List<GasLog>> getGasLogsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final records = _box.values.where((record) {
        return record.date.isAfter(
              startDate.subtract(const Duration(days: 1)),
            ) &&
            record.date.isBefore(endDate.add(const Duration(days: 1)));
      }).toList();

      records.sort((a, b) => b.date.compareTo(a.date));
      return GasLogMapper.fromRecordList(records);
    } catch (e) {
      throw Exception('Failed to get gas logs by date range: $e');
    }
  }

  /// Get total count of gas logs
  int getGasLogsCount() {
    return _box.length;
  }

  /// Get gas logs for current month
  Future<List<GasLog>> getCurrentMonthGasLogs() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    return getGasLogsByDateRange(startOfMonth, endOfMonth);
  }

  /// Clear all gas logs (use with caution)
  Future<void> clearAllGasLogs() async {
    try {
      await _box.clear();
    } catch (e) {
      throw Exception('Failed to clear all gas logs: $e');
    }
  }

  /// Helper methods

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// Close the box (call when app is closing)
  static Future<void> dispose() async {
    if (Hive.isBoxOpen(_boxName)) {
      await Hive.box<GasLogRecord>(_boxName).close();
    }
  }
}
