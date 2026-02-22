import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationDropdown extends StatefulWidget {
  final String role; // "user", "worker", "security", or "authority"

  const NotificationDropdown({super.key, required this.role});

  @override
  State<NotificationDropdown> createState() => _NotificationDropdownState();
}

class _NotificationDropdownState extends State<NotificationDropdown> {
  OverlayEntry? _overlay;
  int _unreadCount = 0;
  StreamSubscription? _unreadSub1;
  StreamSubscription? _unreadSub2;

  @override
  void initState() {
    super.initState();
    _listenToUnreadCount();
  }

  @override
  void dispose() {
    _unreadSub1?.cancel();
    _unreadSub2?.cancel();
    if (_overlay != null) {
      _overlay!.remove();
      _overlay = null;
    }
    super.dispose();
  }

  /// Returns true if this role should see role-based notifications
  bool get _needsRoleQuery {
    return widget.role == "authority" || widget.role == "security";
  }

  void _listenToUnreadCount() async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    // For authority, UID may come from SharedPreferences
    if (uid == null && widget.role == "authority") {
      final prefs = await SharedPreferences.getInstance();
      uid = prefs.getString('authority_uid');
    }

    int uidCount = 0;
    int roleCount = 0;

    void updateCount(int fromUid, int fromRole) {
      if (mounted) {
        setState(() {
          _unreadCount = fromUid + fromRole;
        });
      }
    }

    // Query 1: UID-based notifications (for all roles except pure authority)
    if (uid != null && widget.role != "authority") {
      final uidQuery = FirebaseFirestore.instance
          .collection("notifications")
          .where("isRead", isEqualTo: false)
          .where("toUid", isEqualTo: uid);

      _unreadSub1 = uidQuery.snapshots().listen((snapshot) {
        uidCount = snapshot.docs.length;
        updateCount(uidCount, roleCount);
      });
    }

    // Query 2: Role-based notifications (security sees toRole=='security', authority sees toRole=='authority')
    if (_needsRoleQuery) {
      final roleQuery = FirebaseFirestore.instance
          .collection("notifications")
          .where("isRead", isEqualTo: false)
          .where("toRole", isEqualTo: widget.role);

      _unreadSub2 = roleQuery.snapshots().listen((snapshot) {
        roleCount = snapshot.docs.length;
        updateCount(uidCount, roleCount);
      });
    }
  }

  Future<void> _markAllAsRead() async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null && widget.role == "authority") {
      final prefs = await SharedPreferences.getInstance();
      uid = prefs.getString('authority_uid');
    }
    if (uid == null && widget.role != "authority") return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      // UID-based notifications
      if (uid != null && widget.role != "authority") {
        final uidNotifs = await FirebaseFirestore.instance
            .collection("notifications")
            .where("toUid", isEqualTo: uid)
            .where("isRead", isEqualTo: false)
            .get();
        for (var doc in uidNotifs.docs) {
          batch.update(doc.reference, {"isRead": true});
        }
      }

      // Role-based notifications
      if (_needsRoleQuery) {
        final roleNotifs = await FirebaseFirestore.instance
            .collection("notifications")
            .where("toRole", isEqualTo: widget.role)
            .where("isRead", isEqualTo: false)
            .get();
        for (var doc in roleNotifs.docs) {
          batch.update(doc.reference, {"isRead": true});
        }
      }

      await batch.commit();
    } catch (e) {
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
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null && widget.role == "authority") {
      final prefs = await SharedPreferences.getInstance();
      uid = prefs.getString('authority_uid');
    }
    if (uid == null && widget.role != "authority") return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      // UID-based notifications
      if (uid != null && widget.role != "authority") {
        final uidNotifs = await FirebaseFirestore.instance
            .collection("notifications")
            .where("toUid", isEqualTo: uid)
            .get();
        for (var doc in uidNotifs.docs) {
          batch.delete(doc.reference);
        }
      }

      // Role-based notifications
      if (_needsRoleQuery) {
        final roleNotifs = await FirebaseFirestore.instance
            .collection("notifications")
            .where("toRole", isEqualTo: widget.role)
            .get();
        for (var doc in roleNotifs.docs) {
          batch.delete(doc.reference);
        }
      }

      await batch.commit();

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

    // Build queries based on role — security/authority need both UID + role queries
    final List<Query> queries = [];

    // UID-based query
    if (uid != null && widget.role != "authority") {
      queries.add(
        FirebaseFirestore.instance
            .collection("notifications")
            .where("toUid", isEqualTo: uid)
            .orderBy("timestamp", descending: true)
            .limit(20),
      );
    }

    // Role-based query
    if (_needsRoleQuery) {
      queries.add(
        FirebaseFirestore.instance
            .collection("notifications")
            .where("toRole", isEqualTo: widget.role)
            .orderBy("timestamp", descending: true)
            .limit(20),
      );
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

                        Flexible(child: _buildMergedNotificationList(queries)),
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

  /// Merges results from multiple Firestore queries into a single sorted list
  Widget _buildMergedNotificationList(List<Query> queries) {
    if (queries.isEmpty) {
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

    // For a single query, use simple StreamBuilder
    if (queries.length == 1) {
      return StreamBuilder<QuerySnapshot>(
        stream: queries[0].snapshots(),
        builder: (_, snap) => _buildNotifList(snap),
      );
    }

    // For two queries (UID + role), merge both streams
    return StreamBuilder<List<QuerySnapshot>>(
      stream: _mergeStreams(queries),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snap.hasData) {
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

        // Merge and deduplicate docs from all queries
        final Map<String, QueryDocumentSnapshot> mergedDocs = {};
        for (var querySnap in snap.data!) {
          for (var doc in querySnap.docs) {
            mergedDocs[doc.id] = doc;
          }
        }

        final docs = mergedDocs.values.toList();
        // Sort by timestamp descending
        docs.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)['timestamp'];
          final bTime = (b.data() as Map<String, dynamic>)['timestamp'];
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return (bTime as Timestamp).compareTo(aTime as Timestamp);
        });

        if (docs.isEmpty) {
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

        return ListView.builder(
          shrinkWrap: true,
          itemCount: docs.length,
          itemBuilder: (context, index) =>
              _buildNotifTile(docs[index].data() as Map<String, dynamic>),
        );
      },
    );
  }

  Stream<List<QuerySnapshot>> _mergeStreams(List<Query> queries) {
    final streams = queries.map((q) => q.snapshots()).toList();
    // Use combineLatest pattern with StreamGroup
    return streams[0].asyncExpand((first) {
      return streams[1].map((second) => [first, second]);
    });
  }

  Widget _buildNotifList(AsyncSnapshot<QuerySnapshot> snap) {
    if (snap.connectionState == ConnectionState.waiting) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
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
      itemBuilder: (context, index) =>
          _buildNotifTile(docs[index].data() as Map<String, dynamic>),
    );
  }

  Widget _buildNotifTile(Map<String, dynamic> data) {
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
              const Color(0xFFE3F8FF).withOpacity(0.75),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withOpacity(0.12),
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
              child: Icon(
                isRead
                    ? Icons.notifications_outlined
                    : Icons.notifications_active,
                size: 18,
                color: isRead ? Colors.grey : Colors.blueGrey,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (!isRead) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          data["title"] ?? "Notification",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data["message"] ?? "",
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
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
