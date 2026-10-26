import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeAlarmService {
  static final NativeAlarmService instance = NativeAlarmService._internal();
  NativeAlarmService._internal();

  static const MethodChannel _channel = MethodChannel('com.bloomwell.bloomwell/alarm_manager');

  final _waterLoggedController = StreamController<void>.broadcast();
  Stream<void> get onWaterLoggedStream => _waterLoggedController.stream;

  final _waterReminderTriggeredController = StreamController<String>.broadcast();
  Stream<String> get onWaterReminderTriggeredStream => _waterReminderTriggeredController.stream;

  final _openFlowController = StreamController<String>.broadcast();
  Stream<String> get onOpenFlowStream => _openFlowController.stream;

  void notifyOpenFlow(String flow) {
    _openFlowController.add(flow);
  }

  bool _isInitialized = false;

  void initialize() {
    if (_isInitialized) return;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onWaterLogged':
          _waterLoggedController.add(null);
          break;
        case 'onWaterReminderTriggered':
          final reminderId = call.arguments as String?;
          if (reminderId != null) {
            _waterReminderTriggeredController.add(reminderId);
          }
          break;
        case 'onOpenFlow':
          final flow = call.arguments as String?;
          if (flow != null) {
            _openFlowController.add(flow);
          }
          break;
      }
    });
    _isInitialized = true;
  }

  Future<bool> scheduleWaterReminder({
    required DateTime deadline,
    required int intervalMinutes,
    String? reminderId,
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('scheduleWaterReminder', {
        'deadlineMs': deadline.millisecondsSinceEpoch,
        'intervalMinutes': intervalMinutes,
        'reminderId': reminderId,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('scheduleWaterReminder error: $e');
      return false;
    }
  }

  Future<bool> cancelWaterReminder() async {
    try {
      final res = await _channel.invokeMethod<bool>('cancelWaterReminder');
      return res ?? false;
    } catch (e) {
      debugPrint('cancelWaterReminder error: $e');
      return false;
    }
  }

  Future<bool> completeWaterReminder({
    required String? reminderId,
    required DateTime nextDeadline,
    required int intervalMinutes,
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('completeWaterReminder', {
        'reminderId': reminderId,
        'nextDeadlineMs': nextDeadline.millisecondsSinceEpoch,
        'intervalMinutes': intervalMinutes,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('completeWaterReminder error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getPendingWaterReminder() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('getPendingWaterReminder');
      return res;
    } catch (e) {
      debugPrint('getPendingWaterReminder error: $e');
      return null;
    }
  }

  Future<bool> scheduleWakeAlarm({
    required int hour,
    required int minute,
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('scheduleWakeAlarm', {
        'hour': hour,
        'minute': minute,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('scheduleWakeAlarm error: $e');
      return false;
    }
  }

  Future<bool> cancelWakeAlarm() async {
    try {
      final res = await _channel.invokeMethod<bool>('cancelWakeAlarm');
      return res ?? false;
    } catch (e) {
      debugPrint('cancelWakeAlarm error: $e');
      return false;
    }
  }

  Future<bool> cancelAllAlarms() async {
    try {
      final res = await _channel.invokeMethod<bool>('cancelAllAlarms');
      return res ?? false;
    } catch (e) {
      debugPrint('cancelAllAlarms error: $e');
      return false;
    }
  }

  Future<bool> stopAlarmSound({String? reminderId}) async {
    try {
      final res = await _channel.invokeMethod<bool>('stopAlarmSound', {
        'reminderId': reminderId,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('stopAlarmSound error: $e');
      return false;
    }
  }

  Future<bool> setCollegeSchedule({
    required String date,
    required bool goingToCollege,
    required bool hasClasses,
    String? collegeStartTime,
    String? collegeEndTime,
    String? classStartTime,
    String? classEndTime,
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('setCollegeSchedule', {
        'date': date,
        'goingToCollege': goingToCollege,
        'hasClasses': hasClasses,
        'collegeStartTime': collegeStartTime,
        'collegeEndTime': collegeEndTime,
        'classStartTime': classStartTime,
        'classEndTime': classEndTime,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('setCollegeSchedule error: $e');
      return false;
    }
  }

  Future<bool> setSleepSchedule({
    required String bedtime,
    required String wakeUpTime,
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('setSleepSchedule', {
        'bedtime': bedtime,
        'wakeUpTime': wakeUpTime,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('setSleepSchedule error: $e');
      return false;
    }
  }

  Future<bool> cancelCollegeSchedule(String date) async {
    try {
      final res = await _channel.invokeMethod<bool>('cancelCollegeSchedule', {
        'date': date,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('cancelCollegeSchedule error: $e');
      return false;
    }
  }

  Future<String?> getInitialFlow() async {
    try {
      return await _channel.invokeMethod<String>('getInitialFlow');
    } catch (e) {
      debugPrint('getInitialFlow error: $e');
      return null;
    }
  }

  Future<bool> canScheduleExactAlarms() async {
    try {
      final res = await _channel.invokeMethod<bool>('canScheduleExactAlarms');
      return res ?? true;
    } catch (e) {
      debugPrint('canScheduleExactAlarms error: $e');
      return true;
    }
  }

  Future<void> openExactAlarmSettings() async {
    try {
      await _channel.invokeMethod('openExactAlarmSettings');
    } catch (e) {
      debugPrint('openExactAlarmSettings error: $e');
    }
  }
}
