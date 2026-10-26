import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const String dbName = 'bloomwell_local.db';
  static const int dbVersion = 4;

  static final DatabaseHelper instance = DatabaseHelper._internal();
  DatabaseHelper._internal();

  Database? _database;

  // Allows injecting in-memory or custom database for tests
  DatabaseHelper.withDatabase(this._database);

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, dbName);

    return await openDatabase(
      path,
      version: dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _migrateUserProfileColumns(db);
      await _migrateWalkLogsColumns(db);
    }
    if (oldVersion < 3) {
      await _migrateDailyActivityTable(db);
    }
    if (oldVersion < 4) {
      await _migrateWakeAndCollegeTables(db);
    }
  }

  Future<void> _onOpen(Database db) async {
    await _migrateUserProfileColumns(db);
    await _migrateWalkLogsColumns(db);
    await _migrateDailyActivityTable(db);
    await _migrateWakeAndCollegeTables(db);
  }

  Future<void> _migrateWakeAndCollegeTables(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS college_schedules (
          date TEXT PRIMARY KEY,
          goingToCollege INTEGER NOT NULL DEFAULT 0,
          hasClasses INTEGER NOT NULL DEFAULT 0,
          collegeStartTime TEXT,
          collegeEndTime TEXT,
          classStartTime TEXT,
          classEndTime TEXT,
          updatedAt TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS wake_verifications (
          date TEXT PRIMARY KEY,
          verifiedAt TEXT NOT NULL,
          method TEXT NOT NULL DEFAULT 'selfie'
        )
      ''');

      // Migrate new collegeStartTime & collegeEndTime columns if missing
      final List<Map<String, dynamic>> cols = await db.rawQuery('PRAGMA table_info(college_schedules)');
      final colNames = cols.map((c) => c['name'] as String).toList();
      if (!colNames.contains('collegeStartTime')) {
        await db.execute('ALTER TABLE college_schedules ADD COLUMN collegeStartTime TEXT');
      }
      if (!colNames.contains('collegeEndTime')) {
        await db.execute('ALTER TABLE college_schedules ADD COLUMN collegeEndTime TEXT');
      }
    } catch (_) {
      // Tables or columns may already exist
    }
  }

  Future<void> _migrateDailyActivityTable(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS daily_activity_logs (
          date TEXT PRIMARY KEY,
          steps INTEGER NOT NULL DEFAULT 0,
          goal INTEGER NOT NULL DEFAULT 6000,
          distanceMeters REAL NOT NULL DEFAULT 0.0,
          activeMinutes INTEGER NOT NULL DEFAULT 0,
          estimatedCalories REAL NOT NULL DEFAULT 0.0,
          lastUpdatedAt TEXT NOT NULL
        )
      ''');
    } catch (_) {
      // Table may already exist
    }
  }

  Future<void> _migrateUserProfileColumns(Database db) async {
    try {
      final List<Map<String, dynamic>> columns =
          await db.rawQuery('PRAGMA table_info(user_profile)');
      final columnNames = columns.map((c) => c['name'] as String).toSet();

      if (columnNames.isNotEmpty) {
        if (!columnNames.contains('isOnboarded')) {
          await db.execute('ALTER TABLE user_profile ADD COLUMN isOnboarded INTEGER DEFAULT 0');
        }
        if (!columnNames.contains('name')) {
          await db.execute('ALTER TABLE user_profile ADD COLUMN name TEXT');
        }
        if (!columnNames.contains('weightUnit')) {
          await db.execute('ALTER TABLE user_profile ADD COLUMN weightUnit TEXT DEFAULT "kg"');
        }
        if (!columnNames.contains('heightUnit')) {
          await db.execute('ALTER TABLE user_profile ADD COLUMN heightUnit TEXT DEFAULT "cm"');
        }
        if (!columnNames.contains('pcodStatus')) {
          await db.execute('ALTER TABLE user_profile ADD COLUMN pcodStatus TEXT');
        }
        if (!columnNames.contains('pcosStatus')) {
          await db.execute('ALTER TABLE user_profile ADD COLUMN pcosStatus TEXT');
        }
        if (!columnNames.contains('healthGoal')) {
          await db.execute('ALTER TABLE user_profile ADD COLUMN healthGoal TEXT DEFAULT "both"');
        }
      }
    } catch (_) {
      // Table might not exist yet if onCreate hasn't run
    }
  }

  Future<void> _migrateWalkLogsColumns(Database db) async {
    try {
      final List<Map<String, dynamic>> columns =
          await db.rawQuery('PRAGMA table_info(walk_logs)');
      final columnNames = columns.map((c) => c['name'] as String).toSet();

      if (columnNames.isNotEmpty) {
        if (!columnNames.contains('activeDurationSeconds')) {
          await db.execute('ALTER TABLE walk_logs ADD COLUMN activeDurationSeconds INTEGER');
        }
        if (!columnNames.contains('elapsedAvgSpeedKmh')) {
          await db.execute('ALTER TABLE walk_logs ADD COLUMN elapsedAvgSpeedKmh REAL');
        }
      }
    } catch (_) {
      // Table might not exist yet
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. User Profile Table
    await db.execute('''
      CREATE TABLE user_profile (
        id INTEGER PRIMARY KEY,
        name TEXT,
        weightUnit TEXT DEFAULT 'kg',
        heightUnit TEXT DEFAULT 'cm',
        age INTEGER NOT NULL,
        heightCm REAL NOT NULL,
        currentWeightKg REAL NOT NULL,
        targetWeightKg REAL,
        dietaryPreference TEXT,
        allergies TEXT,
        hostelFacility TEXT,
        weeklyFoodBudget REAL,
        wakeUpTime TEXT,
        bedtime TEXT,
        waterReminderIntervalMinutes INTEGER,
        exerciseExperience TEXT,
        mobilityLimitations TEXT,
        pcodStatus TEXT,
        pcosStatus TEXT,
        healthGoal TEXT DEFAULT 'both',
        activityLevel TEXT,
        isHotClimate INTEGER,
        hasFluidRestriction INTEGER,
        isOnboarded INTEGER
      )
    ''');

    // 2. Water Logs Table
    await db.execute('''
      CREATE TABLE water_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amountMl INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        photoPath TEXT,
        notes TEXT,
        isPhotoVerified INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 3. Weight Entries Table
    await db.execute('''
      CREATE TABLE weight_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        weightKg REAL NOT NULL,
        timestamp TEXT NOT NULL,
        notes TEXT
      )
    ''');

    // 4. Meal Logs Table (tracked offline adherence / preparation)
    await db.execute('''
      CREATE TABLE meal_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mealId TEXT NOT NULL,
        mealType TEXT NOT NULL,
        consumedDate TEXT NOT NULL,
        wasPrepared INTEGER NOT NULL DEFAULT 1,
        notes TEXT
      )
    ''');

    // 5. Workout Logs Table
    await db.execute('''
      CREATE TABLE workout_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        exerciseId TEXT NOT NULL,
        exerciseName TEXT NOT NULL,
        completedAt TEXT NOT NULL,
        durationSeconds INTEGER NOT NULL,
        estimatedCalories REAL NOT NULL
      )
    ''');

    // 6. Walk / Run GPS Logs Table
    await db.execute('''
      CREATE TABLE walk_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        startTime TEXT NOT NULL,
        endTime TEXT NOT NULL,
        distanceMeters REAL NOT NULL,
        durationSeconds INTEGER NOT NULL,
        activeDurationSeconds INTEGER,
        avgSpeedKmh REAL NOT NULL,
        elapsedAvgSpeedKmh REAL,
        estimatedCalories REAL NOT NULL,
        notes TEXT
      )
    ''');

    // 7. Sleep Logs Table
    await db.execute('''
      CREATE TABLE sleep_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bedtime TEXT NOT NULL,
        wakeTime TEXT NOT NULL,
        durationMinutes INTEGER NOT NULL,
        notes TEXT
      )
    ''');

    // 8. Earned Badges Table
    await db.execute('''
      CREATE TABLE earned_badges (
        badgeId TEXT PRIMARY KEY,
        earnedAt TEXT NOT NULL,
        reason TEXT
      )
    ''');

    // 9. Daily Activity Logs Table (Automatic Step Tracker)
    await db.execute('''
      CREATE TABLE daily_activity_logs (
        date TEXT PRIMARY KEY,
        steps INTEGER NOT NULL DEFAULT 0,
        goal INTEGER NOT NULL DEFAULT 6000,
        distanceMeters REAL NOT NULL DEFAULT 0.0,
        activeMinutes INTEGER NOT NULL DEFAULT 0,
        estimatedCalories REAL NOT NULL DEFAULT 0.0,
        lastUpdatedAt TEXT NOT NULL
      )
    ''');

    // 10. College Schedules Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS college_schedules (
        date TEXT PRIMARY KEY,
        goingToCollege INTEGER NOT NULL DEFAULT 0,
        hasClasses INTEGER NOT NULL DEFAULT 0,
        collegeStartTime TEXT,
        collegeEndTime TEXT,
        classStartTime TEXT,
        classEndTime TEXT,
        updatedAt TEXT NOT NULL
      )
    ''');

    // 11. Wake Verifications Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS wake_verifications (
        date TEXT PRIMARY KEY,
        verifiedAt TEXT NOT NULL,
        method TEXT NOT NULL DEFAULT 'selfie'
      )
    ''');
  }

  /// Erase all local records and tables for privacy reset
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('user_profile');
    await db.delete('water_logs');
    await db.delete('weight_entries');
    await db.delete('meal_logs');
    await db.delete('workout_logs');
    await db.delete('walk_logs');
    await db.delete('sleep_logs');
    await db.delete('earned_badges');
    await db.delete('daily_activity_logs');
    await db.delete('college_schedules');
    await db.delete('wake_verifications');
  }

  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }
}
