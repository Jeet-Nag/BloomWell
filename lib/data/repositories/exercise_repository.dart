import 'dart:convert';
import 'package:flutter/services.dart';
import '../../domain/models/exercise_item.dart';
import '../database/database_helper.dart';

class ExerciseRepository {
  final DatabaseHelper dbHelper;
  List<ExerciseItem>? _cachedExercises;

  ExerciseRepository({DatabaseHelper? dbHelper})
      : dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<List<ExerciseItem>> loadAllExercises() async {
    if (_cachedExercises != null) return _cachedExercises!;

    final jsonString = await rootBundle.loadString('assets/data/exercises.json');
    final List dynamicList = jsonDecode(jsonString) as List;
    _cachedExercises = dynamicList
        .map((item) => ExerciseItem.fromJson(item as Map<String, dynamic>))
        .toList();
    return _cachedExercises!;
  }

  Future<List<ExerciseItem>> getExercisesByCategory(String category) async {
    final all = await loadAllExercises();
    if (category == 'all') return all;
    return all.where((e) => e.category == category).toList();
  }

  Future<int> insertWorkoutLog(WorkoutLog log) async {
    final db = await dbHelper.database;
    return await db.insert('workout_logs', log.toMap());
  }

  Future<List<WorkoutLog>> getAllWorkoutLogs() async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'workout_logs',
      orderBy: 'completedAt DESC',
    );
    return maps.map((m) => WorkoutLog.fromMap(m)).toList();
  }

  Future<List<WorkoutLog>> getWorkoutLogsForDate(DateTime date) async {
    final db = await dbHelper.database;
    final startOfDay = DateTime(date.year, date.month, date.day).toIso8601String();
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();

    final List<Map<String, dynamic>> maps = await db.query(
      'workout_logs',
      where: 'completedAt >= ? AND completedAt <= ?',
      whereArgs: [startOfDay, endOfDay],
      orderBy: 'completedAt DESC',
    );
    return maps.map((m) => WorkoutLog.fromMap(m)).toList();
  }
}
