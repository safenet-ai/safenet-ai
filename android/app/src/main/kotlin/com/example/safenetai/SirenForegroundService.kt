package com.example.safenetai

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log
import androidx.core.app.NotificationCompat

class SirenForegroundService : Service() {

    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private val CHANNEL_ID = "siren_channel"

    override fun onCreate() {
        super.onCreate()
        
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "ACTION_STOP_SIREN") {
            
            stopSelf()
            return START_NOT_STICKY
        }

        val title = intent?.getStringExtra("title") ?: "🚨 EMERGENCY PANIC ALERT 🚨"
        val body = intent?.getStringExtra("body") ?: "A panic alert has been triggered. Tap here or stop the alarm."

        val notification = createNotification(title, body)
        startForeground(999, notification)

        startSirenAndVibration()

        return START_STICKY
    }

    private fun startSirenAndVibration() {
        try {
            // Find sound in raw folder
            val resId = resources.getIdentifier("urgent_alarm", "raw", packageName)
            if (resId != 0) {
                mediaPlayer = MediaPlayer.create(this, resId)
                mediaPlayer?.isLooping = true
                val audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                mediaPlayer?.setAudioAttributes(audioAttributes)
                mediaPlayer?.start()
                
            } else {
                
            }
        } catch (e: Exception) {
            
        }

        try {
            vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            if (vibrator?.hasVibrator() == true) {
                val pattern = alongVibrationPattern()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0)) // 0 means repeat indefinitely
                } else {
                    @Suppress("DEPRECATION")
                    vibrator?.vibrate(pattern, 0)
                }
                
            }
        } catch (e: Exception) {
             
        }
    }

    private fun alongVibrationPattern(): LongArray {
        return longArrayOf(0, 500, 200, 500, 200, 1000)
    }

    override fun onDestroy() {
        
        try {
            mediaPlayer?.apply {
                if (isPlaying) stop()
                release()
            }
            mediaPlayer = null
        } catch (e: Exception) {
             
        }

        try {
            vibrator?.cancel()
            vibrator = null
        } catch (e: Exception) {
             
        }

        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "Siren Alert Channel",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                // No sound here — MediaPlayer handles the audio
                setSound(null, null)
                enableVibration(false)
                description = "Active emergency alert indicator"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }

    private fun createNotification(title: String, body: String): Notification {
        val stopIntent = Intent(this, SirenForegroundService::class.java).apply {
            action = "ACTION_STOP_SIREN"
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 0, stopIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val appIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val appPendingIntent = PendingIntent.getActivity(
            this, 0, appIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setFullScreenIntent(appPendingIntent, true)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "STOP SIREN", stopPendingIntent)
            .setAutoCancel(false)
            .setOngoing(true)
            .build()
    }
}
