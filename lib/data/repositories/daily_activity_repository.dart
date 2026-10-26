import 'package:sqflite/sqflite.dart';
import '../../domain/models/daily_activity_log.dart';
import '../database/database_helper.dart';

class DailyActivityRepository {
  final DatabaseHelper dbHelper;

  DailyActivityRepository({DatabaseHelper? dbHelper})
      : dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<void> insertOrUpdate(DailyActivityLog log) async {
    final db = await dbHelper.database;
    final existing = await getLogForDate(log.date);
    if (existing == null) {
      await db.insert(
        'daily_activity_logs',
        log.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      // Idempotent upsert: preserve the maximum step count, distance, active minutes, and calories.
      // Never allow a zero or regressed total to overwrite legitimate activity.
      final int maxSteps = log.steps >= existing.steps ? log.steps : existing.steps;
      final double maxDist = log.distanceMeters >= existing.distanceMeters ? log.distanceMeters : existing.distanceMeters;
      final int maxActive = log.activeMinutes >= existing.activeMinutes ? log.activeMinutes : existing.activeMinutes;
      final double maxCal = log.estimatedCalories >= existing.estimatedCalories ? log.estimatedCalories : existing.estimatedCalories;
      final int finalGoal = log.goal > 0 ? log.goal : existing.goal;

      final mergedLog = DailyActivityLog(
        date: log.date,
        steps: maxSteps,
        goal: finalGoal,
        distanceMeters: maxDist,
        activeMinutes: maxActive,
        estimatedCalories: maxCal,
        lastUpdatedAt: log.lastUpdatedAt.isAfter(existing.lastUpdatedAt)
            ? log.lastUpdatedAt
            : existing.lastUpdatedAt,
      );

      await db.update(
        'daily_activity_logs',
        mergedLog.toMap(),
        where: 'date = ?',
        whereArgs: [log.date],
      );
    }
  }

  Future<DailyActivityLog?> getLogForDate(String date) async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'daily_activity_logs',
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return DailyActivityLog.fromMap(maps.first);
  }

  Future<List<DailyActivityLog>> getPastDaysLogs(int count) async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'daily_activity_logs',
      orderBy: 'date DESC',
      limit: count,
    );
    return maps.map((m) => DailyActivityLog.fromMap(m)).toList();
  }

  Future<List<DailyActivityLog>> getAllLogs() async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'daily_activity_logs',
      orderBy: 'date DESC',
    );
    return maps.map((m) => DailyActivityLog.fromMap(m)).toList();
  }
}
