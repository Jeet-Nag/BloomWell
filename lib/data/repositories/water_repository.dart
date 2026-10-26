import '../../domain/models/water_log.dart';
import '../database/database_helper.dart';

class WaterRepository {
  final DatabaseHelper dbHelper;

  WaterRepository({DatabaseHelper? dbHelper})
      : dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<int> insertLog(WaterLog log) async {
    final db = await dbHelper.database;
    return await db.insert('water_logs', log.toMap());
  }

  Future<List<WaterLog>> getLogsForDate(DateTime date) async {
    final db = await dbHelper.database;
    final startOfDay = DateTime(date.year, date.month, date.day).toIso8601String();
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();

    final List<Map<String, dynamic>> maps = await db.query(
      'water_logs',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [startOfDay, endOfDay],
      orderBy: 'timestamp DESC',
    );
    return maps.map((m) => WaterLog.fromMap(m)).toList();
  }

  Future<int> getTotalMlForDate(DateTime date) async {
    final logs = await getLogsForDate(date);
    return logs.fold<int>(0, (sum, item) => sum + item.amountMl);
  }

  Future<WaterLog?> getLastLog() async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'water_logs',
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return WaterLog.fromMap(maps.first);
  }

  Future<List<WaterLog>> getAllLogs() async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'water_logs',
      orderBy: 'timestamp DESC',
    );
    return maps.map((m) => WaterLog.fromMap(m)).toList();
  }

  Future<void> deleteLog(int id) async {
    final db = await dbHelper.database;
    await db.delete('water_logs', where: 'id = ?', whereArgs: [id]);
  }
}
