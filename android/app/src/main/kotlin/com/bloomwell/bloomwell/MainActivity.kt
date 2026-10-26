package com.bloomwell.bloomwell

import android.app.AlarmManager
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Calendar

class MainActivity : FlutterFragmentActivity() {
    private val STEP_CHANNEL = "com.bloomwell.bloomwell/step_counter"
    private val ALARM_CHANNEL = "com.bloomwell.bloomwell/alarm_manager"
    private val UPDATER_CHANNEL = "com.bloomwell.bloomwell/app_updater"

    companion object {
        private var instance: MainActivity? = null
        private var alarmMethodChannel: MethodChannel? = null

        fun notifyWaterLogged() {
            Handler(Looper.getMainLooper()).post {
                alarmMethodChannel?.invokeMethod("onWaterLogged", null)
            }
        }

        fun notifyWaterReminderTriggered(reminderId: String) {
            Handler(Looper.getMainLooper()).post {
                alarmMethodChannel?.invokeMethod("onWaterReminderTriggered", reminderId)
                alarmMethodChannel?.invokeMethod("onOpenFlow", BloomWellAlarmReceiver.FLOW_WATER_SCREEN)
            }
        }
    }

    private var initialFlow: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
        sanitizeFlutterSharedPreferences()
        BloomWellAlarmReceiver.createNotificationChannels(this)
        handleIntent(intent)
    }

    private fun sanitizeFlutterSharedPreferences() {
        try {
            val prefs = getSharedPreferences(BloomWellAlarmReceiver.PREFS_NAME, Context.MODE_PRIVATE)
            val allEntries = prefs.all
            val editor = prefs.edit()
            var modified = false
            for ((key, value) in allEntries) {
                if (value is Int) {
                    editor.remove(key)
                    editor.putLong(key, value.toLong())
                    modified = true
                }
            }
            if (modified) {
                editor.commit()
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to sanitize preferences", e)
        }
    }

    override fun onResume() {
        super.onResume()
        // If app resumes (e.g. phone was unlocked or app reopened) and a water reminder is awaiting confirmation,
        // automatically route to the Drink Water screen as required.
        val prefs = getSharedPreferences(BloomWellAlarmReceiver.PREFS_NAME, Context.MODE_PRIVATE)
        val state = prefs.getString(BloomWellAlarmReceiver.PREF_WATER_REMINDER_STATE, null)
        if (state == BloomWellAlarmReceiver.STATE_AWAITING_CONFIRMATION || state == BloomWellAlarmReceiver.STATE_RINGING) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
            }
            alarmMethodChannel?.invokeMethod("onOpenFlow", BloomWellAlarmReceiver.FLOW_WATER_SCREEN)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    override fun onDestroy() {
        if (instance == this) {
            instance = null
        }
        super.onDestroy()
    }

    private fun handleIntent(intent: Intent?) {
        val flow = intent?.getStringExtra(BloomWellAlarmReceiver.EXTRA_OPEN_FLOW)
        if (flow != null) {
            initialFlow = flow
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
            } else {
                @Suppress("DEPRECATION")
                window.addFlags(
                    android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                )
            }
            alarmMethodChannel?.invokeMethod("onOpenFlow", flow)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Step Counter Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STEP_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    try {
                        StepCounterForegroundService.start(this)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_START_FAILED", e.message, null)
                    }
                }
                "stopForegroundService" -> {
                    try {
                        StepCounterForegroundService.stop(this)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_STOP_FAILED", e.message, null)
                    }
                }
                "isServiceRunning" -> {
                    result.success(StepCounterForegroundService.isRunning)
                }
                "getLatestHardwareSteps" -> {
                    if (StepCounterForegroundService.latestHardwareSteps > 0) {
                        result.success(StepCounterForegroundService.latestHardwareSteps)
                        return@setMethodCallHandler
                    }

                    val sm = getSystemService(Context.SENSOR_SERVICE) as? SensorManager
                    val sensor = sm?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
                    if (sm != null && sensor != null) {
                        var hasResponded = false
                        val listener = object : SensorEventListener {
                            override fun onAccuracyChanged(s: Sensor?, accuracy: Int) {}
                            override fun onSensorChanged(event: SensorEvent?) {
                                if (!hasResponded && event != null && event.values.isNotEmpty()) {
                                    hasResponded = true
                                    sm.unregisterListener(this)
                                    val count = event.values[0].toInt()
                                    StepCounterForegroundService.latestHardwareSteps = count
                                    result.success(count)
                                }
                            }
                        }
                        sm.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_FASTEST)

                        Handler(Looper.getMainLooper()).postDelayed({
                            if (!hasResponded) {
                                hasResponded = true
                                sm.unregisterListener(listener)
                                val prefs = getSharedPreferences(StepCounterForegroundService.PREFS_NAME, Context.MODE_PRIVATE)
                                val fallback = prefs.getSafeInt(StepCounterForegroundService.PREF_KEY_LAST_HW_STEPS, -1)
                                result.success(fallback)
                            }
                        }, 300)
                    } else {
                        result.success(-1)
                    }
                }
                "getDeviceInfo" -> {
                    val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                    val isIgnoring = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && pm != null) {
                        pm.isIgnoringBatteryOptimizations(packageName)
                    } else {
                        true
                    }

                    val info = mapOf(
                        "manufacturer" to (Build.MANUFACTURER ?: "unknown"),
                        "model" to (Build.MODEL ?: "unknown"),
                        "sdkInt" to Build.VERSION.SDK_INT,
                        "isBatteryOptimizationIgnored" to isIgnoring
                    )
                    result.success(info)
                }
                "openBatterySettings" -> {
                    val opened = launchBatterySettings()
                    result.success(opened)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // 2. Alarm & Reminder Channel
        val alarmChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CHANNEL)
        alarmMethodChannel = alarmChannel
        alarmChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleWaterReminder" -> {
                    val deadlineMs = (call.argument<Number>("deadlineMs"))?.toLong() ?: (System.currentTimeMillis() + 30 * 60 * 1000L)
                    val intervalMinutes = call.argument<Int>("intervalMinutes") ?: 30
                    val reminderId = call.argument<String>("reminderId")
                    BloomWellAlarmReceiver.scheduleWaterReminder(this, deadlineMs, intervalMinutes, reminderId)
                    result.success(true)
                }
                "cancelWaterReminder" -> {
                    BloomWellAlarmReceiver.cancelWaterReminder(this)
                    result.success(true)
                }
                "cancelAllAlarms" -> {
                    BloomWellAlarmReceiver.cancelAllAlarms(this)
                    result.success(true)
                }
                "scheduleWakeAlarm" -> {
                    val hour = call.argument<Int>("hour") ?: 7
                    val minute = call.argument<Int>("minute") ?: 0
                    BloomWellAlarmReceiver.scheduleWakeAlarm(this, hour, minute)
                    result.success(true)
                }
                "cancelWakeAlarm" -> {
                    BloomWellAlarmReceiver.cancelWakeAlarm(this)
                    result.success(true)
                }
                "stopAlarmSound" -> {
                    val reminderId = call.argument<String>("reminderId")
                    AlarmSoundManager.stopAlarm(reminderId)
                    val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    nm.cancel(BloomWellAlarmReceiver.NOTIFICATION_ID_ALARM)
                    nm.cancel(BloomWellAlarmReceiver.NOTIFICATION_ID_WATER)
                    result.success(true)
                }
                "completeWaterReminder" -> {
                    val reminderId = call.argument<String>("reminderId")
                    val nextDeadlineMs = (call.argument<Number>("nextDeadlineMs"))?.toLong() ?: (System.currentTimeMillis() + 30 * 60 * 1000L)
                    val intervalMinutes = call.argument<Int>("intervalMinutes") ?: 30
                    BloomWellAlarmReceiver.completeWaterReminder(this, reminderId, nextDeadlineMs, intervalMinutes)
                    result.success(true)
                }
                "getPendingWaterReminder" -> {
                    val prefs = getSharedPreferences(BloomWellAlarmReceiver.PREFS_NAME, Context.MODE_PRIVATE)
                    val state = prefs.getString(BloomWellAlarmReceiver.PREF_WATER_REMINDER_STATE, BloomWellAlarmReceiver.STATE_COMPLETED)
                    val reminderId = prefs.getString(BloomWellAlarmReceiver.PREF_WATER_REMINDER_ID, null)
                    val rawDue = prefs.all[BloomWellAlarmReceiver.PREF_WATER_REMINDER_DUE_MS]
                    val dueMs = when (rawDue) {
                        is Number -> rawDue.toLong()
                        is String -> rawDue.toLongOrNull() ?: 0L
                        else -> 0L
                    }
                    result.success(mapOf(
                        "state" to state,
                        "reminderId" to reminderId,
                        "dueMs" to dueMs
                    ))
                }
                "setCollegeSchedule" -> {
                    val date = call.argument<String>("date") ?: ""
                    val goingToCollege = call.argument<Boolean>("goingToCollege") ?: false
                    val collegeStartTime = call.argument<String>("collegeStartTime")
                    val collegeEndTime = call.argument<String>("collegeEndTime")
                    val hasClasses = call.argument<Boolean>("hasClasses") ?: false
                    val classStartTime = call.argument<String>("classStartTime")
                    val classEndTime = call.argument<String>("classEndTime")

                    val prefs = getSharedPreferences(BloomWellAlarmReceiver.PREFS_NAME, Context.MODE_PRIVATE)
                    prefs.edit()
                        .putString(BloomWellAlarmReceiver.PREF_CLASS_DATE, date)
                        .putBoolean(BloomWellAlarmReceiver.PREF_COLLEGE_GOING, goingToCollege)
                        .putString(BloomWellAlarmReceiver.PREF_COLLEGE_START, collegeStartTime)
                        .putString(BloomWellAlarmReceiver.PREF_COLLEGE_END, collegeEndTime)
                        .putBoolean(BloomWellAlarmReceiver.PREF_CLASS_HAS_CLASSES, hasClasses)
                        .putString(BloomWellAlarmReceiver.PREF_CLASS_START, classStartTime)
                        .putString(BloomWellAlarmReceiver.PREF_CLASS_END, classEndTime)
                        .apply()

                    // Schedule class end catchup if classes or college hours end today
                    val catchupEndStr = if (hasClasses && !classEndTime.isNullOrEmpty()) classEndTime else if (goingToCollege && !collegeEndTime.isNullOrEmpty()) collegeEndTime else null
                    if (!catchupEndStr.isNullOrEmpty()) {
                        try {
                            val endParts = catchupEndStr.split(":")
                            val endCal = Calendar.getInstance().apply {
                                set(Calendar.HOUR_OF_DAY, endParts[0].toInt())
                                set(Calendar.MINUTE, endParts[1].toInt())
                                set(Calendar.SECOND, 0)
                                set(Calendar.MILLISECOND, 0)
                            }
                            if (endCal.timeInMillis > System.currentTimeMillis()) {
                                BloomWellAlarmReceiver.scheduleClassEndCatchup(this, endCal.timeInMillis)
                            }
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                    }
                    result.success(true)
                }
                "cancelCollegeSchedule" -> {
                    val prefs = getSharedPreferences(BloomWellAlarmReceiver.PREFS_NAME, Context.MODE_PRIVATE)
                    prefs.edit()
                        .remove(BloomWellAlarmReceiver.PREF_CLASS_DATE)
                        .remove(BloomWellAlarmReceiver.PREF_COLLEGE_GOING)
                        .remove(BloomWellAlarmReceiver.PREF_COLLEGE_START)
                        .remove(BloomWellAlarmReceiver.PREF_COLLEGE_END)
                        .remove(BloomWellAlarmReceiver.PREF_CLASS_HAS_CLASSES)
                        .remove(BloomWellAlarmReceiver.PREF_CLASS_START)
                        .remove(BloomWellAlarmReceiver.PREF_CLASS_END)
                        .remove(BloomWellAlarmReceiver.PREF_WATER_DEFERRED)
                        .apply()
                    result.success(true)
                }
                "setSleepSchedule" -> {
                    val bedtime = call.argument<String>("bedtime") ?: "23:00"
                    val wakeTime = call.argument<String>("wakeUpTime") ?: "07:00"
                    val prefs = getSharedPreferences(BloomWellAlarmReceiver.PREFS_NAME, Context.MODE_PRIVATE)
                    prefs.edit()
                        .putString(BloomWellAlarmReceiver.PREF_BEDTIME, bedtime)
                        .putString(BloomWellAlarmReceiver.PREF_WAKE_TIME, wakeTime)
                        .apply()

                    // Reschedule wake alarm
                    try {
                        val wakeParts = wakeTime.split(":")
                        if (wakeParts.size == 2) {
                            BloomWellAlarmReceiver.scheduleWakeAlarm(this, wakeParts[0].toInt(), wakeParts[1].toInt())
                        }
                    } catch (_: Exception) {}

                    // Recalculate water reminder
                    val interval = prefs.getSafeInt(BloomWellAlarmReceiver.PREF_REMINDER_INTERVAL, 30)
                    val candidateMs = System.currentTimeMillis() + interval * 60 * 1000L
                    val targetMs = BloomWellAlarmReceiver.calculateNextUnsuppressedReminderTime(this, candidateMs, interval)
                    BloomWellAlarmReceiver.scheduleWaterReminder(this, targetMs, interval)
                    result.success(true)
                }
                "getInitialFlow" -> {
                    val flow = initialFlow
                    initialFlow = null
                    result.success(flow)
                }
                "canScheduleExactAlarms" -> {
                    val am = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                    val canSchedule = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && am != null) {
                        am.canScheduleExactAlarms()
                    } else {
                        true
                    }
                    result.success(canSchedule)
                }
                "openExactAlarmSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        try {
                            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SETTINGS_ERROR", e.message, null)
                        }
                    } else {
                        result.success(true)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // 3. In-App Updater Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAppVersion" -> {
                    try {
                        val pInfo = packageManager.getPackageInfo(packageName, 0)
                        val vName = pInfo.versionName ?: "1.0.0"
                        val vCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            pInfo.longVersionCode
                        } else {
                            @Suppress("DEPRECATION")
                            pInfo.versionCode.toLong()
                        }
                        result.success(mapOf(
                            "versionName" to vName,
                            "versionCode" to vCode,
                            "applicationId" to packageName
                        ))
                    } catch (e: Exception) {
                        result.error("VERSION_ERROR", e.message, null)
                    }
                }
                "canRequestPackageInstalls" -> {
                    val canInstall = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        packageManager.canRequestPackageInstalls()
                    } else {
                        true
                    }
                    result.success(canInstall)
                }
                "openInstallPermissionSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SETTINGS_ERROR", e.message, null)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath.isNullOrEmpty()) {
                        result.error("INVALID_PATH", "File path is null or empty", null)
                        return@setMethodCallHandler
                    }
                    val file = File(filePath)
                    if (!file.exists()) {
                        result.error("FILE_NOT_FOUND", "APK file does not exist at $filePath", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val uri = FileProvider.getUriForFile(
                            this,
                            "$packageName.fileprovider",
                            file
                        )
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun launchBatterySettings(): Boolean {
        val intents = mutableListOf<Intent>()

        // 1. Direct ignore battery optimizations request dialog (if supported)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            intents.add(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:$packageName")
            })
        }

        // 2. Standard Battery Optimization list
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            intents.add(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
        }

        // 3. Xiaomi / POCO / Redmi Autostart Screen
        val manufacturer = (Build.MANUFACTURER ?: "").lowercase()
        if (manufacturer.contains("xiaomi") || manufacturer.contains("redmi") || manufacturer.contains("poco")) {
            intents.add(Intent().apply {
                component = ComponentName(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.autostart.AutoStartManagementActivity"
                )
            })
        }

        // 4. Fallback: App Details Settings
        intents.add(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
        })

        for (intent in intents) {
            try {
                if (intent.resolveActivity(packageManager) != null) {
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    return true
                }
            } catch (_: Exception) {}
        }
        return false
    }
}
