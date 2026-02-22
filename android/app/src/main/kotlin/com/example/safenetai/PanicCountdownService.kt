package com.example.safenetai

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.CountDownTimer
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.FirebaseApp
import com.google.firebase.Timestamp
import com.google.firebase.firestore.FirebaseFirestore

class PanicCountdownService : Service() {

    private var countDownTimer: CountDownTimer? = null
    private val CHANNEL_ID = "panic_countdown_channel"
    private val NOTIF_ID = 7777
    private var secondsLeft = 10

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_CANCEL) {
            Log.d("PanicCountdown", "User cancelled panic alert!")
            cancelCountdown()
            return START_NOT_STICKY
        }

        Log.d("PanicCountdown", "Starting 10-second panic countdown")
        secondsLeft = 10
        showCountdownNotification(secondsLeft)
        startCountdown()
        return START_NOT_STICKY
    }

    private fun startCountdown() {
        countDownTimer = object : CountDownTimer(10_000L, 1_000L) {
            override fun onTick(millisUntilFinished: Long) {
                secondsLeft = (millisUntilFinished / 1000).toInt() + 1
                showCountdownNotification(secondsLeft)
                Log.d("PanicCountdown", "Panic in ${secondsLeft}s...")
            }

            override fun onFinish() {
                Log.d("PanicCountdown", "Countdown finished — sending panic alert!")
                dismissNotification()
                sendPanicToFirestore()
                broadcastPanicToFlutter()
                stopSelf()
            }
        }.start()
    }

    private fun cancelCountdown() {
        countDownTimer?.cancel()
        dismissNotification()
        Log.d("PanicCountdown", "Panic cancelled by user.")
        stopSelf()
    }

    private fun showCountdownNotification(seconds: Int) {
        // Cancel intent → tapping the notification itself cancels panic
        val cancelIntent = Intent(this, PanicCountdownService::class.java).apply {
            action = ACTION_CANCEL
        }
        val cancelPendingIntent = PendingIntent.getService(
            this, 0, cancelIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("🚨 Panic Alert in ${seconds}s")
            .setContentText("Tap CANCEL to stop. Alert sends automatically in ${seconds} seconds.")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "❌ CANCEL PANIC",
                cancelPendingIntent
            )
            .build()

        startForeground(NOTIF_ID, notification)
    }

    private fun dismissNotification() {
        val nm = getSystemService(NotificationManager::class.java)
        nm?.cancel(NOTIF_ID)
        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    private fun sendPanicToFirestore() {
        try {
            FirebaseApp.initializeApp(this)
            val db = FirebaseFirestore.getInstance()

            // Read resident context stored by Flutter via setPanicContext
            val prefs = getSharedPreferences("SafeNetPrefs", Context.MODE_PRIVATE)
            val residentId = prefs.getString("residentId", "") ?: ""
            val flatNumber = prefs.getString("flatNumber", "") ?: ""
            val buildingNumber = prefs.getString("buildingNumber", "") ?: ""
            val blockName = prefs.getString("blockName", "") ?: ""
            val residentName = prefs.getString("residentName", "Unknown") ?: "Unknown"
            val phone = prefs.getString("phone", "") ?: ""

            val panicData = hashMapOf(
                "requestType" to "panic_alert",
                "status" to "pending",
                "priority" to "urgent",
                "triggeredBy" to "volume_button",
                "timestamp" to Timestamp.now(),
                "residentId" to residentId,
                "residentName" to residentName,
                "flatNumber" to flatNumber,
                "buildingNumber" to buildingNumber,
                "block" to blockName,
                "phone" to phone
            )

            db.collection("security_requests")
                .add(panicData)
                .addOnSuccessListener { ref ->
                    Log.d("PanicCountdown", "Panic written to Firestore: ${ref.id}")
                }
                .addOnFailureListener { e ->
                    Log.e("PanicCountdown", "Firestore write failed: ${e.message}")
                }
        } catch (e: Exception) {
            Log.e("PanicCountdown", "Error writing to Firestore: ${e.message}")
        }
    }

    private fun broadcastPanicToFlutter() {
        try {
            val broadcastIntent = Intent("com.example.safenetai.PANIC_TRIGGERED")
            broadcastIntent.setPackage(packageName)
            sendBroadcast(broadcastIntent)
            Log.d("PanicCountdown", "Broadcast sent to Flutter")
        } catch (e: Exception) {
            Log.e("PanicCountdown", "Broadcast failed: ${e.message}")
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Panic Countdown",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Panic alert countdown timer"
                enableVibration(false)
                setSound(null, null) // Silent — vibration from AccessibilityService is enough
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm?.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        countDownTimer?.cancel()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val ACTION_CANCEL = "ACTION_CANCEL_PANIC"
    }
}
