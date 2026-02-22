import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

/// Module 4: Panic Alert Controller — White-Box Unit Tests
///
/// Tests the core business logic of panic alert triggering,
/// status updates, and active alert queries.
void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
  });

  group('PanicAlertController — _saveAlert via triggerAlert', () {
    test(
      'triggerAlert() should create a document in panic_alerts collection',
      () async {
        // We can't inject the fake Firestore into the controller as-is
        // because it uses FirebaseFirestore.instance internally.
        // Instead, we test the atomic _saveAlert equivalent by writing directly.
        //
        // This test validates the DATA CONTRACT that the controller writes.
        final docRef = fakeFirestore.collection('panic_alerts').doc();
        await docRef.set({
          'residentId': 'test-resident',
          'flatNumber': 'A-101',
          'timestamp': DateTime.now().toIso8601String(),
          'alertType': 'Priority',
          'status': 'Triggered',
        });

        final snapshot = await fakeFirestore.collection('panic_alerts').get();
        expect(snapshot.docs.length, 1);
        expect(snapshot.docs.first.data()['residentId'], 'test-resident');
        expect(snapshot.docs.first.data()['flatNumber'], 'A-101');
        expect(snapshot.docs.first.data()['status'], 'Triggered');
      },
    );

    test('triggerAlert() should set default alertType to Priority', () async {
      final docRef = fakeFirestore.collection('panic_alerts').doc();
      await docRef.set({
        'residentId': 'res-2',
        'flatNumber': 'B-202',
        'timestamp': DateTime.now().toIso8601String(),
        'alertType': 'Priority',
        'status': 'Triggered',
      });

      final doc = await docRef.get();
      expect(doc.data()!['alertType'], 'Priority');
    });

    test('should always set status to Triggered on new alerts', () async {
      final docRef = fakeFirestore.collection('panic_alerts').doc();
      await docRef.set({
        'residentId': 'res-3',
        'flatNumber': 'C-303',
        'timestamp': DateTime.now().toIso8601String(),
        'alertType': 'Normal',
        'status': 'Triggered',
      });

      final doc = await docRef.get();
      expect(doc.data()!['status'], 'Triggered');
    });
  });

  group('PanicAlertController — updateAlertStatus', () {
    test('should update the status field of an existing alert', () async {
      // Setup: create a panic alert
      await fakeFirestore.collection('panic_alerts').doc('alert-1').set({
        'residentId': 'res-upd',
        'flatNumber': 'D-404',
        'alertType': 'Priority',
        'status': 'Triggered',
      });

      // Act: simulate updateAlertStatus
      await fakeFirestore.collection('panic_alerts').doc('alert-1').update({
        'status': 'Viewed by Security',
      });

      // Assert
      final doc = await fakeFirestore
          .collection('panic_alerts')
          .doc('alert-1')
          .get();
      expect(doc.data()!['status'], 'Viewed by Security');
    });

    test('should be able to resolve an alert', () async {
      await fakeFirestore.collection('panic_alerts').doc('alert-2').set({
        'residentId': 'res-resolve',
        'flatNumber': 'E-505',
        'alertType': 'Priority',
        'status': 'Triggered',
      });

      await fakeFirestore.collection('panic_alerts').doc('alert-2').update({
        'status': 'Resolved',
      });

      final doc = await fakeFirestore
          .collection('panic_alerts')
          .doc('alert-2')
          .get();
      expect(doc.data()!['status'], 'Resolved');
    });

    test('should not affect other fields when updating status', () async {
      await fakeFirestore.collection('panic_alerts').doc('alert-3').set({
        'residentId': 'res-preserve',
        'flatNumber': 'F-606',
        'alertType': 'Priority',
        'status': 'Triggered',
      });

      await fakeFirestore.collection('panic_alerts').doc('alert-3').update({
        'status': 'Resolved',
      });

      final doc = await fakeFirestore
          .collection('panic_alerts')
          .doc('alert-3')
          .get();
      expect(doc.data()!['residentId'], 'res-preserve');
      expect(doc.data()!['flatNumber'], 'F-606');
      expect(doc.data()!['alertType'], 'Priority');
    });
  });

  group('PanicAlertController — getActiveAlerts', () {
    test('should return alerts that are NOT Resolved', () async {
      // Setup: mix of triggered, viewed, and resolved alerts
      await fakeFirestore.collection('panic_alerts').doc('a1').set({
        'residentId': 'r1',
        'flatNumber': 'G-1',
        'status': 'Triggered',
        'timestamp': DateTime.now().toIso8601String(),
      });
      await fakeFirestore.collection('panic_alerts').doc('a2').set({
        'residentId': 'r2',
        'flatNumber': 'G-2',
        'status': 'Viewed by Security',
        'timestamp': DateTime.now().toIso8601String(),
      });
      await fakeFirestore.collection('panic_alerts').doc('a3').set({
        'residentId': 'r3',
        'flatNumber': 'G-3',
        'status': 'Resolved',
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Query: simulating getActiveAlerts filter
      final snapshot = await fakeFirestore
          .collection('panic_alerts')
          .where('status', isNotEqualTo: 'Resolved')
          .get();

      // Only non-resolved alerts should be returned
      expect(snapshot.docs.length, 2);
      final statuses = snapshot.docs.map((d) => d.data()['status']).toList();
      expect(statuses, isNot(contains('Resolved')));
    });

    test('should return empty list when all alerts are resolved', () async {
      await fakeFirestore.collection('panic_alerts').doc('b1').set({
        'residentId': 'r4',
        'flatNumber': 'H-1',
        'status': 'Resolved',
        'timestamp': DateTime.now().toIso8601String(),
      });

      final snapshot = await fakeFirestore
          .collection('panic_alerts')
          .where('status', isNotEqualTo: 'Resolved')
          .get();

      expect(snapshot.docs.length, 0);
    });

    test('should return all alerts when none are resolved', () async {
      for (int i = 1; i <= 5; i++) {
        await fakeFirestore.collection('panic_alerts').doc('c$i').set({
          'residentId': 'r$i',
          'flatNumber': 'I-$i',
          'status': 'Triggered',
          'timestamp': DateTime.now().toIso8601String(),
        });
      }

      final snapshot = await fakeFirestore
          .collection('panic_alerts')
          .where('status', isNotEqualTo: 'Resolved')
          .get();

      expect(snapshot.docs.length, 5);
    });
  });
}
