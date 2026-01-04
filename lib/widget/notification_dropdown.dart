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
    } else {
      _overlay = _createOverlay();
      Overlay.of(context).insert(_overlay!);
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
    } else {
      query = query.where("target", isEqualTo: "authority");
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
                    color: Colors.white.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: Colors.white.withOpacity(0.8)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Notifications",
                          style: TextStyle(fontWeight: FontWeight.w700,fontSize: 20,color: Colors.black87)),

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

                          final docs = snap.data!.docs;   // ✅ ADD THIS LINE

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
                                  color: Colors.white.withOpacity(0.65),
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
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
                                        crossAxisAlignment: CrossAxisAlignment.start,
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
                      )
                    ],
                  ),
                ),
              ),
            ),
          )
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


