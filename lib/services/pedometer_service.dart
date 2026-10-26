import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repositories/daily_activity_repository.dart';
import '../domain/calculators/step_calculator.dart';
import '../domain/models/daily_activity_log.dart';

enum PedometerSensorStatus {
  initializing,
  ready,
  permissionDenied,
  sensorUnavailable,
  error,
}

class PedometerService {
  static final PedometerService instance = PedometerService._internal();
  PedometerService._internal();

  static const MethodChannel _nativeChannel = MethodChannel('com.bloomwell.bloomwell/step_counter');

  DailyActivityRepository? _activityRepo;

  StreamSubscription<StepCount>? _stepSubscription;
  StreamSubscription<PedestrianStatus>? _statusSubscription;

  PedometerSensorStatus _sensorStatus = PedometerSensorStatus.initializing;
  PedometerSensorStatus get sensorStatus => _sensorStatus;

  String _pedestrianStatus = 'idle';
  String get pedestrianStatus => _pedestrianStatus;

  int _todaySteps = 0;
  int get todaySteps => _todaySteps;

  int _dailyGoal = 6000;
  int get dailyGoal => _dailyGoal;

  DateTime? _lastSensorEventTime;
  DateTime? get lastSensorEventTime => _lastSensorEventTime;

  double? _userHeightCm;
  double? _userWeightKg;

  final StreamController<int> _todayStepsController = StreamController<int>.broadcast();
  Stream<int> get todayStepsStream => _todayStepsController.stream;

  final StreamController<String> _pedestrianStatusController = StreamController<String>.broadcast();
  Stream<String> get pedestrianStatusStream => _pedestrianStatusController.stream;

  final StreamController<PedometerSensorStatus> _sensorStatusController =
      StreamController<PedometerSensorStatus>.broadcast();
  Stream<PedometerSensorStatus> get sensorStatusStream => _sensorStatusController.stream;

  static const String _prefDateKey = 'bloomwell_pedometer_date';
  static const String _prefBaselineKey = 'bloomwell_pedometer_baseline';
  static const String _prefRebootOffsetKey = 'bloomwell_pedometer_reboot_offset';
  static const String _prefTodayStepsKey = 'bloomwell_pedometer_today_steps';
  static const String _prefGoalKey = 'bloomwell_pedometer_daily_goal';

  /// Initializes the pedometer service with dependencies and loaded profile metrics
  Future<void> initialize({
    DailyActivityRepository? activityRepo,
    double? userHeightCm,
    double? userWeightKg,
  }) async {
    _activityRepo = activityRepo ?? DailyActivityRepository();
    _userHeightCm = userHeightCm;
    _userWeightKg = userWeightKg;

    // Load persisted state for today (strictly preserves existing non-zero steps)
    await _loadPersistedState();

    // Check & request permission and attach sensor stream
    await startListening();
  }

  void updateUserProfile({double? heightCm, double? weightKg}) {
    _userHeightCm = heightCm ?? _userHeightCm;
    _userWeightKg = weightKg ?? _userWeightKg;
  }

  Future<void> setDailyGoal(int newGoal) async {
    if (newGoal <= 0) return;
    _dailyGoal = newGoal;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefGoalKey, newGoal);

    // Save updated goal to SQLite for today
    await _persistCurrentDayLog();
  }

  Future<void> _loadPersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _formatTodayDate();
    final savedDate = prefs.getString(_prefDateKey);

    _dailyGoal = prefs.getInt(_prefGoalKey) ?? 6000;

    if (savedDate == today) {
      final prefSteps = prefs.getInt(_prefTodayStepsKey) ?? 0;
      final dbLog = await _activityRepo?.getLogForDate(today);
      final dbSteps = dbLog?.steps ?? 0;
      // Preserve the highest verified step total (never wipe legitimate steps)
      _todaySteps = prefSteps >= dbSteps ? prefSteps : dbSteps;
    } else {
      // Date changed while app was terminated (missed midnight rollover)!
      if (savedDate != null) {
        final prevSteps = prefs.getInt(_prefTodayStepsKey) ?? 0;
        if (prevSteps > 0 && _activityRepo != null) {
          final dist = StepCalculator.estimateDistanceMeters(steps: prevSteps, heightCm: _userHeightCm);
          final cal = StepCalculator.estimateCaloriesBurned(steps: prevSteps, weightKg: _userWeightKg);
          final activeMin = StepCalculator.estimateActiveMinutes(prevSteps);
          await _activityRepo!.insertOrUpdate(DailyActivityLog(
            date: savedDate,
            steps: prevSteps,
            goal: _dailyGoal,
            distanceMeters: dist,
            activeMinutes: activeMin,
            estimatedCalories: cal,
            lastUpdatedAt: DateTime.now(),
          ));
        }
      }

      // Reset for new day
      _todaySteps = 0;
      await prefs.setString(_prefDateKey, today);
      await prefs.setInt(_prefBaselineKey, -1);
      await prefs.setInt(_prefRebootOffsetKey, 0);
      await prefs.setInt(_prefTodayStepsKey, 0);
    }

    _todayStepsController.add(_todaySteps);
  }

  String _formatTodayDate([DateTime? date]) {
    final d = date ?? DateTime.now();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  Future<bool> checkPermission() async {
    final status = await Permission.activityRecognition.status;
    return status.isGranted;
  }

  Future<bool> requestPermission() async {
    final status = await Permission.activityRecognition.request();
    if (status.isGranted) {
      await startListening();
      return true;
    } else {
      _updateStatus(PedometerSensorStatus.permissionDenied);
      return false;
    }
  }

  Future<void> startListening() async {
    final hasPerm = await checkPermission();
    if (!hasPerm) {
      final requested = await Permission.activityRecognition.request();
      if (!requested.isGranted) {
        _updateStatus(PedometerSensorStatus.permissionDenied);
        return;
      }
    }

    _updateStatus(PedometerSensorStatus.ready);

    // 1. Start Native Foreground Service for continuous screen-off collection
    try {
      await _nativeChannel.invokeMethod('startForegroundService');
    } catch (e) {
      if (kDebugMode) print('Note: native foreground step service could not be started: $e');
    }

    // 2. Query immediate sensor reading from native HAL to calibrate without waiting for a new step
    try {
      final initialSteps = await _nativeChannel.invokeMethod<int>('getLatestHardwareSteps');
      if (initialSteps != null && initialSteps > 0) {
        await processStepEvent(
          rawHardwareSteps: initialSteps,
          eventTime: DateTime.now(),
        );
      }
    } catch (_) {}

    _stepSubscription?.cancel();
    _statusSubscription?.cancel();

    try {
      _stepSubscription = Pedometer.stepCountStream.listen(
        _onStepCountReceived,
        onError: (err) {
          if (kDebugMode) print('Pedometer step count stream error: $err');
          _updateStatus(PedometerSensorStatus.sensorUnavailable);
        },
        cancelOnError: false,
      );

      _statusSubscription = Pedometer.pedestrianStatusStream.listen(
        (status) {
          _pedestrianStatus = status.status;
          _pedestrianStatusController.add(_pedestrianStatus);
        },
        onError: (_) {
          // Some devices don't have step detector, only step counter
        },
        cancelOnError: false,
      );
    } catch (e) {
      if (kDebugMode) print('Error subscribing to Pedometer: $e');
      _updateStatus(PedometerSensorStatus.sensorUnavailable);
    }
  }

  /// Reconciles sensor data and date boundaries whenever the app returns to foreground
  Future<void> reconcileOnResume() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _formatTodayDate();
    final savedDate = prefs.getString(_prefDateKey) ?? today;

    // 1. Check for missed midnight rollover while backgrounded or phone asleep
    if (savedDate != today) {
      final prevSteps = prefs.getInt(_prefTodayStepsKey) ?? 0;
      if (prevSteps > 0 && _activityRepo != null) {
        final dist = StepCalculator.estimateDistanceMeters(steps: prevSteps, heightCm: _userHeightCm);
        final cal = StepCalculator.estimateCaloriesBurned(steps: prevSteps, weightKg: _userWeightKg);
        final activeMin = StepCalculator.estimateActiveMinutes(prevSteps);
        await _activityRepo!.insertOrUpdate(DailyActivityLog(
          date: savedDate,
          steps: prevSteps,
          goal: _dailyGoal,
          distanceMeters: dist,
          activeMinutes: activeMin,
          estimatedCalories: cal,
          lastUpdatedAt: DateTime.now(),
        ));
      }

      // Initialize new day
      _todaySteps = 0;
      await prefs.setString(_prefDateKey, today);
      await prefs.setInt(_prefBaselineKey, -1);
      await prefs.setInt(_prefRebootOffsetKey, 0);
      await prefs.setInt(_prefTodayStepsKey, 0);
      _todayStepsController.add(0);
      await _persistCurrentDayLog();
    }

    // 2. Query native hardware step counter to ingest steps taken while screen was off
    try {
      final latestHwSteps = await _nativeChannel.invokeMethod<int>('getLatestHardwareSteps');
      if (latestHwSteps != null && latestHwSteps > 0) {
        await processStepEvent(
          rawHardwareSteps: latestHwSteps,
          eventTime: DateTime.now(),
        );
        return;
      }
    } catch (_) {}

    // 3. Fallback: Check if background native service recorded steps in SharedPreferences
    final bgTodaySteps = prefs.getInt(_prefTodayStepsKey) ?? _todaySteps;
    if (bgTodaySteps > _todaySteps) {
      _todaySteps = bgTodaySteps;
      _todayStepsController.add(_todaySteps);
      await _persistCurrentDayLog();
    }
  }

  /// Pure deterministic step processor exposed for real-world sensor events and unit tests
  Future<void> processStepEvent({
    required int rawHardwareSteps,
    required DateTime eventTime,
    SharedPreferences? prefsInstance,
  }) async {
    _lastSensorEventTime = eventTime;
    final prefs = prefsInstance ?? await SharedPreferences.getInstance();
    final today = _formatTodayDate(eventTime);
    String savedDate = prefs.getString(_prefDateKey) ?? today;

    int baseline = prefs.getInt(_prefBaselineKey) ?? -1;
    int rebootOffset = prefs.getInt(_prefRebootOffsetKey) ?? 0;
    int savedTodaySteps = prefs.getInt(_prefTodayStepsKey) ?? 0;

    // 1. Midnight / Date Change Rollover
    if (savedDate != today) {
      // Archive the old day in SQLite before rolling over
      if (_activityRepo != null && savedTodaySteps > 0) {
        final dist = StepCalculator.estimateDistanceMeters(steps: savedTodaySteps, heightCm: _userHeightCm);
        final cal = StepCalculator.estimateCaloriesBurned(steps: savedTodaySteps, weightKg: _userWeightKg);
        final activeMin = StepCalculator.estimateActiveMinutes(savedTodaySteps);
        await _activityRepo!.insertOrUpdate(DailyActivityLog(
          date: savedDate,
          steps: savedTodaySteps,
          goal: _dailyGoal,
          distanceMeters: dist,
          activeMinutes: activeMin,
          estimatedCalories: cal,
          lastUpdatedAt: eventTime,
        ));
      }

      // Initialize new day starting at 0
      savedDate = today;
      baseline = rawHardwareSteps;
      rebootOffset = 0;
      savedTodaySteps = 0;
      _todaySteps = 0;
      await prefs.setString(_prefDateKey, today);
      await prefs.setInt(_prefBaselineKey, baseline);
      await prefs.setInt(_prefRebootOffsetKey, 0);
      await prefs.setInt(_prefTodayStepsKey, 0);
    }

    // 2. Initial Setup Baseline for First Run
    if (baseline == -1) {
      baseline = rawHardwareSteps;
      await prefs.setInt(_prefBaselineKey, baseline);
      await prefs.setString(_prefDateKey, today);
      // Preserve any previously loaded steps from persistent storage
      if (savedTodaySteps > 0 && rebootOffset == 0) {
        rebootOffset = savedTodaySteps;
        await prefs.setInt(_prefRebootOffsetKey, rebootOffset);
      }
    }

    // 3. Device Reboot Detection
    // The hardware step counter counts steps since boot. If rawHardwareSteps < baseline, device rebooted!
    if (rawHardwareSteps < baseline) {
      rebootOffset += savedTodaySteps;
      baseline = 0; // Hardware step counter resets to 0 upon device reboot
      await prefs.setInt(_prefRebootOffsetKey, rebootOffset);
      await prefs.setInt(_prefBaselineKey, baseline);
    }

    // 4. Calculate Today's Steps
    final deltaSinceBaseline = (rawHardwareSteps - baseline).clamp(0, 500000);
    final newTodaySteps = rebootOffset + deltaSinceBaseline;

    // Idempotent: ensure step count never regresses within the same day
    if (newTodaySteps >= _todaySteps) {
      _todaySteps = newTodaySteps;
      await prefs.setInt(_prefTodayStepsKey, _todaySteps);
      _todayStepsController.add(_todaySteps);
      await _persistCurrentDayLog();
    }
  }

  void _onStepCountReceived(StepCount stepCount) {
    processStepEvent(
      rawHardwareSteps: stepCount.steps,
      eventTime: stepCount.timeStamp,
    );
  }

  Future<void> _persistCurrentDayLog() async {
    if (_activityRepo == null) return;
    final today = _formatTodayDate();
    final dist = StepCalculator.estimateDistanceMeters(steps: _todaySteps, heightCm: _userHeightCm);
    final cal = StepCalculator.estimateCaloriesBurned(steps: _todaySteps, weightKg: _userWeightKg);
    final activeMin = StepCalculator.estimateActiveMinutes(_todaySteps);

    final log = DailyActivityLog(
      date: today,
      steps: _todaySteps,
      goal: _dailyGoal,
      distanceMeters: dist,
      activeMinutes: activeMin,
      estimatedCalories: cal,
      lastUpdatedAt: DateTime.now(),
    );

    await _activityRepo!.insertOrUpdate(log);
  }

  void _updateStatus(PedometerSensorStatus status) {
    _sensorStatus = status;
    _sensorStatusController.add(_sensorStatus);
  }

  @visibleForTesting
  void resetForTesting({int initialSteps = 0}) {
    _todaySteps = initialSteps;
    _lastSensorEventTime = null;
  }

  void dispose() {
    _stepSubscription?.cancel();
    _statusSubscription?.cancel();
    _todayStepsController.close();
    _pedestrianStatusController.close();
    _sensorStatusController.close();
  }
}
