import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase_options.dart';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

/// Top-level background message handler for FCM
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('Handling background message: ${message.messageId}');

  // Show a local notification for ALL background messages.
  // Android auto-shows system tray for notification+data, but a local notification
  // ensures correct channel and priority are used.
  final notification = message.notification;
  final data = message.data;

  // If FCM already displayed a system notification, don't duplicate it locally.
  if (notification != null) {
    print(
      'FCM payload contains notification block. System handles display. Skipping manual local notification.',
    );
    return;
  }

  // BUG-1 FIX: notification is guaranteed null here — read from data only
  final String title = data['title'] ?? data['category'] ?? 'SafeNet AI';
  final String body = data['body'] ?? '';
  final String priority =
      data['priority']?.toString().toLowerCase() ?? 'normal';

  if (title.isEmpty && body.isEmpty) return;

  final FlutterLocalNotificationsPlugin localNotifications =
      FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings initSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  await localNotifications.initialize(
    const InitializationSettings(android: initSettingsAndroid),
  );

  // Select v6 channel
  String channelId = 'normal_security_channel_v6';
  String channelName = 'Normal Updates';
  Importance importance = Importance.defaultImportance;
  if (priority == 'urgent') {
    channelId = 'urgent_security_channel_v6';
    channelName = 'Urgent Security Alerts';
    importance = Importance.max;
  } else if (priority == 'medium') {
    channelId = 'medium_security_channel_v6';
    channelName = 'Medium Security Updates';
    importance = Importance.high;
  }

  await localNotifications.show(
    message.hashCode,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: importance,
        priority: Priority.max,
        icon: '@mipmap/ic_launcher',
        playSound:
            priority !=
            'urgent', // urgent channel is silent, siren handles audio
      ),
    ),
  );
}

/// Centralized notification service for handling both in-app and push notifications
class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static StreamSubscription<QuerySnapshot>? _notificationSubscription;
  static StreamSubscription<RemoteMessage>? _onMessageSubscription;
  static StreamSubscription<RemoteMessage>? _onMessageOpenedAppSubscription;

  // URGENT: Silent channel (v6) — no sound here.
  // SirenForegroundService plays the looping alarm via MediaPlayer.
  // Importance.max → heads-up popup still shows.
  static const AndroidNotificationChannel _urgentChannel =
      AndroidNotificationChannel(
        'urgent_security_channel_v6',
        'Urgent Security Alerts',
        description: 'Critical updates and security alerts.',
        importance: Importance.max,
        playSound: false,
        enableVibration: true,
      );

  static const AndroidNotificationChannel _mediumChannel =
      AndroidNotificationChannel(
        'medium_security_channel_v6',
        'Medium Security Updates',
        description: 'Important status updates.',
        importance: Importance.high,
        playSound: true,
      );

  static const AndroidNotificationChannel _normalChannel =
      AndroidNotificationChannel(
        'normal_security_channel_v6',
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

        // Delete ALL legacy channels to bust cached settings
        await androidPlugin?.deleteNotificationChannel(
          'high_importance_channel',
        );
        await androidPlugin?.deleteNotificationChannel(
          'urgent_security_channel_v4',
        );
        await androidPlugin?.deleteNotificationChannel(
          'medium_security_channel_v4',
        );
        await androidPlugin?.deleteNotificationChannel(
          'normal_security_channel_v4',
        );
        await androidPlugin?.deleteNotificationChannel(
          'urgent_security_channel_v5',
        );
        await androidPlugin?.deleteNotificationChannel(
          'medium_security_channel_v5',
        );
        await androidPlugin?.deleteNotificationChannel(
          'normal_security_channel_v5',
        );

        // Create fresh v6 channels with correct settings
        await androidPlugin?.createNotificationChannel(_urgentChannel);
        await androidPlugin?.createNotificationChannel(_mediumChannel);
        await androidPlugin?.createNotificationChannel(_normalChannel);
        print('🔔 Notification channels v6 initialized successfully.');
      } catch (e) {
        print('🚨 Error creating notification channels: $e');
      }
    }

    // If notifications are disabled, stop here (FCM background handler is still registered).
    // startFirestoreListener() must NOT be called here — user is not logged in yet.
    // It is called from each dashboard's initState after authentication.
    if (!isEnabled) {
      print(
        '🔔 NotificationService: Notification UI disabled by user preference.',
      );
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

    // Handle background message taps (App is in background, but not killed)
    _onMessageOpenedAppSubscription = FirebaseMessaging.onMessageOpenedApp
        .listen(_handleNotificationTap);

    // Handle cold-start message taps (App is completely killed)
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
        print('Cold start from notification: ${message.data}');
        _handleNotificationTap(message);
      }
    });

    // Request permissions for Android 13+
    await _requestPermissions();

    // Save FCM token to user document
    // NOTE: This may fail here if user is not logged in yet.
    // saveFCMToken() is also called from each dashboard's initState.
    await saveFCMToken();

    // NOTE: startFirestoreListener() is NOT called here.
    // It must be called AFTER login from each dashboard's initState,
    // when currentUser and userRole are available.
    print(
      '🔔 NotificationService.initialize() complete. Waiting for dashboard to start Firestore listener.',
    );
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

  /// Save FCM token to current user's document (Public for manual refresh)
  static Future<void> saveFCMToken() async {
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

      // Save token to user document (Still useful for 1-to-1 DMs/Chats)
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(user.uid)
          .update({
            'fcmToken': token,
            'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          });

      // ==========================================
      // NEW TOPIC SUBSCRIPTION LOGIC
      // ==========================================
      // First, unsubscribe from all possible roles to prevent leakage
      await _fcm.unsubscribeFromTopic('resident');
      await _fcm.unsubscribeFromTopic('security');
      await _fcm.unsubscribeFromTopic('authority');
      await _fcm.unsubscribeFromTopic('worker');
      await _fcm.unsubscribeFromTopic('user'); // Alias

      // Then subscribe to the current actual role
      if (userRole.isNotEmpty) {
        await _fcm.subscribeToTopic(userRole);
        // Standardize topics for backend ease
        if (userRole == 'security') await _fcm.subscribeToTopic('worker');
        if (userRole == 'resident') await _fcm.subscribeToTopic('user');

        print('🔔 Subscribed UID ${user.uid} to FCM topic: $userRole');
      }

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

      // ==========================================
      // NEW TOPIC UNSUBSCRIPTION LOGIC
      // ==========================================
      await _fcm.unsubscribeFromTopic('resident');
      await _fcm.unsubscribeFromTopic('security');
      await _fcm.unsubscribeFromTopic('authority');
      await _fcm.unsubscribeFromTopic('worker');
      await _fcm.unsubscribeFromTopic('user');

      print('FCM token removed and topics unsubscribed for UID: ${user.uid}');
    } catch (e) {
      print('Error removing FCM token from Firestore: $e');
    }
  }

  /// Handle foreground messages
  static void _handleForegroundMessage(RemoteMessage message) {
    print('Foreground message: ${message.notification?.title}');

    RemoteNotification? notification = message.notification;

    // If `onMessage` is triggered, FCM will NOT automatically show a notification bar alert
    // when the app is in the foreground. We must show it manually using local notifications.
    if (notification != null) {
      // Extract priority from data if available
      String priority =
          message.data['priority']?.toString().toLowerCase() ?? 'normal';

      // Use unique timestamp ID to prevent different notifications collapsing
      _showLocalNotification(
        id: DateTime.now().millisecondsSinceEpoch % 100000,
        title: notification.title ?? 'SafeNet AI',
        body: notification.body ?? '',
        payload: message.data.toString(),
        priority: priority,
      );
    } else if (message.data.isNotEmpty) {
      // Data-only message (e.g., panic alerts use data-only for native siren)
      final data = message.data;
      final title = data['title'] ?? 'SafeNet AI';
      final body = data['body'] ?? '';
      final priority = data['priority']?.toString().toLowerCase() ?? 'normal';

      if (title.isNotEmpty && body.isNotEmpty) {
        _showLocalNotification(
          id: message.hashCode,
          title: title,
          body: body,
          payload: data.toString(),
          priority: priority,
        );
      }
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
            priority: Priority.max,
            icon: '@mipmap/ic_launcher',
            ticker: 'SafeNet AI Notification',
            playSound: targetChannel.playSound,
            enableVibration: true,
            vibrationPattern: priority.toLowerCase() == 'urgent'
                ? Int64List.fromList([0, 500, 200, 500, 200, 1000])
                : null,
            // No sound override — the channel's sound setting takes effect
            // Urgent channel is SILENT; SirenForegroundService plays the loop
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'urgent_alarm.aiff',
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
  }

  static final Set<String> _processedNotificationIds = {};
  static bool _isFirstSnapshot = true;
  static const int _maxProcessedIds =
      500; // BUG-6 FIX: Cap to prevent unbounded growth

  /// Start listening for new notifications in Firestore (Public for manual restart)
  static void startFirestoreListener() {
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

            // 🛡️ Null guard: If auth state isn't ready, skip this snapshot
            if (currentUid == null || userRole == null) {
              print(
                '🔔 Firestore Listener: UID or Role is NULL — skipping this snapshot. Auth may not be ready yet.',
              );
              return;
            }

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
                // BUG-6 FIX: Prevent unbounded Set growth
                if (_processedNotificationIds.length > _maxProcessedIds) {
                  final toRemove = _processedNotificationIds
                      .take(_processedNotificationIds.length - _maxProcessedIds)
                      .toList();
                  _processedNotificationIds.removeAll(toRemove);
                }

                final data = change.doc.data() as Map<String, dynamic>;
                final fromUid = data['fromUid'];

                // Skip if I am the one who sent it
                if (fromUid != null && fromUid == currentUid) {
                  print('🔔 Skipping self-notification.');
                  continue;
                }

                final toUid = data['toUid'];
                final toRole = data['toRole'];

                bool isForMe = false;
                if (toUid != null && toUid == currentUid) {
                  isForMe = true;
                } else if (toRole != null) {
                  if (toRole == userRole ||
                      (toRole == 'user' && userRole == 'resident')) {
                    isForMe = true;
                  }
                }

                if (isForMe) {
                  print(
                    '🔔 SILENT FIRESTORE LISTENER UPDATE: ${data['title']}',
                  );
                  // App-based local notifications removed.
                  // Only relying on Firebase push notifications.
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
      // BUG-2 FIX: Search ALL collections for the recipient, not just the sender's role collection
      if (userId != null) {
        String? fcmToken;
        for (final coll in ['users', 'workers', 'authorities']) {
          final userDoc = await FirebaseFirestore.instance
              .collection(coll)
              .doc(userId)
              .get();
          if (userDoc.exists) {
            fcmToken = userDoc.data()?['fcmToken'] as String?;
            print('Found user $userId in $coll collection.');
            break;
          }
        }

        if (fcmToken != null) {
          print('Would send push notification to token: $fcmToken');
          print('Title: $title, Body: $body');
        } else {
          print('No FCM token found for UID: $userId in any collection.');
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
  /// BUG-3 FIX: Now accepts and passes `priority` parameter
  static Future<void> sendBulkNotification({
    required List<String> userIds,
    required String userRole,
    required String title,
    required String body,
    required String type,
    String priority = 'normal',
    Map<String, dynamic>? additionalData,
  }) async {
    for (final userId in userIds) {
      await sendNotification(
        userId: userId,
        userRole: userRole,
        title: title,
        body: body,
        type: type,
        priority: priority,
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
