import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../shared/widgets/profile_sidebar.dart';
import '../../shared/widgets/notification_dropdown.dart';

class VisitorManagementPage extends StatefulWidget {
  const VisitorManagementPage({super.key});

  @override
  State<VisitorManagementPage> createState() => _VisitorManagementPageState();
}

class _VisitorManagementPageState extends State<VisitorManagementPage> {
  bool _isProfileOpen = false;
  String selectedFilter = "Pending";

  final List<String> filters = [
    "All",
    "Pending",
    "Approved",
    "Checked-In",
    "Completed",
  ];

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
                        "Visitor Management",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      Row(
                        children: [
                          NotificationDropdown(role: "security"),
                          const SizedBox(width: 15),
                          GestureDetector(
                            onTap: () {
                              setState(() => _isProfileOpen = true);
                            },
                            child: _circleButton(Icons.person),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Filter tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: filters.map((filter) {
                        final isSelected = selectedFilter == filter;
                        return GestureDetector(
                          onTap: () => setState(() => selectedFilter = filter),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.blue.withOpacity(0.2)
                                  : Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.blue
                                    : Colors.white.withOpacity(0.5),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Text(
                              filter,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: isSelected
                                    ? Colors.blue
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Visitor list
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _getVisitorStream(),
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
                                "No visitors found",
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
                          return _visitorCard(visitors[index].id, data);
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
                userCollection: "workers",
                onClose: () => setState(() => _isProfileOpen = false),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getVisitorStream() {
    Query query = FirebaseFirestore.instance.collection("visitors");

    if (selectedFilter != "All") {
      query = query.where("status", isEqualTo: selectedFilter.toLowerCase());
    }

    return query.orderBy("timestamp", descending: true).snapshots();
  }

  Widget _visitorCard(String visitorId, Map<String, dynamic> data) {
    final status = data["status"] ?? "pending";
    final name = data["name"] ?? "Unknown";
    final phone = data["phone"] ?? "N/A";
    final purpose = data["purposeOfVisit"] ?? "N/A";
    final residentName = data["residentName"] ?? "Unknown";
    final flatNo = data["flatNo"] ?? "N/A";
    final expectedTime = data["expectedTime"] ?? "N/A";

    Color statusColor;
    IconData statusIcon;

    switch (status.toLowerCase()) {
      case "approved":
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case "checked-in":
        statusColor = Colors.blue;
        statusIcon = Icons.login;
        break;
      case "completed":
        statusColor = Colors.grey;
        statusIcon = Icons.done_all;
        break;
      case "rejected":
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
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
                  radius: 24,
                  backgroundColor: Colors.blue.withOpacity(0.2),
                  child: const Icon(Icons.person, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        phone,
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
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow(Icons.home, "Visiting: $residentName (Flat $flatNo)"),
            _infoRow(Icons.description, "Purpose: $purpose"),
            _infoRow(Icons.access_time, "Expected: $expectedTime"),

            // Action buttons
            if (status == "pending") ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _updateVisitorStatus(visitorId, "approved"),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text("Approve"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _updateVisitorStatus(visitorId, "rejected"),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text("Reject"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (status == "approved") ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _checkInVisitor(visitorId),
                icon: const Icon(Icons.login, size: 18),
                label: const Text("Check In"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ] else if (status == "checked-in") ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _checkOutVisitor(visitorId),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text("Check Out"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
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

  Future<void> _updateVisitorStatus(String visitorId, String status) async {
    try {
      await FirebaseFirestore.instance
          .collection("visitors")
          .doc(visitorId)
          .update({
            "status": status,
            "updatedAt": FieldValue.serverTimestamp(),
            "updatedBy": FirebaseAuth.instance.currentUser?.uid,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Visitor ${status == 'approved' ? 'approved' : 'rejected'}",
            ),
            backgroundColor: status == 'approved' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _checkInVisitor(String visitorId) async {
    try {
      await FirebaseFirestore.instance
          .collection("visitors")
          .doc(visitorId)
          .update({
            "status": "checked-in",
            "actualArrival": FieldValue.serverTimestamp(),
            "checkedInBy": FirebaseAuth.instance.currentUser?.uid,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Visitor checked in successfully"),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _checkOutVisitor(String visitorId) async {
    try {
      await FirebaseFirestore.instance
          .collection("visitors")
          .doc(visitorId)
          .update({
            "status": "completed",
            "actualDeparture": FieldValue.serverTimestamp(),
            "checkedOutBy": FirebaseAuth.instance.currentUser?.uid,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Visitor checked out successfully"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
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
