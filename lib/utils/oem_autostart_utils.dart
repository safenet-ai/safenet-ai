import 'dart:io';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OemAutostartUtils {
  static const String _prefKey = 'has_requested_autostart';

  /// Check if the device is a Chinese OEM that typically requires Autostart permission
  static Future<bool> isOemWithAutostart() async {
    if (!Platform.isAndroid) return false;

    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    final manufacturer = androidInfo.manufacturer.toLowerCase();

    return manufacturer.contains('xiaomi') ||
        manufacturer.contains('oppo') ||
        manufacturer.contains('vivo') ||
        manufacturer.contains('letv') ||
        manufacturer.contains('honor') ||
        manufacturer.contains('oneplus');
  }

  /// Check if we've already shown the prompt to the user
  static Future<bool> hasRequestedAutostart() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  /// Mark that we've shown the prompt
  static Future<void> markAutostartRequested() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }

  /// Open the specific OEM's autostart settings page using intents
  static Future<void> openAutostartSettings() async {
    if (!Platform.isAndroid) return;

    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    final manufacturer = androidInfo.manufacturer.toLowerCase();

    try {
      if (manufacturer.contains('xiaomi')) {
        const intent = AndroidIntent(
          action: 'action_view',
          componentName:
              'com.miui.securitycenter/com.miui.permcenter.autostart.AutoStartManagementActivity',
        );
        await intent.launch();
      } else if (manufacturer.contains('oppo')) {
        const intent = AndroidIntent(
          action: 'action_view',
          componentName:
              'com.coloros.safecenter/com.coloros.safecenter.permission.startup.StartupAppListActivity',
        );
        await intent.launch();
      } else if (manufacturer.contains('vivo')) {
        const intent = AndroidIntent(
          action: 'action_view',
          componentName:
              'com.vivo.permissionmanager/com.vivo.permissionmanager.activity.BgStartUpManagerActivity',
        );
        await intent.launch();
      } else if (manufacturer.contains('oneplus')) {
        const intent = AndroidIntent(
          action: 'action_view',
          componentName:
              'com.oneplus.security/com.oneplus.security.chainlaunch.view.AllowAutoLaunchActivity',
        );
        await intent.launch();
      }
    } catch (e) {
      print('Failed to open OEM Autostart settings: $e');
      // Fallback to standard app info settings
      const intent = AndroidIntent(
        action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
        data: 'package:com.example.safenetai',
      );
      await intent.launch();
    }
  }

  /// Open standard Android battery optimization settings
  static Future<void> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) return;
    try {
      const intent = AndroidIntent(
        action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
      );
      await intent.launch();
    } catch (e) {
      print('Failed to open Battery Optimization settings: $e');
    }
  }

  /// Show the dialog to the user explaining why we need Autostart
  static Future<void> showAutostartDialogIfNeeded(BuildContext context) async {
    if (await isOemWithAutostart() && !(await hasRequestedAutostart())) {
      bool shouldOpen = false;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text('Background Execution Needed'),
            content: const Text(
              'Your device restricts apps from running in the background. To guarantee you receive Emergency Panic Alerts and Urgent Notifications even when the app is swiped away, you MUST enable "Autostart" and set Battery Saving to "No Restrictions".\n\nWould you like to open settings now?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('LATER'),
              ),
              ElevatedButton(
                onPressed: () {
                  shouldOpen = true;
                  Navigator.of(context).pop();
                },
                child: const Text('OPEN SETTINGS'),
              ),
            ],
          );
        },
      );

      await markAutostartRequested();

      if (shouldOpen) {
        await openAutostartSettings();
        // Give the user time to return from settings
        await Future.delayed(const Duration(seconds: 3));
        await openBatteryOptimizationSettings();
      }
    }
  }
}
