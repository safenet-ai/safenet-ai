import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/notification_service.dart';

class NotificationDropdown extends StatefulWidget {
  final String role; // "user", "worker", "security", or "authority"

  const NotificationDropdown({super.key, required this.role});

  @override
  State<NotificationDropdown> createState() => _NotificationDropdownState();
}

class _NotificationDropdownState extends State<NotificationDropdown> {
  OverlayEntry? _overlay;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _listenToUnreadCount();
  }

  @override
  void dispose() {
    // Clean up overlay when widget is disposed
    if (_overlay != null) {
      _overlay!.remove();
      _overlay = null;
    }
    super.dispose();
  }

  void _listenToUnreadCount() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    Query query = FirebaseFirestore.instance
        .collection("notifications")
        .where("isRead", isEqualTo: false);

    if (widget.role == "user" ||
        widget.role == "worker" ||
        widget.role == "security" ||
        widget.role == "resident") {
      query = query.where("toUid", isEqualTo: uid);
    } else if (widget.role == "authority") {
      query = query.where("toRole", isEqualTo: "authority");
    }

    query.snapshots().listen((snapshot) {
      if (mounted) {
        setState(() {
          _unreadCount = snapshot.docs.length;
        });
      }
    });
  }

  Future<void> _markAllAsRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null && widget.role != "authority") return;

    try {
      QuerySnapshot notifications;

      if (widget.role == "user" ||
          widget.role == "worker" ||
          widget.role == "security" ||
          widget.role == "resident") {
        notifications = await FirebaseFirestore.instance
            .collection("notifications")
            .where("toUid", isEqualTo: uid)
            .where("isRead", isEqualTo: false)
            .get();
      } else if (widget.role == "authority") {
        notifications = await FirebaseFirestore.instance
            .collection("notifications")
            .where("toRole", isEqualTo: "authority")
            .where("isRead", isEqualTo: false)
            .get();
      } else {
        return;
      }

      // Mark all as read in batch
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in notifications.docs) {
        batch.update(doc.reference, {"isRead": true});
      }
      await batch.commit();
    } catch (e) {
      // Silently handle error
      debugPrint("Error marking notifications as read: $e");
    }
  }

  void toggle() {
    if (_overlay != null) {
      _markAllAsRead(); // Mark as read when closing
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
    if (uid == null && widget.role != "authority") return;

    try {
      QuerySnapshot notifications;

      if (widget.role == "user" ||
          widget.role == "worker" ||
          widget.role == "security" ||
          widget.role == "resident") {
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

      // Delete all notifications in batch
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in notifications.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Close overlay after clearing
      if (_overlay != null) {
        _overlay!.remove();
        _overlay = null;
        setState(() {});
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

    // Build query based on role
    Query query = FirebaseFirestore.instance.collection("notifications");

    if (widget.role == "user" ||
        widget.role == "worker" ||
        widget.role == "security" ||
        widget.role == "resident") {
      if (uid != null) {
        query = query
            .where("toUid", isEqualTo: uid)
            .orderBy("timestamp", descending: true)
            .limit(20);
      }
    } else if (widget.role == "authority") {
      query = query
          .where("toRole", isEqualTo: "authority")
          .orderBy("timestamp", descending: true)
          .limit(20);
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
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
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
                          const Color(
                            0xFFBEEBFF,
                          ).withOpacity(0.75), // aqua light
                          const Color(
                            0xFFDCF7FF,
                          ).withOpacity(0.55), // glass shine
                          const Color(
                            0xFFB4E8F5,
                          ).withOpacity(0.65), // liquid blue
                        ],
                      ),
                      borderRadius: BorderRadius.circular(26),
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
                        const Center(
                          child: Text(
                            "Notifications",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 26,
                              color: Colors.black87,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        Center(
                          child: GestureDetector(
                            onTap: _clearAllNotifications,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
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
                                  const SizedBox(width: 6),
                                  Text(
                                    "Clear All",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),
                        
                        // TEST NOTIFICATION BUTTON (Verification)
                        Center(
                          child: Wrap(
                            spacing: 8,
                            children: [
                              _testButton(label: "Normal", priority: "normal", color: Colors.blue),
                              _testButton(label: "Medium", priority: "medium", color: Colors.orange),
                              _testButton(label: "URGENT", priority: "urgent", color: Colors.red),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        Flexible(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: query.snapshots(),
                            builder: (_, snap) {
                              if (snap.connectionState ==
                                  ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              if (!snap.hasData || snap.data!.docs.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Center(
                                    child: Text(
                                      "No notifications",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.black54,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              final docs = snap.data!.docs;

                              return ListView.builder(
                                shrinkWrap: true,
                                itemCount: docs.length,
                                itemBuilder: (context, index) {
                                  final data =
                                      docs[index].data()
                                          as Map<String, dynamic>;
                                  final isRead = data["isRead"] ?? false;

                                  return Opacity(
                                    opacity: isRead ? 0.5 : 1.0,
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white.withOpacity(0.85),
                                            const Color(
                                              0xFFE3F8FF,
                                            ).withOpacity(0.75),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(18),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.blueAccent
                                                .withOpacity(0.12),
                                            blurRadius: 12,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),

                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: Colors.blueGrey
                                                  .withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              isRead
                                                  ? Icons.notifications_outlined
                                                  : Icons.notifications_active,
                                              size: 18,
                                              color: isRead
                                                  ? Colors.grey
                                                  : Colors.blueGrey,
                                            ),
                                          ),

                                          const SizedBox(width: 12),

                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    if (!isRead) ...[
                                                      Container(
                                                        width: 8,
                                                        height: 8,
                                                        decoration:
                                                            const BoxDecoration(
                                                              color: Colors.red,
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                    ],
                                                    Expanded(
                                                      child: Text(
                                                        data["title"] ??
                                                            "Notification",
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: Colors.black87,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
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
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
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
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _circleIcon(Icons.notifications_none),
          if (_unreadCount > 0)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Center(
                  child: Text(
                    _unreadCount > 9 ? '9+' : _unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _testButton({
    required String label,
    required String priority,
    required MaterialColor color,
  }) {
    return GestureDetector(
      onTap: () async {
        await NotificationService.sendNotification(
          toRole: widget.role,
          userRole: widget.role,
          title: "$label Priority Test",
          body: "This is a ${label.toLowerCase()} priority security update.",
          type: "test_$priority",
          priority: priority,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color.shade700,
          ),
        ),
      ),
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
