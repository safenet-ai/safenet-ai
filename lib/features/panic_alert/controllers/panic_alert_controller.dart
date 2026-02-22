import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:safenetai/features/panic_alert/models/panic_alert_model.dart';

class PanicAlertController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Triggers a panic alert. Fetches location and saves to Firestore.
  /// This function acts as the bridge between the hardware trigger and the database.
  Future<void> triggerAlert({
    required String residentId,
    required String flatNumber,
    String alertType = 'Priority',
  }) async {
    try {
      await _saveAlert(residentId, flatNumber, alertType);
      debugPrint("Panic Alert Successfully Triggered and Saved.");
    } catch (e) {
      debugPrint("Error triggering panic alert: $e");
      await _saveAlert(residentId, flatNumber, alertType);
    }
  }

  Future<void> _saveAlert(
    String residentId,
    String flatNumber,
    String alertType,
  ) async {
    try {
      final docRef = _firestore.collection('panic_alerts').doc();
      final alert = PanicAlertModel(
        id: docRef.id,
        residentId: residentId,
        flatNumber: flatNumber,
        timestamp: DateTime.now(),
        alertType: alertType,
        status: 'Triggered',
      );

      await docRef.set(alert.toMap());
    } catch (e) {
      debugPrint("Failed to save panic alert to Firestore: $e");
    }
  }

  /// Updates the status of an alert (e.g. from Security Dashboard)
  Future<void> updateAlertStatus(String alertId, String newStatus) async {
    try {
      await _firestore.collection('panic_alerts').doc(alertId).update({
        'status': newStatus,
      });
    } catch (e) {
      debugPrint("Error updating alert status: $e");
    }
  }

  /// Stream to listen for active panic alerts (used by Security and Authority Dashboards)
  Stream<List<PanicAlertModel>> getActiveAlerts() {
    return _firestore
        .collection('panic_alerts')
        .where('status', isNotEqualTo: 'Resolved')
        .orderBy('status')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => PanicAlertModel.fromMap(doc.data(), doc.id))
              .toList();
        });
  }
}
