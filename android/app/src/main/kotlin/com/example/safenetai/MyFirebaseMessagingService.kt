package com.example.safenetai

import android.content.Intent
import android.os.Build
import android.util.Log
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

class MyFirebaseMessagingService : FlutterFirebaseMessagingService() {

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        // ALWAYS let Flutter handle it as well
        super.onMessageReceived(remoteMessage)

        Log.d("MyFCMService", "Intercepted FCM Message Natively! ID: ${remoteMessage.messageId}")
        
        // Ensure data exists
        val data = remoteMessage.data
        if (data.isNotEmpty()) {
            val type = data["type"]
            val priority = data["priority"]
            Log.d("MyFCMService", "Message Type: $type, Priority: $priority")
            
            // Trigger siren for panic alerts OR any urgent request
            if (type == "panic_alert" || priority == "urgent") {
                Log.d("MyFCMService", "🚨 URGENT ALERT RECEIVED NATIVELY! WAKING UP SIREN! 🚨")
                startSirenService()
            }
        }
    }

    private fun startSirenService() {
        try {
            val intent = Intent(this, SirenForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (e: Exception) {
            Log.e("MyFCMService", "Failed to start SirenForegroundService: ${e.message}")
        }
    }
}
