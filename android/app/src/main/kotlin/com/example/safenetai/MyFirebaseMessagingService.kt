package com.example.safenetai

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

class MyFirebaseMessagingService : FlutterFirebaseMessagingService() {

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        // ALWAYS let Flutter handle it as well (for foreground state)
        super.onMessageReceived(remoteMessage)

        val data = remoteMessage.data
        if (data.isEmpty()) return

        val type = data["type"]
        val priority = data["priority"]?.lowercase() ?: "normal"
        val title = data["title"] ?: "SafeNet AI"
        val body = data["body"] ?: ""

        when {
            type == "panic_alert" || priority == "urgent" -> {
                // Native Siren handles urgent — show full screen alarm
                startSirenService(title, body)
            }
            else -> {
                // For normal/medium — show a system-tray notification natively
                // This fires even in killed state without needing Flutter engine
                showLocalNotification(title, body, priority)
            }
        }
    }

    private fun showLocalNotification(title: String, body: String, priority: String) {
        try {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channelId = if (priority == "medium") "medium_security_channel_v6" else "normal_security_channel_v6"
            val channelName = if (priority == "medium") "Medium Security Updates" else "Normal Updates"
            val importance = if (priority == "medium") NotificationManager.IMPORTANCE_HIGH else NotificationManager.IMPORTANCE_DEFAULT

            // Ensure the channel exists (safe to call repeatedly)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(channelId, channelName, importance)
                notificationManager.createNotificationChannel(channel)
            }

            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            val pendingIntent = PendingIntent.getActivity(
                this, 0, launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val notification = NotificationCompat.Builder(this, channelId)
                .setContentTitle(title)
                .setContentText(body)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setPriority(if (priority == "medium") NotificationCompat.PRIORITY_HIGH else NotificationCompat.PRIORITY_DEFAULT)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .build()

            notificationManager.notify(System.currentTimeMillis().toInt(), notification)
        } catch (e: Exception) {
            Log.e("SafeNet", "Error showing local notification: ${e.message}")
        }
    }

    private fun startSirenService(title: String, body: String) {
        try {
            val intent = Intent(this, SirenForegroundService::class.java).apply {
                putExtra("title", title)
                putExtra("body", body)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (e: Exception) {
            Log.e("SafeNet", "Error starting siren: ${e.message}")
        }
    }
}
