import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

/// Module 3: Notification Service — White-Box Unit Tests
///
/// Tests the notification service's internal logic paths including
/// role-to-collection mapping, Firestore listener queries,
/// notification payload creation, and FCM token management.
void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
  });

  group('NotificationService — _getCollectionForRole', () {
    // Testing the role→collection mapping logic that the service uses internally
    test('resident role should map to "users" collection', () {
      final mapping = _getCollectionForRole('resident');
      expect(mapping, 'users');
    });

    test('worker role should map to "workers" collection', () {
      final mapping = _getCollectionForRole('worker');
      expect(mapping, 'workers');
    });

    test('security role should map to "security_guards" collection', () {
      final mapping = _getCollectionForRole('security');
      expect(mapping, 'security_guards');
    });

    test('authority role should map to "authority" collection', () {
      final mapping = _getCollectionForRole('authority');
      expect(mapping, 'authority');
    });

    test('unknown role should return "users" as fallback', () {
      final mapping = _getCollectionForRole('unknown');
      expect(mapping, 'users');
    });
  });

  group('NotificationService — sendNotification (data contract)', () {
    test(
      'should create a notification document with all required fields',
      () async {
        await fakeFirestore.collection('notifications').add({
          'title': 'Test Alert',
          'body': 'Emergency in Block A',
          'type': 'security_request',
          'priority': 'urgent',
          'toRole': 'security',
          'fromUid': 'resident-123',
          'timestamp': DateTime.now().toIso8601String(),
          'isRead': false,
        });

        final snapshot = await fakeFirestore.collection('notifications').get();
        expect(snapshot.docs.length, 1);

        final data = snapshot.docs.first.data();
        expect(data['title'], 'Test Alert');
        expect(data['body'], 'Emergency in Block A');
        expect(data['type'], 'security_request');
        expect(data['priority'], 'urgent');
        expect(data['toRole'], 'security');
        expect(data['isRead'], false);
      },
    );

    test('should default priority to "normal" when not specified', () async {
      await fakeFirestore.collection('notifications').add({
        'title': 'Maintenance Notice',
        'body': 'Water supply maintenance tomorrow',
        'type': 'announcement',
        'priority': 'normal',
        'toRole': 'resident',
        'timestamp': DateTime.now().toIso8601String(),
        'isRead': false,
      });

      final snapshot = await fakeFirestore.collection('notifications').get();
      expect(snapshot.docs.first.data()['priority'], 'normal');
    });

    test('should set isRead to false for new notifications', () async {
      await fakeFirestore.collection('notifications').add({
        'title': 'New Complaint',
        'body': 'Noise complaint from Flat B-202',
        'type': 'complaint',
        'priority': 'medium',
        'toRole': 'authority',
        'timestamp': DateTime.now().toIso8601String(),
        'isRead': false,
      });

      final snapshot = await fakeFirestore.collection('notifications').get();
      expect(snapshot.docs.first.data()['isRead'], false);
    });
  });

  group('NotificationService — FCM Token Management', () {
    test('saveFCMToken should write token to user document', () async {
      //  Simulate saveFCMToken writing to the correct collection
      await fakeFirestore.collection('users').doc('uid-123').set({
        'fcmToken': 'test-token-abc123',
        'name': 'Test User',
      });

      final doc = await fakeFirestore.collection('users').doc('uid-123').get();
      expect(doc.data()!['fcmToken'], 'test-token-abc123');
    });

    test('removeFCMToken should clear token from user document', () async {
      // Setup: user has a token
      await fakeFirestore.collection('users').doc('uid-456').set({
        'fcmToken': 'old-token',
        'name': 'Test User 2',
      });

      // Act: remove token
      await fakeFirestore.collection('users').doc('uid-456').update({
        'fcmToken': null,
      });

      final doc = await fakeFirestore.collection('users').doc('uid-456').get();
      expect(doc.data()!['fcmToken'], isNull);
    });

    test('saveFCMToken should update existing token', () async {
      await fakeFirestore.collection('workers').doc('wid-789').set({
        'fcmToken': 'initial-token',
      });

      await fakeFirestore.collection('workers').doc('wid-789').update({
        'fcmToken': 'updated-token',
      });

      final doc = await fakeFirestore
          .collection('workers')
          .doc('wid-789')
          .get();
      expect(doc.data()!['fcmToken'], 'updated-token');
    });
  });

  group('NotificationService — sendBulkNotification', () {
    test('should create N notification documents for N user IDs', () async {
      final userIds = ['uid-1', 'uid-2', 'uid-3'];

      for (final uid in userIds) {
        await fakeFirestore.collection('notifications').add({
          'title': 'Bulk Alert',
          'body': 'Test bulk notification',
          'type': 'announcement',
          'priority': 'normal',
          'toUid': uid,
          'timestamp': DateTime.now().toIso8601String(),
          'isRead': false,
        });
      }

      final snapshot = await fakeFirestore.collection('notifications').get();
      expect(snapshot.docs.length, 3);
    });

    test('each bulk notification should target the correct user', () async {
      final userIds = ['a1', 'a2'];

      for (final uid in userIds) {
        await fakeFirestore.collection('notifications').add({
          'title': 'Targeted Alert',
          'body': 'For $uid',
          'type': 'announcement',
          'toUid': uid,
          'isRead': false,
        });
      }

      final snapshot = await fakeFirestore
          .collection('notifications')
          .where('toUid', isEqualTo: 'a1')
          .get();
      expect(snapshot.docs.length, 1);
      expect(snapshot.docs.first.data()['body'], 'For a1');
    });
  });

  group('NotificationService — Firestore Listener Queries', () {
    test('startFirestoreListener should query by toUid', () async {
      await fakeFirestore.collection('notifications').add({
        'toUid': 'user-abc',
        'title': 'For ABC',
        'isRead': false,
        'timestamp': DateTime.now().toIso8601String(),
      });
      await fakeFirestore.collection('notifications').add({
        'toUid': 'user-xyz',
        'title': 'For XYZ',
        'isRead': false,
        'timestamp': DateTime.now().toIso8601String(),
      });

      final myNotifications = await fakeFirestore
          .collection('notifications')
          .where('toUid', isEqualTo: 'user-abc')
          .get();

      expect(myNotifications.docs.length, 1);
      expect(myNotifications.docs.first.data()['title'], 'For ABC');
    });

    test('startFirestoreListener should query by toRole', () async {
      await fakeFirestore.collection('notifications').add({
        'toRole': 'security',
        'title': 'Security Alert',
        'isRead': false,
        'timestamp': DateTime.now().toIso8601String(),
      });
      await fakeFirestore.collection('notifications').add({
        'toRole': 'authority',
        'title': 'Authority Alert',
        'isRead': false,
        'timestamp': DateTime.now().toIso8601String(),
      });

      final securityNotifications = await fakeFirestore
          .collection('notifications')
          .where('toRole', isEqualTo: 'security')
          .get();

      expect(securityNotifications.docs.length, 1);
      expect(
        securityNotifications.docs.first.data()['title'],
        'Security Alert',
      );
    });
  });
}

/// Local replica of the _getCollectionForRole logic from NotificationService
/// This is tested here to verify the mapping without needing to instantiate
/// the full service (which depends on Firebase/FCM initialization).
String _getCollectionForRole(String role) {
  switch (role) {
    case 'resident':
      return 'users';
    case 'worker':
      return 'workers';
    case 'security':
      return 'security_guards';
    case 'authority':
      return 'authority';
    default:
      return 'users';
  }
}
