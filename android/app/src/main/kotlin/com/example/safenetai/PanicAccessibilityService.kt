package com.example.safenetai

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import android.widget.Toast

class PanicAccessibilityService : AccessibilityService() {

    private var volumeUpPressCount = 0
    private var lastVolumeUpPressTime: Long = 0
    private val PANIC_THRESHOLD_MS = 5000L // 5 seconds
    private val REQUIRED_PRESSES = 3
    
    // Global lock to prevent race conditions and duplicate fires
    private var isPanicTriggered = false
    private val COOLDOWN_PERIOD_MS = 15000L // 15 seconds cooldown

    override fun onServiceConnected() {
        super.onServiceConnected()
        
        try {
            val intent = Intent(this, PanicForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (e: Exception) {
            
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Not used
    }

    override fun onInterrupt() {
        // Not used
    }

    override fun onKeyEvent(event: KeyEvent): Boolean {
        // If we are in cooldown, ignore key completely so standard system behavior resumes
        if (isPanicTriggered) {
            return super.onKeyEvent(event)
        }

        if (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
            if (event.action == KeyEvent.ACTION_DOWN) {
                
                handleVolumeUpPress()
            }
            return true 
        }

        return super.onKeyEvent(event)
    }

    private fun handleVolumeUpPress() {
        val currentTime = System.currentTimeMillis()
        if (currentTime - lastVolumeUpPressTime > PANIC_THRESHOLD_MS) {
            volumeUpPressCount = 1 
        } else {
            volumeUpPressCount++
        }
        lastVolumeUpPressTime = currentTime

        

        if (volumeUpPressCount >= REQUIRED_PRESSES) {
            triggerPanicAlert()
        }
    }

    private fun triggerPanicAlert() {
        if (isPanicTriggered) return // Double check thread safety
        isPanicTriggered = true
        volumeUpPressCount = 0 // Reset

        
        
        showToast("🚨 Panic Alert in 10s — Check your notification to cancel")
        vibrateDevice()

        // 1. Broadcast to Flutter if it's currently alive in the background
        val broadcastIntent = Intent("com.example.safenetai.PANIC_TRIGGERED_COUNTDOWN")
        broadcastIntent.setPackage(packageName)
        sendBroadcast(broadcastIntent)

        // 2. Start native countdown notification (no app launch needed)
        try {
            val countdownIntent = Intent(this, PanicCountdownService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(countdownIntent)
            } else {
                startService(countdownIntent)
            }
        } catch (e: Exception) {
            
        }

        // 3. Start 15-second cooldown timer
        Handler(Looper.getMainLooper()).postDelayed({
            isPanicTriggered = false
            
        }, COOLDOWN_PERIOD_MS)
    }

    private fun showToast(message: String) {
        Handler(Looper.getMainLooper()).post {
            Toast.makeText(applicationContext, message, Toast.LENGTH_LONG).show()
        }
    }

    private fun vibrateDevice() {
        val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createOneShot(1000, VibrationEffect.DEFAULT_AMPLITUDE))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(1000)
        }
    }
}

