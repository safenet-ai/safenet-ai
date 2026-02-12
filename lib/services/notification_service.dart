import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

/// Top-level background message handler for FCM
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `Firebase.initializeApp()` first.
  print('Handling background message: ${message.messageId}');
}

/// Centralized notification service for handling both in-app and push notifications
class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static StreamSubscription<QuerySnapshot>? _notificationSubscription;
  static StreamSubscription<RemoteMessage>? _onMessageSubscription;
  static StreamSubscription<RemoteMessage>? _onMessageOpenedAppSubscription;

  static const AndroidNotificationChannel
  _urgentChannel = AndroidNotificationChannel(
    'urgent_security_channel_v3', // Versioned ID to force sound/importance update
    'Urgent Security Alerts',
    description: 'Critical updates and security alerts.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    sound: RawResourceAndroidNotificationSound(
      'urgent_alarm',
    ), // Refers to res/raw/urgent_alarm.mp3
    audioAttributesUsage: AudioAttributesUsage.alarm,
  );

  static const AndroidNotificationChannel _mediumChannel =
      AndroidNotificationChannel(
        'medium_security_channel_v3',
        'Medium Security Updates',
        description: 'Important status updates.',
        importance: Importance.high,
        playSound: true,
      );

  static const AndroidNotificationChannel _normalChannel =
      AndroidNotificationChannel(
        'normal_security_channel_v3',
        'Normal Updates',
        description: 'General app notifications.',
        importance: Importance.defaultImportance,
        playSound: true,
      );

  /// Initialize notification service
  static Future<void> initialize() async {
    // 🛡️ Pre-cleanup: Cancel any existing subscriptions to avoid duplicates
    _onMessageSubscription?.cancel();
    _onMessageOpenedAppSubscription?.cancel();
    _notificationSubscription?.cancel();

    // 🛡️ Check user preference before requesting any permissions or registering tokens
    final prefs = await SharedPreferences.getInstance();
    final bool isEnabled = prefs.getBool('notifications_enabled') ?? true;

    // 0. Register background handler (always do this to prevent crashes)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 1. Initialize Local Notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap when app is in foreground
        print('Local notification tapped: ${response.payload}');
      },
    );

    // 2. Create Android Notification Channels
    if (Platform.isAndroid) {
      try {
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

        // Delete legacy channel
        await androidPlugin?.deleteNotificationChannel(
          'high_importance_channel',
        );

        await androidPlugin?.createNotificationChannel(_urgentChannel);
        await androidPlugin?.createNotificationChannel(_mediumChannel);
        await androidPlugin?.createNotificationChannel(_normalChannel);
        print('🔔 Notification channels initialized successfully.');
      } catch (e) {
        print('🚨 Error creating notification channels: $e');
      }
    }

    // If notifications are disabled, stop here (except for the listener which already checks)
    if (!isEnabled) {
      print(
        '🔔 NotificationService: Initialization stopped (disabled by user).',
      );
      _startFirestoreListener(); // Still listen to handle unread counts if needed, but it checks preference
      return;
    }

    // 3. Request FCM permissions
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted notification permission');
    } else {
      print('User declined or has not accepted notification permission');
    }

    // Configure FCM foreground notification presentation
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Handle foreground messages
    _onMessageSubscription = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );

    // Handle background message taps
    _onMessageOpenedAppSubscription = FirebaseMessaging.onMessageOpenedApp
        .listen(_handleNotificationTap);

    // Request permissions for Android 13+
    await _requestPermissions();

    // Save FCM token to user document
    await _saveFCMToken();

    // 4. Start real-time Firestore listener for system tray alerts
    _startFirestoreListener();
  }

  static Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
  }

  /// Save FCM token to current user's document
  static Future<void> _saveFCMToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print(
          '🔔 NotificationService: No user logged in, skipping token save.',
        );
        return;
      }

      final token = await _fcm.getToken();
      if (token == null) {
        print('🔔 NotificationService: Failed to get FCM token.');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final userRole = prefs.getString('user_role') ?? 'resident';
      String collection = _getCollectionForRole(userRole);

      // Save token to user document
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(user.uid)
          .update({
            'fcmToken': token,
            'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          });

      print('FCM token saved to $collection for UID: ${user.uid}');
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  /// Remove FCM token from user document
  static Future<void> removeFCMToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Determine user collection based on role
      final prefs = await SharedPreferences.getInstance();
      final userRole = prefs.getString('user_role') ?? 'resident';
      String collection = _getCollectionForRole(userRole);

      // Verify document exists first if possible, or just try to update
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(user.uid)
          .update({
            'fcmToken': FieldValue.delete(),
            'fcmTokenLastRemoved': FieldValue.serverTimestamp(),
          });
      print('FCM token removed from Firestore for UID: ${user.uid}');
    } catch (e) {
      print('Error removing FCM token from Firestore: $e');
    }
  }

  /// Handle foreground messages
  static void _handleForegroundMessage(RemoteMessage message) {
    print('Foreground message: ${message.notification?.title}');

    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    // If `onMessage` is triggered, FCM will NOT automatically show a notification bar alert
    // when the app is in the foreground. We must show it manually using local notifications.
    if (notification != null) {
      _showLocalNotification(
        id: notification.hashCode,
        title: notification.title ?? 'SafeNet AI',
        body: notification.body ?? '',
        payload: message.data.toString(),
      );
    }
  }

  /// Show a system tray notification
  static Future<void> _showLocalNotification({
    int id = 0,
    required String title,
    required String body,
    String? payload,
    String priority = 'normal',
  }) async {
    try {
      // 🛡️ Check user preference before showing any notification
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('notifications_enabled') ?? true;
      if (!enabled) {
        print('🔔 Notification suppressed by user preference.');
        return;
      }

      print('🔔 Showing alert: Priority=$priority, Title=$title');

      // Select channel based on priority
      AndroidNotificationChannel targetChannel = _normalChannel;
      if (priority.toLowerCase() == 'urgent') {
        targetChannel = _urgentChannel;
      } else if (priority.toLowerCase() == 'medium') {
        targetChannel = _mediumChannel;
      }

      print('🔔 Channel selected: ${targetChannel.id}. Attempting to show...');

      await _localNotifications.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            targetChannel.id,
            targetChannel.name,
            channelDescription: targetChannel.description,
            importance: targetChannel.importance,
            priority: Priority.max, // Set to MAX for Urgent alerts
            icon: '@mipmap/ic_launcher',
            ticker: 'SafeNet AI Notification',
            playSound: true,
            enableVibration: true,
            vibrationPattern: priority.toLowerCase() == 'urgent'
                ? Int64List.fromList([
                    0,
                    500,
                    200,
                    500,
                    200,
                    1000,
                  ]) // Aggressive pattern for Urgent
                : null,
            sound: priority.toLowerCase() == 'urgent'
                ? const RawResourceAndroidNotificationSound('urgent_alarm')
                : null,
            audioAttributesUsage: priority.toLowerCase() == 'urgent'
                ? AudioAttributesUsage.alarm
                : AudioAttributesUsage.notification,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound:
                'urgent_alarm.aiff', // Assuming iOS uses aiff or caf, but keeping consistent with original logic if possible or standard sound
          ),
        ),
        payload: payload,
      );
      print('🔔 Notification .show() called successfully.');
    } catch (e, stack) {
      print('🚨 CRITICAL ERROR in _showLocalNotification: $e');
      print('🚨 STACK TRACE: $stack');
    }
  }

  /// Handle notification tap
  static void _handleNotificationTap(RemoteMessage message) {
    print('Notification tapped: ${message.data}');
    // TODO: Implement deep linking based on notification type
    // Navigate to appropriate screen based on message.data['type']
  }

  static final Set<String> _processedNotificationIds = {};
  static bool _isFirstSnapshot = true;

  /// Start listening for new notifications in Firestore
  static void _startFirestoreListener() {
    print('🔔 Firestore Listener: Initializing...');

    _notificationSubscription?.cancel();
    _processedNotificationIds.clear();
    _isFirstSnapshot = true; // Reset for new subscription

    _notificationSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen(
          (snapshot) async {
            // 🛡️ Check user preference first
            final prefs = await SharedPreferences.getInstance();
            final enabled = prefs.getBool('notifications_enabled') ?? true;
            if (!enabled) {
              print(
                '🔔 Firestore Listener: Skipping alerts (notifications disabled).',
              );
              return;
            }

            final user = FirebaseAuth.instance.currentUser;

            final authorityUid = prefs.getString('authority_uid');
            final currentUid = user?.uid ?? authorityUid;
            final userRole = prefs.getString('user_role');

            print(
              '🔔 Firestore Signal: UID=$currentUid, Role=$userRole. IsFirst=$_isFirstSnapshot, Docs: ${snapshot.docs.length}',
            );

            // If it's the first snapshot, we just mark everything as processed
            // to avoid alerting for old unread notifications on every restart.
            if (_isFirstSnapshot) {
              for (var doc in snapshot.docs) {
                _processedNotificationIds.add(doc.id);
              }
              _isFirstSnapshot = false;
              print(
                '🔔 First snapshot processed: ${_processedNotificationIds.length} existing unread notifications marked.',
              );
              return;
            }

            for (var change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                final docId = change.doc.id;

                // Deduplication: Only process each document ID once per session
                if (_processedNotificationIds.contains(docId)) continue;
                _processedNotificationIds.add(docId);

                final data = change.doc.data() as Map<String, dynamic>;
                final fromUid = data['fromUid'];

                // Skip if I am the one who sent it
                if (fromUid != null &&
                    currentUid != null &&
                    fromUid == currentUid) {
                  print('🔔 Skipping self-notification.');
                  continue;
                }

                final toUid = data['toUid'];
                final toRole = data['toRole'];

                bool isForMe = false;
                if (toUid != null &&
                    currentUid != null &&
                    toUid == currentUid) {
                  isForMe = true;
                } else if (toRole != null && userRole != null) {
                  if (toRole == userRole ||
                      (toRole == 'user' && userRole == 'resident')) {
                    isForMe = true;
                  }
                }

                if (isForMe) {
                  print(
                    '🔔 TRIGGERING SYSTEM TRAY ALERT: ${data['title']} (Priority: ${data['priority']})',
                  );
                  _showLocalNotification(
                    id: docId.hashCode,
                    title: data['title'] ?? 'SafeNet AI',
                    body: data['message'] ?? '',
                    payload: data['type'],
                    priority: data['priority'] ?? 'normal',
                  );
                }
              }
            }
          },
          onError: (e) {
            print('🔔 Firestore Listener Error: $e');
          },
        );
  }

  /// Send notification to a specific user or role
  /// Creates both in-app notification (Firestore) and sends push notification
  static Future<void> sendNotification({
    String? userId,
    String? toRole,
    required String userRole,
    required String title,
    required String body,
    required String type,
    String priority = 'normal',
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final prefs = await SharedPreferences.getInstance();
      final senderUid = currentUser?.uid ?? prefs.getString('authority_uid');

      // 1. Create in-app notification in Firestore
      final notificationData = {
        'fromUid': senderUid,
        'toUid': userId,
        'toRole': toRole,
        'title': title,
        'message': body,
        'type': type,
        'priority': priority,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        ...?additionalData,
      };

      await FirebaseFirestore.instance
          .collection('notifications')
          .add(notificationData);

      // (Local Preview logic removed: Handled by _startFirestoreListener)

      // 2. Get user's FCM token (only if userId is provided)
      if (userId != null) {
        String collection = _getCollectionForRole(userRole);
        final userDoc = await FirebaseFirestore.instance
            .collection(collection)
            .doc(userId)
            .get();

        if (!userDoc.exists) {
          print(
            'User document not found for notification: $userId in $collection',
          );
          return;
        }

        final fcmToken = userDoc.data()?['fcmToken'] as String?;
        if (fcmToken != null) {
          // 3. Send push notification via FCM
          print('Would send push notification to token: $fcmToken');
          print('Title: $title, Body: $body');
        }
      } else if (toRole != null) {
        // Handle role-based push notifications (usually via FCM topics)
        print('Would send push notification to role topic: $toRole');
      }
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  /// Check if a user belongs to a specific role
  static Future<bool> _isUserInRole(String? uid, String role) async {
    if (uid == null) return false;
    final collection = _getCollectionForRole(role);
    final doc = await FirebaseFirestore.instance
        .collection(collection)
        .doc(uid)
        .get();
    return doc.exists;
  }

  /// Get Firestore collection name for user role
  static String _getCollectionForRole(String role) {
    switch (role) {
      case 'user':
      case 'resident':
        return 'users';
      case 'worker':
      case 'security':
        return 'workers';
      case 'authority':
        return 'authorities';
      default:
        return 'users';
    }
  }

  /// Send notification to multiple users
  static Future<void> sendBulkNotification({
    required List<String> userIds,
    required String userRole,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? additionalData,
  }) async {
    for (final userId in userIds) {
      await sendNotification(
        userId: userId,
        userRole: userRole,
        title: title,
        body: body,
        type: type,
        additionalData: additionalData,
      );
    }
  }

  /// Stop the Firestore listener
  static void stopListening() {
    print('🔔 Firestore Listener: Stopping...');
    _notificationSubscription?.cancel();
    _notificationSubscription = null;

    print('🔔 FCM Listeners: Stopping...');
    _onMessageSubscription?.cancel();
    _onMessageSubscription = null;
    _onMessageOpenedAppSubscription?.cancel();
    _onMessageOpenedAppSubscription = null;
  }
}
