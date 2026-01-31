import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileSidebar extends StatelessWidget {
  final VoidCallback onClose;
  final String userCollection; // "workers", "users", "security", etc

  const ProfileSidebar({
    super.key,
    required this.onClose,
    required this.userCollection,
  });

  Future<String> _fetchName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return "User";

    final doc = await FirebaseFirestore.instance
        .collection(userCollection)
        .doc(uid)
        .get();

    if (doc.exists && doc.data()!.containsKey("username")) {
      return doc["username"];
    }
    return "User";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          bottomLeft: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(-6, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              onTap: onClose,
              child: const Icon(Icons.close, size: 22),
            ),
          ),

          const SizedBox(height: 20),

          const CircleAvatar(
            radius: 42,
            backgroundColor: Colors.blueGrey,
            child: Icon(Icons.person, size: 42, color: Colors.white),
          ),

          const SizedBox(height: 12),

          FutureBuilder<String>(
            future: _fetchName(),
            builder: (context, snapshot) {
              return Text(
                snapshot.data ?? "User",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              );
            },
          ),

          const SizedBox(height: 30),

          _btn("Edit Profile", Icons.edit),
          const SizedBox(height: 16),
          _btn("Upload Details", Icons.assignment),
          const SizedBox(height: 16),
          _btn("Logout", Icons.logout, danger: true),
        ],
      ),
    );
  }

  Widget _btn(String text, IconData icon, {bool danger = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: danger ? Colors.red.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: danger ? Colors.red : Colors.black54),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: danger ? Colors.red : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
