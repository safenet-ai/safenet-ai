# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.functions.** { *; }

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# AndroidX/Support libraries
-keep class androidx.core.app.NotificationCompat** { *; }
-keep class android.support.v4.app.NotificationCompat** { *; }

# Play Core / Deferred Components (Fix for R8 build errors)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
