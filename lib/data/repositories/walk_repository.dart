import '../../domain/models/walk_session.dart';
import '../database/database_helper.dart';

class WalkRepository {
  final DatabaseHelper dbHelper;

  WalkRepository({DatabaseHelper? dbHelper})
      : dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<int> insertWalkSession(WalkSession session) async {
    final db = await dbHelper.database;
    return await db.insert('walk_logs', session.toMap());
  }

  Future<List<WalkSession>> getAllWalkSessions() async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'walk_logs',
      orderBy: 'startTime DESC',
    );
    return maps.map((m) => WalkSession.fromMap(m)).toList();
  }

  Future<List<WalkSession>> getWalkSessionsForDate(DateTime date) async {
    final db = await dbHelper.database;
    final startOfDay = DateTime(date.year, date.month, date.day).toIso8601String();
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();

    final List<Map<String, dynamic>> maps = await db.query(
      'walk_logs',
      where: 'startTime >= ? AND startTime <= ?',
      whereArgs: [startOfDay, endOfDay],
      orderBy: 'startTime DESC',
    );
    return maps.map((m) => WalkSession.fromMap(m)).toList();
  }
}
