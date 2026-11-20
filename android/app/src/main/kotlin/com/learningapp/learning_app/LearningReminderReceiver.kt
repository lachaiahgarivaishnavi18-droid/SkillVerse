package com.learningapp.learning_app

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import java.util.Calendar

class LearningReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == LearningReminders.reminderAction) {
            LearningReminders.deliver(context)
        }
        LearningReminders.schedule(context)
    }
}

internal object LearningReminders {
    const val reminderAction = "com.learningapp.learning_app.LEARNING_REMINDER"
    private const val settingsName = "skillverse_learning_reminders"
    private const val channelId = "learning_reminders"
    private const val notificationId = 3151
    private const val alarmRequest = 3152

    private fun preferences(context: Context) = context.getSharedPreferences(
        settingsName, Context.MODE_PRIVATE
    )

    private fun notifications(context: Context) =
        context.getSystemService(NotificationManager::class.java)

    fun requiresPermission(context: Context): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED

    private fun canNotify(context: Context): Boolean {
        if (requiresPermission(context) || !notifications(context).areNotificationsEnabled()) {
            return false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = notifications(context).getNotificationChannel(channelId)
            if (channel?.importance == NotificationManager.IMPORTANCE_NONE) return false
        }
        return true
    }

    fun state(context: Context): Map<String, Any> {
        val saved = preferences(context)
        return mapOf(
            "enabled" to (saved.getBoolean("enabled", false) && canNotify(context)),
            "hour" to saved.getInt("hour", 19),
            "minute" to saved.getInt("minute", 0)
        )
    }

    fun update(context: Context, enabled: Boolean, hour: Int, minute: Int): Map<String, Any> {
        val allowed = enabled && canNotify(context)
        val saved = preferences(context).edit()
            .putBoolean("enabled", allowed)
            .putInt("hour", hour)
            .putInt("minute", minute)
            .commit()
        check(saved) { "Reminder settings could not be saved." }
        if (!allowed) notifications(context).cancel(notificationId)
        schedule(context)
        return state(context)
    }

    private fun alarmIntent(context: Context) =
        Intent(context, LearningReminderReceiver::class.java).setAction(reminderAction)

    fun schedule(context: Context) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        val settings = state(context)
        if (settings["enabled"] != true) {
            val pending = PendingIntent.getBroadcast(
                context, alarmRequest, alarmIntent(context),
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            if (pending != null) {
                alarms.cancel(pending)
                pending.cancel()
            }
            return
        }
        val now = System.currentTimeMillis()
        val next = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, settings["hour"] as Int)
            set(Calendar.MINUTE, settings["minute"] as Int)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= now) add(Calendar.DAY_OF_YEAR, 1)
        }
        val pending = PendingIntent.getBroadcast(
            context, alarmRequest, alarmIntent(context),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next.timeInMillis, pending)
    }

    fun deliver(context: Context) {
        if (state(context)["enabled"] != true) return
        val manager = notifications(context)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(NotificationChannel(
                channelId, "Learning reminders", NotificationManager.IMPORTANCE_DEFAULT
            ))
            Notification.Builder(context, channelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        val openApp = PendingIntent.getActivity(
            context, notificationId,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        manager.notify(notificationId, builder
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("Skillverse learning reminder")
            .setContentText("Continue a lesson or practice a few questions.")
            .setContentIntent(openApp)
            .setAutoCancel(true)
            .build())
    }
}
