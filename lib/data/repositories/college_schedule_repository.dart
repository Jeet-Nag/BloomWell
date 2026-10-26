import 'package:sqflite/sqflite.dart';
import '../../domain/models/college_schedule.dart';
import '../database/database_helper.dart';

class CollegeScheduleRepository {
  final DatabaseHelper dbHelper;

  CollegeScheduleRepository({DatabaseHelper? dbHelper})
      : dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<void> saveSchedule(CollegeSchedule schedule) async {
    final db = await dbHelper.database;
    await db.insert(
      'college_schedules',
      schedule.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<CollegeSchedule?> getScheduleForDate(String date) async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'college_schedules',
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return CollegeSchedule.fromMap(maps.first);
  }

  Future<void> deleteSchedule(String date) async {
    final db = await dbHelper.database;
    await db.delete(
      'college_schedules',
      where: 'date = ?',
      whereArgs: [date],
    );
  }
}
