package com.bloomwell.bloomwell

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class MidnightRolloverReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        if (action == Intent.ACTION_DATE_CHANGED ||
            action == Intent.ACTION_TIMEZONE_CHANGED ||
            action == Intent.ACTION_TIME_CHANGED ||
            action == "android.intent.action.TIME_SET") {
            
            if (StepCounterForegroundService.isRunning) {
                val serviceIntent = Intent(context, StepCounterForegroundService::class.java).apply {
                    putExtra("action", "date_changed")
                }
                context.startService(serviceIntent)
            }
        }
    }
}
