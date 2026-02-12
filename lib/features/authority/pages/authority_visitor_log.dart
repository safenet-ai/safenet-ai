import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/widgets/profile_sidebar.dart';

class AuthorityVisitorLogPage extends StatefulWidget {
  const AuthorityVisitorLogPage({super.key});

  @override
  State<AuthorityVisitorLogPage> createState() =>
      _AuthorityVisitorLogPageState();
}

class _AuthorityVisitorLogPageState extends State<AuthorityVisitorLogPage> {
  bool _isProfileOpen = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset('assets/bg1_img.png', fit: BoxFit.cover),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),

                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _circleButton(
                        Icons.arrow_back,
                        onTap: () => Navigator.pop(context),
                      ),

                      const Text(
                        "Visitor Log",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      GestureDetector(
                        onTap: () {
                          setState(() => _isProfileOpen = true);
                        },
                        child: _circleButton(Icons.person),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Visitor list
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection("visitors")
                        .orderBy("timestamp", descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "No visitors logged yet",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final visitors = snapshot.data!.docs;

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: visitors.length,
                        itemBuilder: (context, index) {
                          final data =
                              visitors[index].data() as Map<String, dynamic>;

                          // Show date header if it's a new date
                          final showDateHeader = _shouldShowDateHeader(
                            visitors,
                            index,
                          );

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showDateHeader)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 8,
                                    bottom: 12,
                                    left: 4,
                                  ),
                                  child: Text(
                                    _getDateLabel(data["timestamp"]),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              _visitorCard(data),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Profile sidebar
          if (_isProfileOpen) ...[
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _isProfileOpen = false),
                child: Container(color: Colors.black.withOpacity(0.35)),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              top: 0,
              bottom: 0,
              right: 0,
              width: 280,
              child: ProfileSidebar(
                userCollection: "authority",
                onClose: () => setState(() => _isProfileOpen = false),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _shouldShowDateHeader(List<QueryDocumentSnapshot> visitors, int index) {
    if (index == 0) return true;

    final currentData = visitors[index].data() as Map<String, dynamic>;
    final previousData = visitors[index - 1].data() as Map<String, dynamic>;

    final currentDate = _getDateFromTimestamp(currentData["timestamp"]);
    final previousDate = _getDateFromTimestamp(previousData["timestamp"]);

    return currentDate != previousDate;
  }

  String _getDateFromTimestamp(dynamic timestamp) {
    if (timestamp == null) return "";
    final dt = (timestamp as Timestamp).toDate();
    return "${dt.year}-${dt.month}-${dt.day}";
  }

  String _getDateLabel(dynamic timestamp) {
    if (timestamp == null) return "Unknown";

    final dt = (timestamp as Timestamp).toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final visitorDate = DateTime(dt.year, dt.month, dt.day);

    if (visitorDate == today) {
      return "Today";
    } else if (visitorDate == yesterday) {
      return "Yesterday";
    } else {
      final months = [
        "Jan",
        "Feb",
        "Mar",
        "Apr",
        "May",
        "Jun",
        "Jul",
        "Aug",
        "Sep",
        "Oct",
        "Nov",
        "Dec",
      ];
      return "${months[dt.month - 1]} ${dt.day}, ${dt.year}";
    }
  }

  Widget _visitorCard(Map<String, dynamic> data) {
    final status = data["status"] ?? "checked-in";
    final name = data["name"] ?? "Unknown";
    final phone = data["phone"] ?? "N/A";
    final purpose = data["purposeOfVisit"] ?? "N/A";
    final flatNo = data["flatNo"] ?? "N/A";
    final isActive = status == "checked-in";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.white.withOpacity(0.95)
            : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: isActive
            ? Border.all(color: Colors.blue.withOpacity(0.5), width: 1)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: isActive ? Colors.blue : Colors.grey,
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isActive ? Colors.black87 : Colors.grey[700],
                        ),
                      ),
                      Text(
                        "$flatNo • $phone",
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.green.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? "ACTIVE" : "OUT",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isActive ? Colors.green : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow(Icons.description, "Purpose: $purpose"),
            if (data["actualArrival"] != null)
              _infoRow(
                Icons.login,
                "In: ${_formatTimestamp(data["actualArrival"])}",
              ),
            if (data["actualDeparture"] != null)
              _infoRow(
                Icons.logout,
                "Out: ${_formatTimestamp(data["actualDeparture"])}",
              ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final dt = timestamp.toDate();
      return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}, ${dt.day}/${dt.month}";
    }
    return "N/A";
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.35),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.6)),
            ),
            child: Icon(icon, size: 22),
          ),
        ),
      ),
    );
  }
}
