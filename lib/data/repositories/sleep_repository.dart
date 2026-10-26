import '../../domain/models/sleep_log.dart';
import '../database/database_helper.dart';

class SleepRepository {
  final DatabaseHelper dbHelper;

  SleepRepository({DatabaseHelper? dbHelper})
      : dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<int> insertSleepLog(SleepLog log) async {
    final db = await dbHelper.database;
    return await db.insert('sleep_logs', log.toMap());
  }

  Future<List<SleepLog>> getAllSleepLogs() async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sleep_logs',
      orderBy: 'wakeTime DESC',
    );
    return maps.map((m) => SleepLog.fromMap(m)).toList();
  }

  Future<SleepLog?> getLatestSleepLog() async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sleep_logs',
      orderBy: 'wakeTime DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return SleepLog.fromMap(maps.first);
  }
}
