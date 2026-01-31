import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationDropdown extends StatefulWidget {
  final String role; // "user" or "authority"

  const NotificationDropdown({super.key, required this.role});

  @override
  State<NotificationDropdown> createState() => _NotificationDropdownState();
}

class _NotificationDropdownState extends State<NotificationDropdown> {
  OverlayEntry? _overlay;

  void toggle() {
    if (_overlay != null) {
      _overlay!.remove();
      _overlay = null;
      setState(() {});
    } else {
      _overlay = _createOverlay();
      Overlay.of(context).insert(_overlay!);
    }
  }

  Future<void> _clearAllNotifications() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    try {
      QuerySnapshot notifications;

      if (widget.role == "user" || widget.role == "worker") {
        notifications = await FirebaseFirestore.instance
            .collection("notifications")
            .where("toUid", isEqualTo: uid)
            .get();
      } else if (widget.role == "authority") {
        notifications = await FirebaseFirestore.instance
            .collection("notifications")
            .where("toRole", isEqualTo: "authority")
            .get();
      } else {
        return;
      }

      // Delete all notifications
      for (var doc in notifications.docs) {
        await doc.reference.delete();
      }

      // Close overlay after clearing
      if (_overlay != null) {
        _overlay!.remove();
        _overlay = null;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("All notifications cleared"),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error clearing notifications: $e"),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  OverlayEntry _createOverlay() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    Query query = FirebaseFirestore.instance
        .collection("notifications")
        .orderBy("timestamp", descending: true)
        .limit(6);

    if (widget.role == "user") {
      query = query.where("toUid", isEqualTo: uid);
    } else if (widget.role == "authority") {
      query = query.where("toRole", isEqualTo: "authority");
    } else if (widget.role == "worker") {
      // Workers should only see notifications specifically sent to them
      query = query.where("toUid", isEqualTo: uid);
    }

    return OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: toggle,
              child: Container(color: Colors.black.withOpacity(0.2)),
            ),
          ),

          Positioned(
            top: 70,
            right: 16,
            width: 330,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFBEEBFF).withOpacity(0.75), // aqua light
                        const Color(
                          0xFFDCF7FF,
                        ).withOpacity(0.55), // glass shine
                        const Color(
                          0xFFB4E8F5,
                        ).withOpacity(0.65), // liquid blue
                      ],
                    ),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.8),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withOpacity(0.25),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: Text(
                              "Notifications",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 26,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _clearAllNotifications,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.red.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.clear_all,
                                    size: 16,
                                    color: Colors.red.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Clear All",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      StreamBuilder<QuerySnapshot>(
                        stream: query.snapshots(),
                        builder: (_, snap) {
                          if (!snap.hasData) {
                            return const Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(),
                            );
                          }

                          final docs = snap.data!.docs; // ✅ ADD THIS LINE

                          if (docs.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(20),
                              child: Text("No notifications"),
                            );
                          }

                          return Column(
                            children: docs.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.85),
                                      const Color(0xFFE3F8FF).withOpacity(0.75),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.7),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blueAccent.withOpacity(
                                        0.12,
                                      ),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),

                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Colors.blueGrey.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.notifications_active,
                                        size: 18,
                                        color: Colors.blueGrey,
                                      ),
                                    ),

                                    const SizedBox(width: 12),

                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            data["title"] ?? "Notification",
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            data["message"] ?? "",
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: toggle,
      child: _circleIcon(Icons.notifications_none),
    );
  }
}

Widget _circleIcon(IconData icon) {
  return Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.white70, // ✅ PURE WHITE BACKGROUND
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: Colors.black12, // ✅ soft shadow
          blurRadius: 8,
          offset: const Offset(2, 2),
        ),
      ],
    ),
    child: Icon(icon, color: Colors.black87, size: 22),
  );
}
