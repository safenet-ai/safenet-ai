import 'package:flutter/services.dart';

class PanicChannel {
  static const MethodChannel _channel = MethodChannel('com.safenetai/panic');
  static Function()? onPanicTriggered;

  /// Starts the foreground service that listens for volume key presses
  static Future<void> startPanicService() async {
    try {
      await _channel.invokeMethod('startPanicService');
    } on PlatformException catch (e) {
      print("Failed to start panic service: '${e.message}'.");
    }
  }

  /// Sends the resident ID and flat number to Android Native SharedPreferences
  static Future<void> setPanicContext(
    String residentId,
    String flatNumber,
    String buildingNumber,
    String blockName,
    String residentName,
    String phone,
  ) async {
    try {
      await _channel.invokeMethod('setPanicContext', {
        'residentId': residentId,
        'flatNumber': flatNumber,
        'buildingNumber': buildingNumber,
        'blockName': blockName,
        'residentName': residentName,
        'phone': phone,
      });
      print("Panic Context synced to Android Native successfully.");
    } on PlatformException catch (e) {
      print("Failed to sync panic context: '${e.message}'.");
    }
  }

  /// Stops the foreground service
  static Future<void> stopPanicService() async {
    try {
      await _channel.invokeMethod('stopPanicService');
    } on PlatformException catch (e) {
      print("Failed to stop panic service: '${e.message}'.");
    }
  }

  /// Stops the emergency siren
  static Future<void> stopSiren() async {
    try {
      await _channel.invokeMethod('stopSiren');
    } catch (e) {
      // MissingPluginException is NOT a PlatformException,
      // so we catch all exceptions to avoid crashing on devices
      // that don't have the siren running (e.g. Security officer's device
      // where the channel may not be fully initialized).
      print("stopSiren: $e (safe to ignore if siren wasn't active)");
    }
  }

  /// Initializes the method call handler to listen for triggers from Native code
  static void init(Function() onTriggerCallback) {
    onPanicTriggered = onTriggerCallback;
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  /// Checks if the accessibility service is running
  static Future<bool> isPanicServiceEnabled() async {
    try {
      final bool result = await _channel.invokeMethod('isPanicServiceEnabled');
      return result;
    } on PlatformException catch (e) {
      print("Failed to check panic service: '${e.message}'.");
      return false;
    }
  }

  /// Opens the accessibility settings directly
  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } on PlatformException catch (e) {
      print("Failed to open settings: '${e.message}'.");
    }
  }

  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onPanicTriggered':
        if (onPanicTriggered != null) {
          onPanicTriggered!();
        }
        break;
      default:
        throw MissingPluginException();
    }
  }
}
