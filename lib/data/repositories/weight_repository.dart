import '../../domain/models/weight_entry.dart';
import '../database/database_helper.dart';

class WeightRepository {
  final DatabaseHelper dbHelper;

  WeightRepository({DatabaseHelper? dbHelper})
      : dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<int> insertEntry(WeightEntry entry) async {
    final db = await dbHelper.database;
    return await db.insert('weight_entries', entry.toMap());
  }

  Future<List<WeightEntry>> getAllEntries() async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'weight_entries',
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => WeightEntry.fromMap(m)).toList();
  }

  Future<WeightEntry?> getLatestEntry() async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'weight_entries',
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return WeightEntry.fromMap(maps.first);
  }

  Future<void> deleteEntry(int id) async {
    final db = await dbHelper.database;
    await db.delete('weight_entries', where: 'id = ?', whereArgs: [id]);
  }
}
