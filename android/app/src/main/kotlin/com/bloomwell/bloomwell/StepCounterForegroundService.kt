package com.bloomwell.bloomwell

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

fun SharedPreferences.getSafeInt(key: String, defValue: Int = 0): Int {
    return try {
        val v = all[key]
        when (v) {
            is Number -> v.toInt()
            is String -> v.toIntOrNull() ?: defValue
            else -> defValue
        }
    } catch (_: Exception) {
        defValue
    }
}

fun SharedPreferences.Editor.putSafeLong(key: String, value: Int): SharedPreferences.Editor {
    return putLong(key, value.toLong())
}

class StepCounterForegroundService : Service(), SensorEventListener {

    companion object {
        const val CHANNEL_ID = "bloomwell_step_tracker_channel"
        const val NOTIFICATION_ID = 40401
        const val PREFS_NAME = "FlutterSharedPreferences"

        // Keys matching Flutter SharedPreferences conventions (prefixed with flutter.)
        const val PREF_KEY_TODAY_STEPS = "flutter.bloomwell_pedometer_today_steps"
        const val PREF_KEY_BASELINE = "flutter.bloomwell_pedometer_baseline"
        const val PREF_KEY_REBOOT_OFFSET = "flutter.bloomwell_pedometer_reboot_offset"
        const val PREF_KEY_DATE = "flutter.bloomwell_pedometer_date"
        const val PREF_KEY_LAST_HW_STEPS = "flutter.bloomwell_pedometer_last_hardware_steps"
        const val PREF_KEY_GOAL = "flutter.bloomwell_pedometer_daily_goal"

        @Volatile
        var isRunning: Boolean = false

        @Volatile
        var latestHardwareSteps: Int = -1

        @Volatile
        var cachedTodaySteps: Int = 0

        fun start(context: Context) {
            val intent = Intent(context, StepCounterForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, StepCounterForegroundService::class.java)
            context.stopService(intent)
        }
    }

    private var sensorManager: SensorManager? = null
    private var stepSensor: Sensor? = null
    private lateinit var prefs: SharedPreferences

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        createNotificationChannel()

        cachedTodaySteps = prefs.getSafeInt(PREF_KEY_TODAY_STEPS, 0)
        latestHardwareSteps = prefs.getSafeInt(PREF_KEY_LAST_HW_STEPS, -1)

        val notification = buildNotification(cachedTodaySteps)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (_: Exception) {
            startForeground(NOTIFICATION_ID, notification)
        }

        sensorManager = getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        stepSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        if (stepSensor != null) {
            // SENSOR_DELAY_NORMAL with 60s batching (60,000,000 microseconds)
            sensorManager?.registerListener(
                this,
                stepSensor,
                SensorManager.SENSOR_DELAY_NORMAL,
                60_000_000
            )
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.getStringExtra("action") == "date_changed") {
            handleDateChanged()
        } else {
            cachedTodaySteps = prefs.getSafeInt(PREF_KEY_TODAY_STEPS, cachedTodaySteps)
            updateNotification(cachedTodaySteps)
        }
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        sensorManager?.unregisterListener(this)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null || event.values.isEmpty()) return
        val rawHardwareSteps = event.values[0].toInt()
        latestHardwareSteps = rawHardwareSteps

        val now = Date()
        val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(now)
        var savedDate = prefs.getString(PREF_KEY_DATE, todayStr) ?: todayStr
        var baseline = prefs.getSafeInt(PREF_KEY_BASELINE, -1)
        var rebootOffset = prefs.getSafeInt(PREF_KEY_REBOOT_OFFSET, 0)
        var savedTodaySteps = prefs.getSafeInt(PREF_KEY_TODAY_STEPS, 0)

        // 1. Midnight Rollover in Background
        if (savedDate != todayStr) {
            savedDate = todayStr
            baseline = rawHardwareSteps
            rebootOffset = 0
            savedTodaySteps = 0
            cachedTodaySteps = 0

            prefs.edit()
                .putString(PREF_KEY_DATE, todayStr)
                .putSafeLong(PREF_KEY_BASELINE, baseline)
                .putSafeLong(PREF_KEY_REBOOT_OFFSET, 0)
                .putSafeLong(PREF_KEY_TODAY_STEPS, 0)
                .putSafeLong(PREF_KEY_LAST_HW_STEPS, rawHardwareSteps)
                .apply()

            updateNotification(0)
            return
        }

        // 2. Initial Baseline
        if (baseline == -1) {
            baseline = rawHardwareSteps
            prefs.edit()
                .putSafeLong(PREF_KEY_BASELINE, baseline)
                .putString(PREF_KEY_DATE, todayStr)
                .apply()
        }

        // 3. Device Reboot Detection
        if (rawHardwareSteps < baseline) {
            rebootOffset += savedTodaySteps
            baseline = 0
            prefs.edit()
                .putSafeLong(PREF_KEY_REBOOT_OFFSET, rebootOffset)
                .putSafeLong(PREF_KEY_BASELINE, baseline)
                .apply()
        }

        // 4. Calculate Today's Steps
        val delta = if (rawHardwareSteps >= baseline) rawHardwareSteps - baseline else 0
        val newTodaySteps = rebootOffset + delta

        if (newTodaySteps >= cachedTodaySteps) {
            cachedTodaySteps = newTodaySteps
            prefs.edit()
                .putSafeLong(PREF_KEY_TODAY_STEPS, cachedTodaySteps)
                .putSafeLong(PREF_KEY_LAST_HW_STEPS, rawHardwareSteps)
                .apply()

            updateNotification(cachedTodaySteps)
        }
    }

    private fun handleDateChanged() {
        val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        val savedDate = prefs.getString(PREF_KEY_DATE, todayStr) ?: todayStr
        if (savedDate != todayStr) {
            val raw = if (latestHardwareSteps > 0) latestHardwareSteps else prefs.getSafeInt(PREF_KEY_LAST_HW_STEPS, 0)
            prefs.edit()
                .putString(PREF_KEY_DATE, todayStr)
                .putSafeLong(PREF_KEY_BASELINE, raw)
                .putSafeLong(PREF_KEY_REBOOT_OFFSET, 0)
                .putSafeLong(PREF_KEY_TODAY_STEPS, 0)
                .apply()
            cachedTodaySteps = 0
            updateNotification(0)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "BloomWell Step Tracker",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps daily step counting active when your screen is off"
                setShowBadge(false)
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(steps: Int): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = if (launchIntent != null) {
            PendingIntent.getActivity(
                this,
                0,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        } else null

        val goal = prefs.getSafeInt(PREF_KEY_GOAL, 6000)
        val title = "BloomWell Step Tracker"
        val text = "Today: $steps steps • Goal: $goal • Low-impact wellness"

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun updateNotification(steps: Int) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIFICATION_ID, buildNotification(steps))
    }
}
