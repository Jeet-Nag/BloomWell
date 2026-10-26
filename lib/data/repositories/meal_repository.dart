import '../../domain/models/meal_item.dart';
import '../datasources/weekly_menu_data.dart';
import '../database/database_helper.dart';

class MealRepository {
  final DatabaseHelper dbHelper;

  MealRepository({DatabaseHelper? dbHelper})
      : dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<List<MealItem>> loadAllMeals() async {
    return WeeklyMenuData.getAllMealItems();
  }

  Future<List<MealItem>> getMealsForDay(
    int dayOfWeek, {
    String? hostelFacility,
    String? budgetTier,
  }) async {
    return WeeklyMenuData.getMealItemsForDay(dayOfWeek);
  }

  Future<void> markMealPrepared(String mealId, String mealType, DateTime date) async {
    final db = await dbHelper.database;
    final dateStr = date.toIso8601String().split('T').first;
    await db.insert('meal_logs', {
      'mealId': mealId,
      'mealType': mealType,
      'consumedDate': dateStr,
      'wasPrepared': 1,
    });
  }

  Future<List<String>> getPreparedMealIdsForDate(DateTime date) async {
    final db = await dbHelper.database;
    final dateStr = date.toIso8601String().split('T').first;
    final List<Map<String, dynamic>> maps = await db.query(
      'meal_logs',
      where: 'consumedDate = ?',
      whereArgs: [dateStr],
    );
    return maps.map((m) => m['mealId'] as String).toList();
  }
}
