package com.example.safenetai

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class PanicForegroundService : Service() {

    override fun onBind(intent: Intent?): IBinder? {
        return null // Not binding to activities
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createNotificationChannel()

        val notification: Notification = NotificationCompat.Builder(this, "panic_foreground_channel")
            .setContentTitle("SafeNet Security is Active")
            .setContentText("Emergency panic monitoring is securely running in the background.")
            .setSmallIcon(R.mipmap.ic_launcher) // Use the standard app icon
            .setPriority(NotificationCompat.PRIORITY_MIN) // To make it as unobtrusive as possible
            .build()

        startForeground(1101, notification)

        // If the OS kills the service, recreate it
        return START_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                "panic_foreground_channel",
                "SafeNet Background Protection",
                NotificationManager.IMPORTANCE_MIN
            )
            serviceChannel.description = "Ensures the Panic Button functions even when the app is closed."
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }
}
