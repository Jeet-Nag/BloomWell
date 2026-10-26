package com.bloomwell.bloomwell

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.util.Log

object AlarmSoundManager {
    private const val TAG = "AlarmSoundManager"

    @Volatile
    private var mediaPlayer: MediaPlayer? = null

    @Volatile
    var isAlarmActive: Boolean = false
        private set

    @Volatile
    var activeSessionId: String? = null
        private set

    @Synchronized
    fun playAlarm(context: Context, sessionId: String = "default") {
        if (isAlarmActive && mediaPlayer?.isPlaying == true) {
            if (activeSessionId == sessionId) {
                Log.d(TAG, "Alarm sound is already playing for session $sessionId. Skipping duplicate start.")
                return
            }
            Log.d(TAG, "Switching alarm sound from session $activeSessionId to $sessionId.")
            stopAlarm()
        }

        stopAlarm()
        isAlarmActive = true
        activeSessionId = sessionId

        try {
            val appContext = context.applicationContext
            val resId = appContext.resources.getIdentifier("mixkit_alarm", "raw", appContext.packageName)
            if (resId != 0) {
                mediaPlayer = MediaPlayer.create(appContext, resId)?.apply {
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                    isLooping = true
                    start()
                }
                Log.d(TAG, "Playing supplied mixkit_alarm repeatedly for session $sessionId on USAGE_ALARM stream.")
            } else {
                Log.w(TAG, "Supplied raw/mixkit_alarm not found. Falling back to default.")
                val fallbackUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                if (fallbackUri != null) {
                    mediaPlayer = MediaPlayer().apply {
                        setDataSource(appContext, fallbackUri)
                        setAudioAttributes(
                            AudioAttributes.Builder()
                                .setUsage(AudioAttributes.USAGE_ALARM)
                                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                .build()
                        )
                        isLooping = true
                        prepare()
                        start()
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start alarm sound for session $sessionId: ${e.message}", e)
        }
    }

    @Synchronized
    fun stopAlarm(sessionId: String? = null) {
        if (sessionId != null && activeSessionId != null && activeSessionId != sessionId) {
            Log.d(TAG, "Ignoring stopAlarm for session $sessionId because current activeSessionId is $activeSessionId")
            return
        }

        isAlarmActive = false
        activeSessionId = null
        try {
            mediaPlayer?.let {
                if (it.isPlaying) {
                    it.stop()
                }
                it.reset()
                it.release()
            }
            mediaPlayer = null
            Log.d(TAG, "Alarm sound stopped and media player released (requested for $sessionId).")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping alarm sound: ${e.message}")
        }
    }
}
