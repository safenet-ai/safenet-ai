package com.example.safenetai

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.content.ComponentName
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.safenetai/panic"
    private lateinit var channel: MethodChannel

    private val panicReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "com.example.safenetai.PANIC_TRIGGERED") {
                // Send the event to Flutter when it's safe on the UI thread
                runOnUiThread {
                    channel.invokeMethod("onPanicTriggered", null)
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startPanicService" -> {
                    startPanicService()
                    result.success(true)
                }
                "setPanicContext" -> {
                    val residentId = call.argument<String>("residentId")
                    val flatNumber = call.argument<String>("flatNumber")
                    val buildingNumber = call.argument<String>("buildingNumber") ?: "Unknown"
                    val blockName = call.argument<String>("blockName") ?: "Unknown"
                    val residentName = call.argument<String>("residentName") ?: "Unknown"
                    val phone = call.argument<String>("phone") ?: "Unknown"
                    if (residentId != null && flatNumber != null) {
                        val prefs = getSharedPreferences("SafeNetPrefs", Context.MODE_PRIVATE)
                        prefs.edit()
                            .putString("residentId", residentId)
                            .putString("flatNumber", flatNumber)
                            .putString("buildingNumber", buildingNumber)
                            .putString("blockName", blockName)
                            .putString("residentName", residentName)
                            .putString("phone", phone)
                            .apply()
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Missing residentId or flatNumber", null)
                    }
                }
                "stopPanicService" -> {
                    stopPanicService()
                    result.success(true)
                }
                "stopSiren" -> {
                    val intent = Intent(this@MainActivity, SirenForegroundService::class.java)
                    stopService(intent)
                    result.success(true)
                }
                "isPanicServiceEnabled" -> {
                    val isEnabled = isAccessibilityServiceEnabled(this@MainActivity, PanicAccessibilityService::class.java)
                    result.success(isEnabled)
                }
                "openAccessibilitySettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    startActivity(intent)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val filter = IntentFilter("com.example.safenetai.PANIC_TRIGGERED")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(panicReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(panicReceiver, filter)
        }
    }

    override fun onDestroy() {
        unregisterReceiver(panicReceiver)
        super.onDestroy()
    }

    private fun startPanicService() {
        if (!isAccessibilityServiceEnabled(this, PanicAccessibilityService::class.java)) {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(intent)
        }
    }

    private fun stopPanicService() {
        // Accessibility services cannot be stopped programmatically for security reasons.
        // User must turn it off in settings.
    }

    private fun isAccessibilityServiceEnabled(context: Context, accessibilityService: Class<*>): Boolean {
        val expectedComponentName = ComponentName(context, accessibilityService)
        val enabledServicesSetting = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServicesSetting)

        while (colonSplitter.hasNext()) {
            val componentNameString = colonSplitter.next()
            val enabledService = ComponentName.unflattenFromString(componentNameString)
            if (enabledService != null && enabledService == expectedComponentName) {
                return true
            }
        }
        return false
    }
}
