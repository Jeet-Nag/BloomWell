import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'native_alarm_service.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload == 'water_screen' ||
            response.id == 101 ||
            response.id == 102 ||
            response.notificationResponseType == NotificationResponseType.selectedNotificationAction) {
          NativeAlarmService.instance.notifyOpenFlow('water_screen');
        }
      },
    );

    // Create required notification channels
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          'water_reminders',
          'Water Reminders',
          description: 'Gentle hydration reminders with photo confirmation',
          importance: Importance.high,
          enableVibration: true,
        ),
      );

      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          'meal_prep',
          'Meal Prep Reminders',
          description: 'Reminders for preparing tomorrow meals',
          importance: Importance.defaultImportance,
        ),
      );

      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          'weight_checkin',
          '15-Day Weight Check-in',
          description: 'Mindful 15-day weight tracking reminder',
          importance: Importance.defaultImportance,
        ),
      );

      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          'wake_alarm',
          'Wake-Up Alarm',
          description: 'Local wake up alarm',
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
        ),
      );
    }

    _isInitialized = true;
  }

  Future<bool> requestPermission() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      final bool? granted =
          await androidImplementation.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  /// Show an immediate notification for water reminder or alert
  Future<void> showWaterReminderNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'water_reminders',
      'Water Reminders',
      channelDescription: 'Gentle hydration reminders with photo confirmation',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(101, title, body, details, payload: 'water_screen');
  }

  /// Schedule the next water reminder at a future DateTime
  Future<void> scheduleWaterReminder({
    required DateTime scheduledDate,
    required String title,
    required String body,
  }) async {
    try {
      final tz.TZDateTime tzDate = tz.TZDateTime.from(scheduledDate, tz.local);
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'water_reminders',
        'Water Reminders',
        importance: Importance.high,
        priority: Priority.high,
      );

      await _notificationsPlugin.zonedSchedule(
        102,
        title,
        body,
        tzDate,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'water_screen',
      );
    } catch (_) {
      // Inexact scheduling fallback if permission or exact alarm restricted
    }
  }

  /// Cancel water reminders (e.g. during quiet hours or sleep)
  Future<void> cancelWaterReminders() async {
    await _notificationsPlugin.cancel(102);
  }

  /// Show wake-up alarm notification
  Future<void> showAlarmNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'wake_alarm',
      'Wake-Up Alarm',
      channelDescription: 'Local wake up alarm',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      enableVibration: true,
      playSound: true,
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(201, title, body, details);
  }

  /// Schedule a daily wake-up alarm matching the user's wake time
  Future<void> scheduleDailyWakeAlarm({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'wake_alarm',
        'Wake-Up Alarm',
        channelDescription: 'Local wake up alarm',
        importance: Importance.max,
        priority: Priority.max,
        fullScreenIntent: true,
        enableVibration: true,
        playSound: true,
      );

      await _notificationsPlugin.zonedSchedule(
        202,
        title,
        body,
        scheduledDate,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {
      // Inexact fallback if exact alarms are restricted
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (_) {}
  }

  Future<void> cancelNotification(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
    } catch (_) {}
  }
}
