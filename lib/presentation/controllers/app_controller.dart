import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/user_repository.dart';
import '../../data/repositories/water_repository.dart';
import '../../data/repositories/weight_repository.dart';
import '../../data/repositories/meal_repository.dart';
import '../../data/repositories/exercise_repository.dart';
import '../../data/repositories/walk_repository.dart';
import '../../data/repositories/daily_activity_repository.dart';
import '../../data/repositories/sleep_repository.dart';
import '../../data/repositories/badge_repository.dart';
import '../../data/repositories/college_schedule_repository.dart';
import '../../data/repositories/wake_verification_repository.dart';
import '../../data/database/database_helper.dart';

import '../../domain/models/user_profile.dart';
import '../../domain/models/water_log.dart';
import '../../domain/models/weight_entry.dart';
import '../../domain/models/meal_item.dart';
import '../../domain/models/exercise_item.dart';
import '../../domain/models/walk_session.dart';
import '../../domain/models/daily_activity_log.dart';
import '../../domain/models/sleep_log.dart';
import '../../domain/models/badge_item.dart';
import '../../domain/models/college_schedule.dart';
import '../../domain/models/wake_verification.dart';

import '../../domain/calculators/water_target_calculator.dart';
import '../../domain/calculators/weight_metrics_calculator.dart';
import '../../domain/calculators/streak_calculator.dart';
import '../../services/notification_service.dart';
import '../../services/pedometer_service.dart';
import '../../services/device_info_service.dart';
import '../../services/native_alarm_service.dart';

class AppController extends ChangeNotifier {
  static const String prefOnboardingCompleted = 'bloomwell_onboarding_completed';
  static const String prefNextReminderIso = 'bloomwell_next_water_reminder_at';
  static const String prefReminderInterval = 'bloomwell_water_reminder_interval';

  final UserRepository userRepo;
  final WaterRepository waterRepo;
  final WeightRepository weightRepo;
  final MealRepository mealRepo;
  final ExerciseRepository exerciseRepo;
  final WalkRepository walkRepo;
  final DailyActivityRepository dailyActivityRepo;
  final SleepRepository sleepRepo;
  final BadgeRepository badgeRepo;
  final CollegeScheduleRepository collegeScheduleRepo;
  final WakeVerificationRepository wakeVerificationRepo;
  final NotificationService notificationService;
  final PedometerService pedometerService;
  final DeviceInfoService deviceInfoService;
  final NativeAlarmService nativeAlarmService;

  AppController({
    UserRepository? userRepo,
    WaterRepository? waterRepo,
    WeightRepository? weightRepo,
    MealRepository? mealRepo,
    ExerciseRepository? exerciseRepo,
    WalkRepository? walkRepo,
    DailyActivityRepository? dailyActivityRepo,
    SleepRepository? sleepRepo,
    BadgeRepository? badgeRepo,
    CollegeScheduleRepository? collegeScheduleRepo,
    WakeVerificationRepository? wakeVerificationRepo,
    NotificationService? notificationService,
    PedometerService? pedometerService,
    DeviceInfoService? deviceInfoService,
    NativeAlarmService? nativeAlarmService,
  })  : userRepo = userRepo ?? UserRepository(),
        waterRepo = waterRepo ?? WaterRepository(),
        weightRepo = weightRepo ?? WeightRepository(),
        mealRepo = mealRepo ?? MealRepository(),
        exerciseRepo = exerciseRepo ?? ExerciseRepository(),
        walkRepo = walkRepo ?? WalkRepository(),
        dailyActivityRepo = dailyActivityRepo ?? DailyActivityRepository(),
        sleepRepo = sleepRepo ?? SleepRepository(),
        badgeRepo = badgeRepo ?? BadgeRepository(),
        collegeScheduleRepo = collegeScheduleRepo ?? CollegeScheduleRepository(),
        wakeVerificationRepo = wakeVerificationRepo ?? WakeVerificationRepository(),
        notificationService = notificationService ?? NotificationService.instance,
        pedometerService = pedometerService ?? PedometerService.instance,
        deviceInfoService = deviceInfoService ?? DeviceInfoService.instance,
        nativeAlarmService = nativeAlarmService ?? NativeAlarmService.instance;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isOnboarded = false;
  bool get isOnboarded => _isOnboarded;

  String _language = 'en';
  String get language => _language;

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  UserProfile? _profile;
  UserProfile? get profile => _profile;

  // Water State
  List<WaterLog> _todayWaterLogs = [];
  List<WaterLog> get todayWaterLogs => _todayWaterLogs;

  int _waterConsumedToday = 0;
  int get waterConsumedToday => _waterConsumedToday;

  int _waterTargetToday = 2000;
  int get waterTargetToday => _waterTargetToday;

  DateTime? _lastDrinkTime;
  DateTime? get lastDrinkTime => _lastDrinkTime;

  DateTime? _nextWaterReminderTime;
  DateTime? get nextWaterReminderTime => _nextWaterReminderTime;

  String _waterReminderState = 'COMPLETED'; // 'SCHEDULED', 'RINGING', 'AWAITING_CONFIRMATION', 'COMPLETED'
  String get waterReminderState => _waterReminderState;

  String? _activeReminderId;
  String? get activeReminderId => _activeReminderId;

  Timer? _countdownTicker;
  int _secondsUntilNextReminder = 0;
  int get secondsUntilNextReminder => _secondsUntilNextReminder;

  // Weight State
  List<WeightEntry> _weightEntries = [];
  List<WeightEntry> get weightEntries => _weightEntries;

  WeightSummary? _weightSummary;
  WeightSummary? get weightSummary => _weightSummary;

  // Meals State
  List<MealItem> _todayMeals = [];
  List<MealItem> get todayMeals => _todayMeals;

  List<String> _preparedMealIds = [];
  List<String> get preparedMealIds => _preparedMealIds;

  // Exercise & Walk State
  List<ExerciseItem> _exercises = [];
  List<ExerciseItem> get exercises => _exercises;

  List<WorkoutLog> _recentWorkouts = [];
  List<WorkoutLog> get recentWorkouts => _recentWorkouts;

  List<WalkSession> _walkSessions = [];
  List<WalkSession> get walkSessions => _walkSessions;

  // Daily Activity State (Automatic Pedometer Step Tracker)
  DailyActivityLog? _todayActivity;
  DailyActivityLog? get todayActivity => _todayActivity;

  List<DailyActivityLog> _weeklyActivityLogs = [];
  List<DailyActivityLog> get weeklyActivityLogs => _weeklyActivityLogs;

  // Sleep State
  SleepLog? _latestSleepLog;
  SleepLog? get latestSleepLog => _latestSleepLog;

  // College Schedule & Wake Verification State
  CollegeSchedule? _todayCollegeSchedule;
  CollegeSchedule? get todayCollegeSchedule => _todayCollegeSchedule;

  WakeVerification? _todayWakeVerification;
  WakeVerification? get todayWakeVerification => _todayWakeVerification;

  bool _canScheduleExactAlarms = true;
  bool get canScheduleExactAlarms => _canScheduleExactAlarms;

  // Badges & Streaks
  List<BadgeItem> _badges = [];
  List<BadgeItem> get badges => _badges;

  int _streakDays = 0;
  int get streakDays => _streakDays;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _language = prefs.getString('bloomwell_lang') ?? 'en';
      _isDarkMode = prefs.getBool('bloomwell_dark_mode') ?? false;

      // Load Profile
      _profile = await userRepo.getProfile();

      // Check onboarding state from both preferences and profile
      final bool prefsOnboarded = prefs.getBool(prefOnboardingCompleted) ?? false;
      final bool profileOnboarded = _profile != null &&
          (_profile!.isOnboarded || (_profile!.age > 0 && _profile!.currentWeightKg > 0));

      if (prefsOnboarded || profileOnboarded) {
        _isOnboarded = true;
        // Keep both storage locations synchronized
        if (!prefsOnboarded) {
          await prefs.setBool(prefOnboardingCompleted, true);
        }
        if (_profile != null && !_profile!.isOnboarded) {
          _profile = _profile!.copyWith(isOnboarded: true);
          await userRepo.saveProfile(_profile!);
        }
      } else {
        _isOnboarded = false;
      }

      // Recalculate water target
      if (_profile != null) {
        _waterTargetToday = WaterTargetCalculator.calculateDailyTargetMl(
          weightKg: _profile!.currentWeightKg,
          age: _profile!.age,
          activityLevel: _profile!.activityLevel,
          isHotClimate: _profile!.isHotClimate,
          hasFluidRestriction: _profile!.hasFluidRestriction,
        );
      }

      // Initialize native alarm service channel & listeners
      nativeAlarmService.initialize();
      nativeAlarmService.onWaterLoggedStream.listen((_) async {
        await _refreshWaterData();
        notifyListeners();
      });
      nativeAlarmService.onWaterReminderTriggeredStream.listen((reminderId) {
        _waterReminderState = 'AWAITING_CONFIRMATION';
        _activeReminderId = reminderId;
        _secondsUntilNextReminder = 0;
        _countdownTicker?.cancel();
        notifyListeners();
      });

      _canScheduleExactAlarms = await nativeAlarmService.canScheduleExactAlarms();

      await _refreshWaterData();
      await _refreshWeightData();
      await _refreshMealData();
      await _refreshExerciseData();
      await _refreshWalkData();
      await _refreshDailyActivityData();
      await _refreshSleepData();
      await _refreshBadgesAndStreak();
      await _refreshCollegeScheduleData();
      await _refreshWakeVerificationData();

      // Initialize automatic hardware step tracker
      await pedometerService.initialize(
        activityRepo: dailyActivityRepo,
        userHeightCm: _profile?.heightCm,
        userWeightKg: _profile?.currentWeightKg,
      );

      pedometerService.todayStepsStream.listen((_) async {
        await _refreshDailyActivityData();
        notifyListeners();
      });

      // Load device hardware details for adaptive battery guidance
      await deviceInfoService.loadDeviceDetails();

      // Restore water reminder deadline from persistent storage ONLY if onboarded
      if (_isOnboarded && _profile != null) {
        await _restoreWaterReminderDeadline(prefs);
      }
    } catch (e) {
      debugPrint('Initialization error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bloomwell_lang', lang);
    notifyListeners();
  }

  Future<void> toggleDarkMode(bool isDark) async {
    _isDarkMode = isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bloomwell_dark_mode', isDark);
    notifyListeners();
  }

  Future<void> saveProfile(UserProfile profile) async {
    final updatedProfile = profile.copyWith(isOnboarded: true);
    _profile = updatedProfile;
    _isOnboarded = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefOnboardingCompleted, true);
    await prefs.setInt(prefReminderInterval, updatedProfile.waterReminderIntervalMinutes);
    await userRepo.saveProfile(updatedProfile);

    _waterTargetToday = WaterTargetCalculator.calculateDailyTargetMl(
      weightKg: updatedProfile.currentWeightKg,
      age: updatedProfile.age,
      activityLevel: updatedProfile.activityLevel,
      isHotClimate: updatedProfile.isHotClimate,
      hasFluidRestriction: updatedProfile.hasFluidRestriction,
    );

    pedometerService.updateUserProfile(
      heightCm: updatedProfile.heightCm,
      weightKg: updatedProfile.currentWeightKg,
    );

    // If first time recording weight, create initial weight entry
    if (_weightEntries.isEmpty && updatedProfile.currentWeightKg > 0) {
      await weightRepo.insertEntry(WeightEntry(
        weightKg: updatedProfile.currentWeightKg,
        timestamp: DateTime.now(),
        notes: 'Baseline recorded during onboarding',
      ));
      await badgeRepo.awardBadge('badge_first_weight_check');
      await _refreshWeightData();
    }

    // Schedule daily wake-up alarm matching wakeUpTime
    // Schedule exact wake alarm and sync sleep schedule
    try {
      final parts = updatedProfile.wakeUpTime.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]) ?? 7;
        final minute = int.tryParse(parts[1]) ?? 0;
        await notificationService.scheduleDailyWakeAlarm(
          hour: hour,
          minute: minute,
          title: 'BloomWell Wake-Up',
          body: 'Good morning! Begin your day with gentle hydration and mindful nourishment.',
        );
        // Also schedule exact wake alarm via NativeAlarmService
        await nativeAlarmService.scheduleWakeAlarm(hour: hour, minute: minute);
      }
      await nativeAlarmService.setSleepSchedule(
        bedtime: updatedProfile.bedtime,
        wakeUpTime: updatedProfile.wakeUpTime,
      );
    } catch (_) {}

    // Reschedule water reminder if interval changed or updated
    final intervalMinutes = updatedProfile.waterReminderIntervalMinutes;
    final deadline = DateTime.now().add(Duration(minutes: intervalMinutes));
    await _persistAndScheduleReminder(deadline, isSnooze: false);

    await _refreshMealData();
    notifyListeners();
  }

  static bool isTimeInSleepWindow(DateTime dt, String bedtimeStr, String wakeTimeStr) {
    try {
      final bedParts = bedtimeStr.split(':');
      final wakeParts = wakeTimeStr.split(':');
      final bedMins = int.parse(bedParts[0]) * 60 + int.parse(bedParts[1]);
      final wakeMins = int.parse(wakeParts[0]) * 60 + int.parse(wakeParts[1]);
      final dtMins = dt.hour * 60 + dt.minute;

      if (bedMins <= wakeMins) {
        return dtMins >= bedMins && dtMins < wakeMins;
      } else {
        return dtMins >= bedMins || dtMins < wakeMins;
      }
    } catch (_) {
      return false;
    }
  }

  static bool isTimeInInterval(int targetMinutes, String? startStr, String? endStr) {
    if (startStr == null || endStr == null || startStr.isEmpty || endStr.isEmpty) return false;
    try {
      final startParts = startStr.split(':');
      final endParts = endStr.split(':');
      final start = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
      final end = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

      if (start <= end) {
        return targetMinutes >= start && targetMinutes < end;
      } else {
        return targetMinutes >= start || targetMinutes < end;
      }
    } catch (_) {
      return false;
    }
  }

  static DateTime calculateNextAwakeWaterTime({
    required DateTime candidate,
    required String bedtimeStr,
    required String wakeTimeStr,
  }) {
    return calculateNextUnsuppressedWaterTime(
      candidate: candidate,
      bedtimeStr: bedtimeStr,
      wakeTimeStr: wakeTimeStr,
    );
  }

  static DateTime calculateNextUnsuppressedWaterTime({
    required DateTime candidate,
    required String bedtimeStr,
    required String wakeTimeStr,
    CollegeSchedule? collegeSchedule,
  }) {
    var target = candidate;
    int attempts = 0;

    while (attempts < 10) {
      attempts++;
      // 1. Check sleep window
      if (isTimeInSleepWindow(target, bedtimeStr, wakeTimeStr)) {
        try {
          final wakeParts = wakeTimeStr.split(':');
          final wakeHour = int.parse(wakeParts[0]);
          final wakeMinute = int.parse(wakeParts[1]);
          var wakeTarget = DateTime(target.year, target.month, target.day, wakeHour, wakeMinute);
          if (!wakeTarget.isAfter(target)) {
            wakeTarget = wakeTarget.add(const Duration(days: 1));
          }
          target = wakeTarget;
          continue;
        } catch (_) {}
      }

      // 2. Check college/class schedule suppression if applicable on candidate's date
      if (collegeSchedule != null) {
        final targetDateStr =
            "${target.year.toString().padLeft(4, '0')}-${target.month.toString().padLeft(2, '0')}-${target.day.toString().padLeft(2, '0')}";
        if (collegeSchedule.date == targetDateStr) {
          final targetMinutes = target.hour * 60 + target.minute;
          int latestEndMinutes = -1;

          // Check College interval independently
          if (collegeSchedule.goingToCollege &&
              collegeSchedule.collegeStartTime != null &&
              collegeSchedule.collegeEndTime != null) {
            if (isTimeInInterval(targetMinutes, collegeSchedule.collegeStartTime, collegeSchedule.collegeEndTime)) {
              final parts = collegeSchedule.collegeEndTime!.split(':');
              final endM = int.parse(parts[0]) * 60 + int.parse(parts[1]);
              if (endM > latestEndMinutes) latestEndMinutes = endM;
            }
          }

          // Check Classes interval independently
          if (collegeSchedule.hasClasses &&
              collegeSchedule.classStartTime != null &&
              collegeSchedule.classEndTime != null) {
            if (isTimeInInterval(targetMinutes, collegeSchedule.classStartTime, collegeSchedule.classEndTime)) {
              final parts = collegeSchedule.classEndTime!.split(':');
              final endM = int.parse(parts[0]) * 60 + int.parse(parts[1]);
              if (endM > latestEndMinutes) latestEndMinutes = endM;
            }
          }

          if (latestEndMinutes > 0) {
            target = DateTime(
              target.year,
              target.month,
              target.day,
              latestEndMinutes ~/ 60,
              latestEndMinutes % 60,
            );
            continue;
          }
        }
      }

      break;
    }

    return target;
  }

  // --- Water Operations ---
  Future<void> _refreshWaterData() async {
    final now = DateTime.now();
    _todayWaterLogs = await waterRepo.getLogsForDate(now);
    _waterConsumedToday = _todayWaterLogs.fold(0, (sum, l) => sum + l.amountMl);

    final lastLog = await waterRepo.getLastLog();
    _lastDrinkTime = lastLog?.timestamp;
  }

  Future<bool> confirmWaterDrink({
    required int amountMl,
    String? photoPath,
    String? notes,
    required bool isPhotoVerified,
    String? reminderId,
  }) async {
    if (amountMl <= 0 || photoPath == null || photoPath.isEmpty) {
      return false;
    }

    final now = DateTime.now();
    final log = WaterLog(
      amountMl: amountMl,
      timestamp: now,
      photoPath: photoPath,
      notes: notes,
      isPhotoVerified: isPhotoVerified,
    );

    try {
      // 1. Persist water log and photo reference to SQLite
      await waterRepo.insertLog(log);
      await _refreshWaterData();

      // Award badges
      await badgeRepo.awardBadge('badge_first_sip');
      if (_waterConsumedToday >= _waterTargetToday) {
        await badgeRepo.awardBadge('badge_hydration_hero_1d');
      }
      await _refreshBadgesAndStreak();

      // 2. Only after SQLite write succeeds: resolve current reminder instance
      final rId = reminderId ?? _activeReminderId;
      _waterReminderState = 'COMPLETED';
      _activeReminderId = null;

      final intervalMinutes = _profile?.waterReminderIntervalMinutes ?? 30;
      final candidateDeadline = now.add(Duration(minutes: intervalMinutes));
      final bedtime = _profile?.bedtime ?? '23:00';
      final wakeTime = _profile?.wakeUpTime ?? '07:00';
      final effectiveDeadline = calculateNextUnsuppressedWaterTime(
        candidate: candidateDeadline,
        bedtimeStr: bedtime,
        wakeTimeStr: wakeTime,
        collegeSchedule: _todayCollegeSchedule,
      );

      _nextWaterReminderTime = effectiveDeadline;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefNextReminderIso, effectiveDeadline.toIso8601String());
      await prefs.setString('flutter.water_reminder_state', 'COMPLETED');
      await prefs.remove('flutter.water_reminder_id');

      final diffSeconds = effectiveDeadline.difference(DateTime.now()).inSeconds;
      _secondsUntilNextReminder = diffSeconds > 0 ? diffSeconds : 0;

      // 3. Complete reminder on native side: stop exact audio session, dismiss notification, and schedule next alarm
      await nativeAlarmService.completeWaterReminder(
        reminderId: rId,
        nextDeadline: effectiveDeadline,
        intervalMinutes: intervalMinutes,
      );

      if (_secondsUntilNextReminder > 0) {
        _startOrUpdateCountdownTicker();
      } else {
        _countdownTicker?.cancel();
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error confirming water drink: $e');
      // DB write failed: retain pending confirmation state and return false for retry
      return false;
    }
  }

  Future<void> skipReminder() async {
    await nativeAlarmService.stopAlarmSound(reminderId: _activeReminderId);
    _waterReminderState = 'COMPLETED';
    _activeReminderId = null;

    final intervalMinutes = _profile?.waterReminderIntervalMinutes ?? 30;
    final deadline = DateTime.now().add(Duration(minutes: intervalMinutes));
    await _persistAndScheduleReminder(deadline, isSnooze: false);
  }

  Future<void> _persistAndScheduleReminder(DateTime deadline, {bool isSnooze = false, String? reminderId}) async {
    final bedtime = _profile?.bedtime ?? '23:00';
    final wakeTime = _profile?.wakeUpTime ?? '07:00';
    final effectiveDeadline = calculateNextUnsuppressedWaterTime(
      candidate: deadline,
      bedtimeStr: bedtime,
      wakeTimeStr: wakeTime,
      collegeSchedule: _todayCollegeSchedule,
    );

    _nextWaterReminderTime = effectiveDeadline;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefNextReminderIso, effectiveDeadline.toIso8601String());

    final diffSeconds = effectiveDeadline.difference(DateTime.now()).inSeconds;
    _secondsUntilNextReminder = diffSeconds > 0 ? diffSeconds : 0;

    final intervalMinutes = _profile?.waterReminderIntervalMinutes ?? 30;

    // Schedule exact native AlarmManager reminder for locked-screen / background reliability
    try {
      await nativeAlarmService.scheduleWaterReminder(
        deadline: effectiveDeadline,
        intervalMinutes: intervalMinutes,
        reminderId: reminderId,
      );
    } catch (e) {
      debugPrint('Error scheduling native water alarm: $e');
    }

    if (_secondsUntilNextReminder > 0) {
      _startOrUpdateCountdownTicker();
    } else {
      _countdownTicker?.cancel();
    }
    notifyListeners();
  }

  Future<void> _restoreWaterReminderDeadline(SharedPreferences prefs) async {
    final pending = await nativeAlarmService.getPendingWaterReminder();
    final nativeState = pending?['state'] as String?;
    final nativeReminderId = pending?['reminderId'] as String?;

    if (nativeState == 'AWAITING_CONFIRMATION' || nativeState == 'RINGING') {
      _waterReminderState = nativeState!;
      _activeReminderId = nativeReminderId;
      _secondsUntilNextReminder = 0;
      _countdownTicker?.cancel();
      notifyListeners();
      return;
    }

    final savedIso = prefs.getString(prefNextReminderIso);
    if (savedIso != null && savedIso.isNotEmpty) {
      final parsed = DateTime.tryParse(savedIso);
      if (parsed != null && parsed.isAfter(DateTime.now())) {
        _nextWaterReminderTime = parsed;
        final diff = parsed.difference(DateTime.now()).inSeconds;
        _secondsUntilNextReminder = diff > 0 ? diff : 0;
        if (diff > 0) {
          _startOrUpdateCountdownTicker();
        } else {
          _countdownTicker?.cancel();
        }
        return;
      }
    }

    // Default to profile interval from now if no valid deadline saved
    final intervalMinutes = _profile?.waterReminderIntervalMinutes ?? 30;
    final deadline = DateTime.now().add(Duration(minutes: intervalMinutes));
    await _persistAndScheduleReminder(deadline, isSnooze: false);
  }

  void _startOrUpdateCountdownTicker() {
    _countdownTicker?.cancel();
    if (_nextWaterReminderTime == null) return;

    final initialDiff = _nextWaterReminderTime!.difference(DateTime.now()).inSeconds;
    _secondsUntilNextReminder = initialDiff > 0 ? initialDiff : 0;

    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_nextWaterReminderTime == null) {
        timer.cancel();
        return;
      }
      final remaining = _nextWaterReminderTime!.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        _secondsUntilNextReminder = 0;
        timer.cancel();
        notifyListeners();
      } else {
        _secondsUntilNextReminder = remaining;
        notifyListeners();
      }
    });
  }

  void syncReminderWithCurrentTime() async {
    final pending = await nativeAlarmService.getPendingWaterReminder();
    final nativeState = pending?['state'] as String?;
    final nativeReminderId = pending?['reminderId'] as String?;

    if (nativeState == 'AWAITING_CONFIRMATION' || nativeState == 'RINGING') {
      _waterReminderState = nativeState!;
      _activeReminderId = nativeReminderId;
      _secondsUntilNextReminder = 0;
      _countdownTicker?.cancel();
      notifyListeners();
      return;
    }

    if (_nextWaterReminderTime != null) {
      final remaining = _nextWaterReminderTime!.difference(DateTime.now()).inSeconds;
      _secondsUntilNextReminder = remaining > 0 ? remaining : 0;
      if (remaining > 0) {
        _startOrUpdateCountdownTicker();
      } else {
        _countdownTicker?.cancel();
      }
      notifyListeners();
    }
  }

  Future<void> deleteWaterLog(int id) async {
    await waterRepo.deleteLog(id);
    await _refreshWaterData();
    notifyListeners();
  }

  // --- Weight Operations ---
  Future<void> _refreshWeightData() async {
    _weightEntries = await weightRepo.getAllEntries();
    _weightSummary = WeightMetricsCalculator.computeSummary(_weightEntries);
  }

  Future<void> recordWeight(double weightKg, {String? notes}) async {
    final entry = WeightEntry(
      weightKg: weightKg,
      timestamp: DateTime.now(),
      notes: notes,
    );
    await weightRepo.insertEntry(entry);

    if (_profile != null) {
      await saveProfile(_profile!.copyWith(currentWeightKg: weightKg));
    }

    await badgeRepo.awardBadge('badge_first_weight_check');
    if (_weightEntries.length >= 2) {
      await badgeRepo.awardBadge('badge_15day_checkin_complete');
    }

    await _refreshWeightData();
    await _refreshBadgesAndStreak();
    notifyListeners();
  }

  // --- Meals Operations ---
  Future<void> _refreshMealData() async {
    final now = DateTime.now();
    // Monday is 1, Sunday is 7
    final dayOfWeek = now.weekday;
    final hostel = _profile?.hostelFacility ?? 'mess';

    _todayMeals = await mealRepo.getMealsForDay(dayOfWeek, hostelFacility: hostel);
    _preparedMealIds = await mealRepo.getPreparedMealIdsForDate(now);
  }

  Future<void> markMealPrepared(String mealId, String mealType) async {
    await mealRepo.markMealPrepared(mealId, mealType, DateTime.now());
    await badgeRepo.awardBadge('badge_first_meal_plan');
    await _refreshMealData();
    await _refreshBadgesAndStreak();
    notifyListeners();
  }

  // --- Exercise & Walk Operations ---
  Future<void> _refreshExerciseData() async {
    _exercises = await exerciseRepo.loadAllExercises();
    _recentWorkouts = await exerciseRepo.getAllWorkoutLogs();
  }

  Future<void> _refreshWalkData() async {
    _walkSessions = await walkRepo.getAllWalkSessions();
  }

  Future<void> recordWorkout(String exerciseId, String exerciseName, int durationSeconds, double estimatedCalories) async {
    final log = WorkoutLog(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      completedAt: DateTime.now(),
      durationSeconds: durationSeconds,
      estimatedCalories: estimatedCalories,
    );
    await exerciseRepo.insertWorkoutLog(log);
    await badgeRepo.awardBadge('badge_first_move');
    await _refreshExerciseData();
    await _refreshBadgesAndStreak();
    notifyListeners();
  }

  Future<void> recordWalkSession(WalkSession session) async {
    await walkRepo.insertWalkSession(session);
    await badgeRepo.awardBadge('badge_first_walk');
    await _refreshWalkData();
    await _refreshBadgesAndStreak();
    notifyListeners();
  }

  // --- Daily Activity & Pedometer Operations ---
  Future<void> _refreshDailyActivityData() async {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _todayActivity = await dailyActivityRepo.getLogForDate(today);
    _weeklyActivityLogs = await dailyActivityRepo.getPastDaysLogs(7);
  }

  Future<void> setDailyStepGoal(int goal) async {
    await pedometerService.setDailyGoal(goal);
    await _refreshDailyActivityData();
    notifyListeners();
  }

  Future<bool> requestActivityPermission() async {
    final granted = await pedometerService.requestPermission();
    await _refreshDailyActivityData();
    notifyListeners();
    return granted;
  }

  /// Reconciles sensor data, background steps, and date rollover whenever the app is resumed
  Future<void> reconcileActivityDataOnResume() async {
    await pedometerService.reconcileOnResume();
    await _refreshDailyActivityData();
    await _refreshWaterData();
    await _refreshCollegeScheduleData();
    await _refreshWakeVerificationData();
    _canScheduleExactAlarms = await nativeAlarmService.canScheduleExactAlarms();
    syncReminderWithCurrentTime();
    notifyListeners();
  }

  // --- College Schedule Operations ---
  Future<void> _refreshCollegeScheduleData() async {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _todayCollegeSchedule = await collegeScheduleRepo.getScheduleForDate(today);
  }

  Future<void> recordCollegeSchedule({
    required bool goingToCollege,
    required bool hasClasses,
    String? collegeStartTime,
    String? collegeEndTime,
    String? classStartTime,
    String? classEndTime,
  }) async {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final schedule = CollegeSchedule(
      date: today,
      goingToCollege: goingToCollege,
      hasClasses: hasClasses,
      collegeStartTime: collegeStartTime,
      collegeEndTime: collegeEndTime,
      classStartTime: classStartTime,
      classEndTime: classEndTime,
      updatedAt: now,
    );

    await collegeScheduleRepo.saveSchedule(schedule);
    await nativeAlarmService.setCollegeSchedule(
      date: today,
      goingToCollege: goingToCollege,
      hasClasses: hasClasses,
      collegeStartTime: collegeStartTime,
      collegeEndTime: collegeEndTime,
      classStartTime: classStartTime,
      classEndTime: classEndTime,
    );
    await _refreshCollegeScheduleData();
    notifyListeners();
  }

  Future<void> cancelCollegeSchedule() async {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await collegeScheduleRepo.deleteSchedule(today);
    await nativeAlarmService.cancelCollegeSchedule(today);
    await _refreshCollegeScheduleData();
    notifyListeners();
  }

  // --- Wake Verification Operations ---
  Future<void> _refreshWakeVerificationData() async {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _todayWakeVerification = await wakeVerificationRepo.getVerificationForDate(today);
  }

  Future<void> verifyAwakeSelfie(String photoPath) async {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Stop alarm audio immediately
    await nativeAlarmService.stopAlarmSound();

    // Persist wake verification
    final verification = WakeVerification(
      date: today,
      verifiedAt: now,
      method: 'selfie',
    );
    await wakeVerificationRepo.saveVerification(verification);

    // Delete temporary photo file to protect user privacy
    try {
      final file = File(photoPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Failed to delete temporary selfie: $e');
    }

    await _refreshWakeVerificationData();
    notifyListeners();
  }

  Future<void> checkExactAlarmPermission() async {
    _canScheduleExactAlarms = await nativeAlarmService.canScheduleExactAlarms();
    notifyListeners();
  }

  Future<void> openExactAlarmSettings() async {
    await nativeAlarmService.openExactAlarmSettings();
  }

  // --- Sleep Operations ---
  Future<void> _refreshSleepData() async {
    _latestSleepLog = await sleepRepo.getLatestSleepLog();
  }

  Future<void> recordSleep(DateTime bedtime, DateTime wakeTime, {String? notes}) async {
    final durationMins = wakeTime.difference(bedtime).inMinutes;
    final log = SleepLog(
      bedtime: bedtime,
      wakeTime: wakeTime,
      durationMinutes: durationMins < 0 ? durationMins + 1440 : durationMins,
      notes: notes,
    );
    await sleepRepo.insertSleepLog(log);
    await badgeRepo.awardBadge('badge_sleep_champion');
    await _refreshSleepData();
    await _refreshBadgesAndStreak();
    notifyListeners();
  }

  // --- Badges & Streaks ---
  Future<void> _refreshBadgesAndStreak() async {
    _badges = await badgeRepo.getAllBadgesWithStatus();

    // Aggregate dates of activity
    final waterLogs = await waterRepo.getAllLogs();
    final workouts = await exerciseRepo.getAllWorkoutLogs();
    final walks = await walkRepo.getAllWalkSessions();

    final allDates = <DateTime>[
      ...waterLogs.map((w) => w.timestamp),
      ...workouts.map((w) => w.completedAt),
      ...walks.map((w) => w.startTime),
    ];

    _streakDays = StreakCalculator.calculateStreak(allDates);

    if (_streakDays >= 3) {
      await badgeRepo.awardBadge('badge_streak_3d');
    }
    if (_streakDays >= 7) {
      await badgeRepo.awardBadge('badge_streak_7d');
    }
  }

  // --- Reset All Data ---
  Future<void> resetAllData() async {
    _countdownTicker?.cancel();
    try {
      await nativeAlarmService.cancelAllAlarms();
    } catch (_) {}
    try {
      await notificationService.cancelAllNotifications();
    } catch (_) {}
    await DatabaseHelper.instance.clearAllData();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _profile = null;
    _isOnboarded = false;
    _nextWaterReminderTime = null;
    _waterReminderState = 'COMPLETED';
    _activeReminderId = null;
    _secondsUntilNextReminder = 0;
    _todayWaterLogs = [];
    _waterConsumedToday = 0;
    _lastDrinkTime = null;
    _weightEntries = [];
    _weightSummary = null;
    _todayMeals = [];
    _preparedMealIds = [];
    _exercises = [];
    _recentWorkouts = [];
    _walkSessions = [];
    _todayActivity = null;
    _weeklyActivityLogs = [];
    _latestSleepLog = null;
    _todayCollegeSchedule = null;
    _todayWakeVerification = null;
    _badges = [];
    _streakDays = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _countdownTicker?.cancel();
    super.dispose();
  }
}
