import 'package:sqflite/sqflite.dart';
import '../../domain/models/user_profile.dart';
import '../database/database_helper.dart';

class UserRepository {
  final DatabaseHelper dbHelper;

  UserRepository({DatabaseHelper? dbHelper})
      : dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<UserProfile?> getProfile() async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'user_profile',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return UserProfile.fromMap(maps.first);
  }

  Future<void> saveProfile(UserProfile profile) async {
    final db = await dbHelper.database;
    final map = profile.toMap()..['id'] = 1;
    await db.insert(
      'user_profile',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteProfile() async {
    final db = await dbHelper.database;
    await db.delete('user_profile');
  }
}
