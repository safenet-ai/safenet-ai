import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:safenetai/features/panic_alert/models/panic_alert_model.dart';

void main() {
  group('PanicAlertModel', () {
    group('toMap()', () {
      test('should return a map with all required keys', () {
        final model = PanicAlertModel(
          id: 'test-id-123',
          residentId: 'resident-456',
          flatNumber: 'A-101',
          timestamp: DateTime(2026, 2, 22, 14, 30),
          alertType: 'Priority',
          status: 'Triggered',
        );

        final map = model.toMap();

        expect(map.containsKey('residentId'), isTrue);
        expect(map.containsKey('flatNumber'), isTrue);
        expect(map.containsKey('timestamp'), isTrue);
        expect(map.containsKey('alertType'), isTrue);
        expect(map.containsKey('status'), isTrue);
      });

      test('should map field values correctly', () {
        final model = PanicAlertModel(
          id: 'test-id',
          residentId: 'resident-789',
          flatNumber: 'B-202',
          timestamp: DateTime.now(),
          alertType: 'Normal',
          status: 'Viewed by Security',
        );

        final map = model.toMap();

        expect(map['residentId'], 'resident-789');
        expect(map['flatNumber'], 'B-202');
        expect(map['alertType'], 'Normal');
        expect(map['status'], 'Viewed by Security');
      });

      test('should use FieldValue.serverTimestamp() for timestamp', () {
        final model = PanicAlertModel(
          id: 'test-id',
          residentId: 'r1',
          flatNumber: 'C-303',
          timestamp: DateTime.now(),
          alertType: 'Priority',
          status: 'Triggered',
        );

        final map = model.toMap();

        // FieldValue.serverTimestamp() returns a FieldValue, not a DateTime
        expect(map['timestamp'], isA<FieldValue>());
      });

      test('should NOT include the document id in the map', () {
        final model = PanicAlertModel(
          id: 'should-not-appear',
          residentId: 'r1',
          flatNumber: 'D-404',
          timestamp: DateTime.now(),
          alertType: 'Priority',
          status: 'Triggered',
        );

        final map = model.toMap();

        expect(map.containsKey('id'), isFalse);
      });
    });

    group('fromMap()', () {
      test('should construct model from a complete map', () {
        final timestamp = Timestamp.fromDate(DateTime(2026, 2, 22, 10, 0));
        final map = {
          'residentId': 'res-100',
          'flatNumber': 'E-505',
          'timestamp': timestamp,
          'alertType': 'Priority',
          'status': 'Triggered',
        };

        final model = PanicAlertModel.fromMap(map, 'doc-id-1');

        expect(model.id, 'doc-id-1');
        expect(model.residentId, 'res-100');
        expect(model.flatNumber, 'E-505');
        expect(model.timestamp, timestamp.toDate());
        expect(model.alertType, 'Priority');
        expect(model.status, 'Triggered');
      });

      test('should handle missing residentId with empty string default', () {
        final map = {
          'flatNumber': 'F-606',
          'timestamp': Timestamp.now(),
          'alertType': 'Normal',
          'status': 'Resolved',
        };

        final model = PanicAlertModel.fromMap(map, 'doc-2');

        expect(model.residentId, '');
      });

      test('should handle missing flatNumber with empty string default', () {
        final map = {
          'residentId': 'res-200',
          'timestamp': Timestamp.now(),
          'alertType': 'Normal',
          'status': 'Resolved',
        };

        final model = PanicAlertModel.fromMap(map, 'doc-3');

        expect(model.flatNumber, '');
      });

      test('should handle null timestamp with DateTime.now() fallback', () {
        final map = {
          'residentId': 'res-300',
          'flatNumber': 'G-707',
          'timestamp': null,
          'alertType': 'Priority',
          'status': 'Triggered',
        };

        final before = DateTime.now();
        final model = PanicAlertModel.fromMap(map, 'doc-4');
        final after = DateTime.now();

        // The fallback DateTime.now() should be between before and after
        expect(
          model.timestamp.isAfter(before.subtract(const Duration(seconds: 1))),
          isTrue,
        );
        expect(
          model.timestamp.isBefore(after.add(const Duration(seconds: 1))),
          isTrue,
        );
      });

      test('should default alertType to "Priority" when missing', () {
        final map = {
          'residentId': 'res-400',
          'flatNumber': 'H-808',
          'timestamp': Timestamp.now(),
          'status': 'Triggered',
        };

        final model = PanicAlertModel.fromMap(map, 'doc-5');

        expect(model.alertType, 'Priority');
      });

      test('should default status to "Triggered" when missing', () {
        final map = {
          'residentId': 'res-500',
          'flatNumber': 'I-909',
          'timestamp': Timestamp.now(),
          'alertType': 'Normal',
        };

        final model = PanicAlertModel.fromMap(map, 'doc-6');

        expect(model.status, 'Triggered');
      });

      test('should handle completely empty map with safe defaults', () {
        final map = <String, dynamic>{};

        final model = PanicAlertModel.fromMap(map, 'doc-7');

        expect(model.id, 'doc-7');
        expect(model.residentId, '');
        expect(model.flatNumber, '');
        expect(model.alertType, 'Priority');
        expect(model.status, 'Triggered');
      });
    });

    group('Firestore round-trip', () {
      test('should write and read correctly from FakeFirestore', () async {
        final fakeFirestore = FakeFirebaseFirestore();

        // Write using raw map (bypassing FieldValue.serverTimestamp()
        // which FakeFirestore cannot process in the same way as real Firestore)
        await fakeFirestore.collection('panic_alerts').doc('roundtrip-1').set({
          'residentId': 'res-rt',
          'flatNumber': 'RT-101',
          'timestamp': Timestamp.fromDate(DateTime(2026, 1, 1)),
          'alertType': 'Priority',
          'status': 'Triggered',
        });

        // Read
        final snapshot = await fakeFirestore
            .collection('panic_alerts')
            .doc('roundtrip-1')
            .get();

        final readModel = PanicAlertModel.fromMap(
          snapshot.data()!,
          snapshot.id,
        );

        expect(readModel.id, 'roundtrip-1');
        expect(readModel.residentId, 'res-rt');
        expect(readModel.flatNumber, 'RT-101');
        expect(readModel.alertType, 'Priority');
        expect(readModel.status, 'Triggered');
        expect(readModel.timestamp, DateTime(2026, 1, 1));
      });
    });
  });
}
