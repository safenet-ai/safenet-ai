import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/pages/role_selection.dart';

class ProfileSidebar extends StatelessWidget {
  final VoidCallback onClose;
  final String
  userCollection; // "workers", "users", "security", "authority", etc

  const ProfileSidebar({
    super.key,
    required this.onClose,
    required this.userCollection,
  });

  Future<String> _fetchName() async {
    String? uid;

    // For authority users, get UID from SharedPreferences
    if (userCollection == "authority") {
      final prefs = await SharedPreferences.getInstance();
      uid = prefs.getString('authority_uid');
    } else {
      // For other users, get UID from Firebase Auth
      uid = FirebaseAuth.instance.currentUser?.uid;
    }

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

  Future<void> _logout(BuildContext context) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Confirm Logout',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Logout',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    // If user cancelled, return
    if (confirm != true) return;

    try {
      // Sign out from Firebase Auth
      await FirebaseAuth.instance.signOut();

      // Clear all shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Navigate to role selection page and clear stack
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const RoleSelectionPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Logout failed: $e")));
      }
    }
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

          _btn(
            context,
            "Edit Profile",
            Icons.edit,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Edit Profile - Coming Soon")),
              );
            },
          ),
          const SizedBox(height: 16),
          _btn(
            context,
            "Settings",
            Icons.settings,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Settings - Coming Soon")),
              );
            },
          ),
          const SizedBox(height: 16),
          _btn(
            context,
            "Logout",
            Icons.logout,
            danger: true,
            onTap: () {
              _logout(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _btn(
    BuildContext context,
    String text,
    IconData icon, {
    bool danger = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
      ),
    );
  }
}
