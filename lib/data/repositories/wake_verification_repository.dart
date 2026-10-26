import 'package:sqflite/sqflite.dart';
import '../../domain/models/wake_verification.dart';
import '../database/database_helper.dart';

class WakeVerificationRepository {
  final DatabaseHelper dbHelper;

  WakeVerificationRepository({DatabaseHelper? dbHelper})
      : dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<void> saveVerification(WakeVerification verification) async {
    final db = await dbHelper.database;
    await db.insert(
      'wake_verifications',
      verification.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<WakeVerification?> getVerificationForDate(String date) async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'wake_verifications',
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return WakeVerification.fromMap(maps.first);
  }
}
