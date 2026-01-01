import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ApprovalGate extends StatelessWidget {
  final Widget child;
  final String collection; // "users" or "workers"

  const ApprovalGate({
    super.key,
    required this.child,
    required this.collection,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;

        final status = data["approvalStatus"] ?? "pending";
        final isActive = data["isActive"] ?? false;

        // Approved → allow dashboard
        if (status == "approved" && isActive == true) {
          return child;
        }

        // Otherwise block UI
        return Scaffold(
          backgroundColor: Colors.black.withOpacity(0.4),
          body: Stack(
            children: [
              child, // blurred behind

              Container(
                color: Colors.black.withOpacity(0.55),
              ),

              Center(
                child: _approvalCard(status),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _approvalCard(String status) {
    String title;
    String message;
    Color color;

    if (status == "pending") {
      title = "Approval Pending";
      message =
          "Your registration is waiting for authority approval.\nPlease contact the authority.";
      color = Colors.orange;
    } else {
      title = "Access Rejected";
      message =
          "Your registration was rejected by the authority.\nPlease contact support.";
      color = Colors.red;
    }

    return Container(
      width: 320,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 12)
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 46, color: color),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15),
          ),
        ],
      ),
    );
  }
}
