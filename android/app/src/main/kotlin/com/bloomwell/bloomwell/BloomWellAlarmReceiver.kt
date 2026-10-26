package com.bloomwell.bloomwell

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.database.sqlite.SQLiteDatabase
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class BloomWellAlarmReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BloomWellAlarmReceiver"

        const val ACTION_WATER_REMINDER = "com.bloomwell.bloomwell.ACTION_WATER_REMINDER"
        const val ACTION_WAKE_ALARM = "com.bloomwell.bloomwell.ACTION_WAKE_ALARM"
        const val ACTION_CLASS_END_CATCHUP = "com.bloomwell.bloomwell.ACTION_CLASS_END_CATCHUP"
        const val ACTION_STOP_ALARM = "com.bloomwell.bloomwell.ACTION_STOP_ALARM"

        // State Machine constants
        const val STATE_SCHEDULED = "SCHEDULED"
        const val STATE_RINGING = "RINGING"
        const val STATE_AWAITING_CONFIRMATION = "AWAITING_CONFIRMATION"
        const val STATE_COMPLETED = "COMPLETED"

        // Upgraded channel IDs with single-owner audio lifecycle
        const val CHANNEL_WATER = "water_reminders_v2"
        const val CHANNEL_ALARM = "wake_alarm_v2"

        const val NOTIFICATION_ID_WATER = 101
        const val NOTIFICATION_ID_ALARM = 201

        const val REQUEST_CODE_WATER = 1001
        const val REQUEST_CODE_ALARM = 2001
        const val REQUEST_CODE_CLASS_END = 3001

        const val EXTRA_OPEN_FLOW = "open_flow"
        const val EXTRA_REMINDER_ID = "reminder_id"
        const val FLOW_SELFIE = "selfie_verification"
        const val FLOW_WATER_SCREEN = "water_screen"

        const val PREFS_NAME = "FlutterSharedPreferences"
        const val PREF_WATER_REMINDER_STATE = "flutter.water_reminder_state"
        const val PREF_WATER_REMINDER_ID = "flutter.water_reminder_id"
        const val PREF_WATER_REMINDER_DUE_MS = "flutter.water_reminder_due_time_ms"
        const val PREF_NEXT_REMINDER_ISO = "flutter.bloomwell_next_water_reminder_at"
        const val PREF_REMINDER_INTERVAL = "flutter.bloomwell_water_reminder_interval"
        const val PREF_WAKE_TIME = "flutter.bloomwell_wake_time"
        const val PREF_BEDTIME = "flutter.bloomwell_bedtime"
        const val PREF_COLLEGE_GOING = "flutter.college_going"
        const val PREF_COLLEGE_START = "flutter.college_start_time"
        const val PREF_COLLEGE_END = "flutter.college_end_time"
        const val PREF_CLASS_HAS_CLASSES = "flutter.class_has_classes"
        const val PREF_CLASS_START = "flutter.class_start_time"
        const val PREF_CLASS_END = "flutter.class_end_time"
        const val PREF_CLASS_DATE = "flutter.class_schedule_date"
        const val PREF_WATER_DEFERRED = "flutter.water_reminder_deferred"

        fun createNotificationChannels(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

                val soundUri = Uri.parse("android.resource://${context.packageName}/raw/mixkit_alarm")
                val alarmAudioAttributes = AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .build()

                // 1. Water Reminders Channel (AlarmSoundManager owns the looping audio playback; channel is silent to avoid dual sound)
                val waterChannel = NotificationChannel(
                    CHANNEL_WATER,
                    "Water Reminders",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Mindful hydration reminders with photo confirmation"
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 350, 200, 350)
                    setSound(null, null)
                    lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
                }
                nm.createNotificationChannel(waterChannel)

                // 2. Wake-Up Alarm Channel (Custom mixkit sound, max importance, bypass DND)
                val alarmChannel = NotificationChannel(
                    CHANNEL_ALARM,
                    "Wake-Up Alarm",
                    NotificationManager.IMPORTANCE_MAX
                ).apply {
                    description = "Local wake up alarm with selfie verification"
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 500, 400, 500, 400, 500)
                    setSound(soundUri, alarmAudioAttributes)
                    lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
                    setBypassDnd(true)
                }
                nm.createNotificationChannel(alarmChannel)
            }
        }

        fun scheduleWaterReminder(
            context: Context,
            triggerAtMillis: Long,
            intervalMinutes: Int,
            reminderId: String? = null
        ) {
            createNotificationChannels(context)
            val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val rId = reminderId ?: "water_$triggerAtMillis"

            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putString(PREF_WATER_REMINDER_STATE, STATE_SCHEDULED)
                .putString(PREF_WATER_REMINDER_ID, rId)
                .putString(PREF_WATER_REMINDER_DUE_MS, triggerAtMillis.toString())
                .putLong(PREF_REMINDER_INTERVAL, intervalMinutes.toLong())
                .apply()

            val intent = Intent(context, BloomWellAlarmReceiver::class.java).apply {
                action = ACTION_WATER_REMINDER
                putExtra("interval_minutes", intervalMinutes)
                putExtra(EXTRA_REMINDER_ID, rId)
            }
            val pi = PendingIntent.getBroadcast(
                context,
                REQUEST_CODE_WATER,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
                } else {
                    am.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
                }
                Log.d(TAG, "Water reminder $rId scheduled at $triggerAtMillis ($intervalMinutes mins)")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to schedule exact water reminder: ${e.message}")
            }
        }

        fun cancelWaterReminder(context: Context) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, BloomWellAlarmReceiver::class.java).apply {
                action = ACTION_WATER_REMINDER
            }
            val pi = PendingIntent.getBroadcast(
                context,
                REQUEST_CODE_WATER,
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            if (pi != null) {
                am.cancel(pi)
                pi.cancel()
            }
        }

        fun completeWaterReminder(
            context: Context,
            reminderId: String?,
            nextDeadlineMs: Long,
            intervalMinutes: Int
        ) {
            Log.d(TAG, "completeWaterReminder called for session: $reminderId")

            // 1. Stop audio for this session
            AlarmSoundManager.stopAlarm(reminderId)

            // 2. Dismiss water notification
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            nm?.cancel(NOTIFICATION_ID_WATER)

            // 3. Mark completed in state machine
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putString(PREF_WATER_REMINDER_STATE, STATE_COMPLETED)
                .remove(PREF_WATER_REMINDER_ID)
                .remove(PREF_WATER_REMINDER_DUE_MS)
                .apply()

            // 4. Schedule next water reminder
            val nextIso = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US).format(Date(nextDeadlineMs))
            prefs.edit().putString(PREF_NEXT_REMINDER_ISO, nextIso).apply()
            scheduleWaterReminder(context, nextDeadlineMs, intervalMinutes)
        }

        fun scheduleWakeAlarm(context: Context, hour: Int, minute: Int) {
            createNotificationChannels(context)
            val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return

            val now = Calendar.getInstance()
            val target = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                if (before(now)) {
                    add(Calendar.DAY_OF_YEAR, 1)
                }
            }

            val intent = Intent(context, BloomWellAlarmReceiver::class.java).apply {
                action = ACTION_WAKE_ALARM
                putExtra("hour", hour)
                putExtra("minute", minute)
            }
            val pi = PendingIntent.getBroadcast(
                context,
                REQUEST_CODE_ALARM,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, target.timeInMillis, pi)
                } else {
                    am.setExact(AlarmManager.RTC_WAKEUP, target.timeInMillis, pi)
                }
                Log.d(TAG, "Wake alarm scheduled for ${target.time}")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to schedule exact wake alarm: ${e.message}")
            }
        }

        fun cancelWakeAlarm(context: Context) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, BloomWellAlarmReceiver::class.java).apply {
                action = ACTION_WAKE_ALARM
            }
            val pi = PendingIntent.getBroadcast(
                context,
                REQUEST_CODE_ALARM,
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            if (pi != null) {
                am.cancel(pi)
                pi.cancel()
            }
        }

        fun cancelClassEndCatchup(context: Context) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, BloomWellAlarmReceiver::class.java).apply {
                action = ACTION_CLASS_END_CATCHUP
            }
            val pi = PendingIntent.getBroadcast(
                context,
                REQUEST_CODE_CLASS_END,
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            if (pi != null) {
                am.cancel(pi)
                pi.cancel()
            }
        }

        fun cancelAllAlarms(context: Context) {
            Log.d(TAG, "Cancelling all alarms, water reminders, and notifications.")
            cancelWaterReminder(context)
            cancelWakeAlarm(context)
            cancelClassEndCatchup(context)

            // Stop any active audio alarm
            AlarmSoundManager.stopAlarm()

            // Dismiss notifications
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            nm?.cancel(NOTIFICATION_ID_WATER)
            nm?.cancel(NOTIFICATION_ID_ALARM)

            // Clear obsolete reminder scheduling metadata and reset state to COMPLETED
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putString(PREF_WATER_REMINDER_STATE, STATE_COMPLETED)
                .remove(PREF_WATER_REMINDER_ID)
                .remove(PREF_WATER_REMINDER_DUE_MS)
                .remove(PREF_NEXT_REMINDER_ISO)
                .remove(PREF_REMINDER_INTERVAL)
                .remove(PREF_WAKE_TIME)
                .remove(PREF_BEDTIME)
                .remove(PREF_CLASS_DATE)
                .remove(PREF_COLLEGE_GOING)
                .remove(PREF_COLLEGE_START)
                .remove(PREF_COLLEGE_END)
                .remove(PREF_CLASS_HAS_CLASSES)
                .remove(PREF_CLASS_START)
                .remove(PREF_CLASS_END)
                .remove(PREF_WATER_DEFERRED)
                .apply()
        }

        fun scheduleClassEndCatchup(context: Context, endMillis: Long) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, BloomWellAlarmReceiver::class.java).apply {
                action = ACTION_CLASS_END_CATCHUP
            }
            val pi = PendingIntent.getBroadcast(
                context,
                REQUEST_CODE_CLASS_END,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, endMillis, pi)
                } else {
                    am.setExact(AlarmManager.RTC_WAKEUP, endMillis, pi)
                }
                Log.d(TAG, "Class end catchup scheduled for $endMillis")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to schedule class end catchup: ${e.message}")
            }
        }

        fun isSleepActive(context: Context, atMillis: Long = System.currentTimeMillis()): Boolean {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val bedtimeStr = prefs.getString(PREF_BEDTIME, "23:00") ?: "23:00"
            val wakeTimeStr = prefs.getString(PREF_WAKE_TIME, "07:00") ?: "07:00"

            return try {
                val bedParts = bedtimeStr.split(":")
                val wakeParts = wakeTimeStr.split(":")
                val bedMinutes = bedParts[0].toInt() * 60 + bedParts[1].toInt()
                val wakeMinutes = wakeParts[0].toInt() * 60 + wakeParts[1].toInt()

                val cal = Calendar.getInstance().apply { timeInMillis = atMillis }
                val targetMinutes = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)

                if (bedMinutes <= wakeMinutes) {
                    targetMinutes in bedMinutes until wakeMinutes
                } else {
                    // Crossing midnight (e.g. 23:00 to 07:00)
                    targetMinutes >= bedMinutes || targetMinutes < wakeMinutes
                }
            } catch (_: Exception) {
                false
            }
        }

        fun getNextWakeTimeMillis(context: Context, fromMillis: Long = System.currentTimeMillis()): Long {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val wakeTimeStr = prefs.getString(PREF_WAKE_TIME, "07:00") ?: "07:00"

            return try {
                val wakeParts = wakeTimeStr.split(":")
                val hour = wakeParts[0].toInt()
                val minute = wakeParts[1].toInt()

                val fromCal = Calendar.getInstance().apply { timeInMillis = fromMillis }
                val target = Calendar.getInstance().apply {
                    timeInMillis = fromMillis
                    set(Calendar.HOUR_OF_DAY, hour)
                    set(Calendar.MINUTE, minute)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                    if (!after(fromCal)) {
                        add(Calendar.DAY_OF_YEAR, 1)
                    }
                }
                target.timeInMillis
            } catch (_: Exception) {
                fromMillis + 8 * 3600 * 1000L
            }
        }

        private fun isTimeInInterval(timeMinutes: Int, startStr: String?, endStr: String?): Boolean {
            if (startStr.isNullOrEmpty() || endStr.isNullOrEmpty()) return false
            return try {
                val startParts = startStr.split(":")
                val endParts = endStr.split(":")
                val start = startParts[0].toInt() * 60 + startParts[1].toInt()
                val end = endParts[0].toInt() * 60 + endParts[1].toInt()

                if (start <= end) {
                    timeMinutes in start until end
                } else {
                    timeMinutes >= start || timeMinutes < end
                }
            } catch (_: Exception) {
                false
            }
        }

        private fun parseMinutes(timeStr: String?): Int {
            if (timeStr.isNullOrEmpty()) return -1
            return try {
                val parts = timeStr.split(":")
                parts[0].toInt() * 60 + parts[1].toInt()
            } catch (_: Exception) {
                -1
            }
        }

        fun isCollegeOrClassActive(context: Context, atMillis: Long = System.currentTimeMillis()): Boolean {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date(atMillis))
            val scheduleDate = prefs.getString(PREF_CLASS_DATE, "") ?: ""

            if (scheduleDate != todayStr) return false

            val cal = Calendar.getInstance().apply { timeInMillis = atMillis }
            val nowMinutes = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)

            // 1. Check Classes interval independently if enabled
            val hasClasses = prefs.getBoolean(PREF_CLASS_HAS_CLASSES, false)
            if (hasClasses) {
                val classStart = prefs.getString(PREF_CLASS_START, null)
                val classEnd = prefs.getString(PREF_CLASS_END, null)
                if (isTimeInInterval(nowMinutes, classStart, classEnd)) {
                    return true
                }
            }

            // 2. Check College interval independently if going to college is enabled
            val goingCollege = prefs.getBoolean(PREF_COLLEGE_GOING, false)
            if (goingCollege) {
                val collegeStart = prefs.getString(PREF_COLLEGE_START, null)
                val collegeEnd = prefs.getString(PREF_COLLEGE_END, null)
                if (isTimeInInterval(nowMinutes, collegeStart, collegeEnd)) {
                    return true
                }
            }

            return false
        }

        fun calculateNextUnsuppressedReminderTime(context: Context, candidateMillis: Long, intervalMinutes: Int): Long {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            var target = candidateMillis
            var attempts = 0

            while (attempts < 10) {
                attempts++
                // 1. Check sleep
                if (isSleepActive(context, target)) {
                    val wakeTime = getNextWakeTimeMillis(context, target)
                    target = wakeTime
                    continue
                }

                // 2. Check college/class
                if (isCollegeOrClassActive(context, target)) {
                    val cal = Calendar.getInstance().apply { timeInMillis = target }
                    val nowMinutes = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)

                    var latestEndMinutes = -1
                    val goingCollege = prefs.getBoolean(PREF_COLLEGE_GOING, false)
                    if (goingCollege) {
                        val colStart = prefs.getString(PREF_COLLEGE_START, null)
                        val colEnd = prefs.getString(PREF_COLLEGE_END, null)
                        if (isTimeInInterval(nowMinutes, colStart, colEnd)) {
                            val endM = parseMinutes(colEnd)
                            if (endM > latestEndMinutes) latestEndMinutes = endM
                        }
                    }

                    val hasClasses = prefs.getBoolean(PREF_CLASS_HAS_CLASSES, false)
                    if (hasClasses) {
                        val clsStart = prefs.getString(PREF_CLASS_START, null)
                        val clsEnd = prefs.getString(PREF_CLASS_END, null)
                        if (isTimeInInterval(nowMinutes, clsStart, clsEnd)) {
                            val endM = parseMinutes(clsEnd)
                            if (endM > latestEndMinutes) latestEndMinutes = endM
                        }
                    }

                    if (latestEndMinutes > 0) {
                        cal.set(Calendar.HOUR_OF_DAY, latestEndMinutes / 60)
                        cal.set(Calendar.MINUTE, latestEndMinutes % 60)
                        cal.set(Calendar.SECOND, 0)
                        cal.set(Calendar.MILLISECOND, 0)
                        target = cal.timeInMillis
                        continue
                    }
                }

                // Neither sleep nor college/class active at target
                break
            }
            return target
        }

        fun showWaterNotification(context: Context, title: String, body: String, reminderId: String) {
            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra(EXTRA_OPEN_FLOW, FLOW_WATER_SCREEN)
                putExtra(EXTRA_REMINDER_ID, reminderId)
            }
            val openAppPendingIntent = PendingIntent.getActivity(
                context,
                1011,
                openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val notification = NotificationCompat.Builder(context, CHANNEL_WATER)
                .setContentTitle(title)
                .setContentText(body)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setOngoing(true)
                .setAutoCancel(false)
                .setContentIntent(openAppPendingIntent)
                .setFullScreenIntent(openAppPendingIntent, true)
                .build()

            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(NOTIFICATION_ID_WATER, notification)
        }
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        Log.d(TAG, "onReceive action: $action")
        createNotificationChannels(context)

        when (action) {
            ACTION_WATER_REMINDER -> handleWaterReminder(context, intent)
            ACTION_CLASS_END_CATCHUP -> handleClassEndCatchup(context)
            ACTION_WAKE_ALARM -> handleWakeAlarm(context, intent)
            ACTION_STOP_ALARM -> handleStopAlarm(context)
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.LOCKED_BOOT_COMPLETED",
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> handleBootOrTimeChanged(context)
        }
    }

    private fun handleWaterReminder(context: Context, intent: Intent) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isOnboarded = prefs.getBoolean("flutter.bloomwell_onboarding_completed", false)
        if (!isOnboarded) {
            Log.w(TAG, "Suppressed stale water reminder: user is not onboarded or app data was reset.")
            cancelWaterReminder(context)
            return
        }

        val intervalMinutes = intent.getIntExtra("interval_minutes", prefs.getSafeInt(PREF_REMINDER_INTERVAL, 30))
        val reminderId = intent.getStringExtra(EXTRA_REMINDER_ID) ?: "water_${System.currentTimeMillis()}"

        // 1. Sleep Schedule Suppression
        if (isSleepActive(context)) {
            Log.d(TAG, "Sleep is active. Suppressing water reminder and scheduling at wake time.")
            val nextWakeMs = getNextWakeTimeMillis(context)
            val nextIso = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US).format(Date(nextWakeMs))
            prefs.edit().putString(PREF_NEXT_REMINDER_ISO, nextIso).apply()
            scheduleWaterReminder(context, nextWakeMs, intervalMinutes)
            return
        }

        // 2. College / Class Schedule Suppression
        if (isCollegeOrClassActive(context)) {
            Log.d(TAG, "Class or College is active. Suppressing alert and resuming after interval.")
            val nextDeadline = calculateNextUnsuppressedReminderTime(context, System.currentTimeMillis(), intervalMinutes)
            val nextIso = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US).format(Date(nextDeadline))
            prefs.edit().putString(PREF_NEXT_REMINDER_ISO, nextIso).apply()
            scheduleWaterReminder(context, nextDeadline, intervalMinutes)
            return
        }

        // 3. Normal waking hours alert: transition state to RINGING -> AWAITING_CONFIRMATION
        prefs.edit()
            .putString(PREF_WATER_REMINDER_STATE, STATE_RINGING)
            .putString(PREF_WATER_REMINDER_ID, reminderId)
            .putString(PREF_WATER_REMINDER_DUE_MS, System.currentTimeMillis().toString())
            .apply()

        // Start owned alarm sound session
        AlarmSoundManager.playAlarm(context, reminderId)

        // Show persistent high-priority notification with full-screen intent
        showWaterNotification(
            context,
            title = "Time to drink water!",
            body = "Confirm your mindful sip with a bottle photo.",
            reminderId = reminderId
        )

        prefs.edit()
            .putString(PREF_WATER_REMINDER_STATE, STATE_AWAITING_CONFIRMATION)
            .apply()

        // Notify active Flutter activity
        MainActivity.notifyWaterReminderTriggered(reminderId)

        // Strict idempotency: Do NOT reschedule the next water reminder here!
        // The next reminder will be scheduled ONLY after water log is committed in SQLite.
    }

    private fun handleClassEndCatchup(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (isSleepActive(context)) return

        // Resume water reminder according to schedule without replaying a backlog
        val intervalMinutes = prefs.getSafeInt(PREF_REMINDER_INTERVAL, 30)
        val candidateDeadline = System.currentTimeMillis() + intervalMinutes * 60 * 1000L
        val nextDeadline = calculateNextUnsuppressedReminderTime(context, candidateDeadline, intervalMinutes)
        val nextIso = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US).format(Date(nextDeadline))
        prefs.edit().putString(PREF_NEXT_REMINDER_ISO, nextIso).apply()
        scheduleWaterReminder(context, nextDeadline, intervalMinutes)
    }

    private fun handleWakeAlarm(context: Context, intent: Intent) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isOnboarded = prefs.getBoolean("flutter.bloomwell_onboarding_completed", false)
        if (!isOnboarded) {
            Log.w(TAG, "Suppressed stale wake alarm: user is not onboarded or app data was reset.")
            cancelWakeAlarm(context)
            return
        }

        // Start audible alarm with mixkit sound
        AlarmSoundManager.playAlarm(context, "wake_alarm")

        // Full screen intent to open MainActivity with selfie verification flow
        val selfieIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(EXTRA_OPEN_FLOW, FLOW_SELFIE)
        }
        val selfiePendingIntent = PendingIntent.getActivity(
            context,
            2011,
            selfieIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ALARM)
            .setContentTitle("BloomWell Wake-Up Alarm")
            .setContentText("Good morning! It's time to wake up and start your day.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(selfiePendingIntent)
            .setFullScreenIntent(selfiePendingIntent, true)
            .addAction(0, "I’m Awake — Verify", selfiePendingIntent)
            .build()

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIFICATION_ID_ALARM, notification)

        // Reschedule tomorrow's alarm
        val hour = intent.getIntExtra("hour", 7)
        val minute = intent.getIntExtra("minute", 0)
        scheduleWakeAlarm(context, hour, minute)
    }

    private fun handleStopAlarm(context: Context) {
        AlarmSoundManager.stopAlarm()
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(NOTIFICATION_ID_ALARM)
        nm.cancel(NOTIFICATION_ID_WATER)
    }

    private fun handleBootOrTimeChanged(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isOnboarded = prefs.getBoolean("flutter.bloomwell_onboarding_completed", false)
        if (!isOnboarded) {
            Log.d(TAG, "Device rebooted or time changed, but user is not onboarded. Cancelling lingering alarms.")
            cancelAllAlarms(context)
            return
        }

        Log.d(TAG, "Device rebooted or time changed. Recovering state...")
        val currentState = prefs.getString(PREF_WATER_REMINDER_STATE, STATE_COMPLETED)
        if (currentState == STATE_AWAITING_CONFIRMATION || currentState == STATE_RINGING) {
            val reminderId = prefs.getString(PREF_WATER_REMINDER_ID, null) ?: "water_${System.currentTimeMillis()}"
            showWaterNotification(
                context,
                title = "Time to drink water!",
                body = "Confirm your mindful sip with a bottle photo.",
                reminderId = reminderId
            )
            // Recover pending confirmation state without duplicating sound or auto-completing
        } else {
            val interval = prefs.getSafeInt(PREF_REMINDER_INTERVAL, 30)
            val nextIso = prefs.getString(PREF_NEXT_REMINDER_ISO, null)
            var deadlineMs = System.currentTimeMillis() + interval * 60 * 1000L
            if (nextIso != null) {
                try {
                    val parsed = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US).parse(nextIso.substring(0, 19))
                    if (parsed != null && parsed.time > System.currentTimeMillis()) {
                        deadlineMs = parsed.time
                    }
                } catch (_: Exception) {}
            }
            val targetMs = calculateNextUnsuppressedReminderTime(context, deadlineMs, interval)
            scheduleWaterReminder(context, targetMs, interval)
        }

        // Reschedule wake alarm
        val wakeTimeStr = prefs.getString(PREF_WAKE_TIME, "07:00") ?: "07:00"
        try {
            val parts = wakeTimeStr.split(":")
            if (parts.size == 2) {
                scheduleWakeAlarm(context, parts[0].toInt(), parts[1].toInt())
            }
        } catch (_: Exception) {}
    }
}
