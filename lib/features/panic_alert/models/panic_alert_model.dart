import 'package:cloud_firestore/cloud_firestore.dart';

class PanicAlertModel {
  final String id;
  final String residentId;
  final String flatNumber;
  final DateTime timestamp;
  final String alertType; // 'Normal' or 'Priority'
  final String status; // 'Triggered', 'Viewed by Security', 'Resolved'

  PanicAlertModel({
    required this.id,
    required this.residentId,
    required this.flatNumber,
    required this.timestamp,
    required this.alertType,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'residentId': residentId,
      'flatNumber': flatNumber,
      'timestamp': FieldValue.serverTimestamp(),
      'alertType': alertType,
      'status': status,
    };
  }

  factory PanicAlertModel.fromMap(Map<String, dynamic> map, String documentId) {
    return PanicAlertModel(
      id: documentId,
      residentId: map['residentId'] ?? '',
      flatNumber: map['flatNumber'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      alertType: map['alertType'] ?? 'Priority',
      status: map['status'] ?? 'Triggered',
    );
  }
}
