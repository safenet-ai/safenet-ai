import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../shared/widgets/profile_sidebar.dart';
import '../../shared/widgets/notification_dropdown.dart';
import '../../../services/notification_service.dart';
import 'security_request_detail.dart';

class SecurityRequestsPage extends StatefulWidget {
  const SecurityRequestsPage({super.key});

  @override
  State<SecurityRequestsPage> createState() => _SecurityRequestsPageState();
}

class _SecurityRequestsPageState extends State<SecurityRequestsPage> {
  bool _isProfileOpen = false;
  String selectedFilter = "Pending";

  final List<String> filters = [
    "All",
    "Pending",
    "Assigned",
    "In Progress",
    "Resolved",
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
                        "Security Requests",
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
                                  ? Colors.red.withOpacity(0.2)
                                  : Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.red
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
                                color: isSelected ? Colors.red : Colors.black87,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Request list
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _getRequestStream(),
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
                                Icons.security,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "No security requests found",
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

                      final requests = snapshot.data!.docs;

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: requests.length,
                        itemBuilder: (context, index) {
                          final data =
                              requests[index].data() as Map<String, dynamic>;
                          return _requestCard(requests[index].id, data);
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

  Stream<QuerySnapshot> _getRequestStream() {
    Query query = FirebaseFirestore.instance.collection("security_requests");

    if (selectedFilter != "All") {
      String filterStatus = selectedFilter.toLowerCase().replaceAll(' ', '_');
      query = query.where("status", isEqualTo: filterStatus);
    }

    return query.orderBy("timestamp", descending: true).snapshots();
  }

  Widget _requestCard(String requestId, Map<String, dynamic> data) {
    final status = data["status"] ?? "pending";
    final requestType = data["requestType"] ?? "Unknown";
    final description = data["description"] ?? "No description";
    final residentName = data["residentName"] ?? "Unknown";
    final flatNo = data["flatNo"] ?? "N/A";
    final location = data["location"] ?? "N/A";
    final priority = data["priority"] ?? "normal";

    Color priorityColor;
    IconData requestIcon;

    switch (priority.toLowerCase()) {
      case "urgent":
        priorityColor = Colors.red;
        break;
      case "medium":
        priorityColor = Colors.orange;
        break;
      default:
        priorityColor = Colors.blue;
    }

    switch (requestType.toLowerCase()) {
      case "suspicious_activity":
        requestIcon = Icons.visibility;
        break;
      case "emergency":
        requestIcon = Icons.warning;
        break;
      case "parking_issue":
        requestIcon = Icons.local_parking;
        break;
      case "noise_complaint":
        requestIcon = Icons.volume_up;
        break;
      default:
        requestIcon = Icons.help_outline;
    }

    Color statusColor;
    String statusDisplay;

    switch (status.toLowerCase()) {
      case "assigned":
        statusColor = Colors.blue;
        statusDisplay = "ASSIGNED";
        break;
      case "in_progress":
        statusColor = Colors.orange;
        statusDisplay = "IN PROGRESS";
        break;
      case "resolved":
        statusColor = Colors.green;
        statusDisplay = "RESOLVED";
        break;
      default:
        statusColor = Colors.red;
        statusDisplay = "PENDING";
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SecurityRequestDetailPage(
              requestId: requestId,
              requestData: data,
            ),
          ),
        );
      },
      child: Container(
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
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(requestIcon, color: priorityColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          requestType.replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          "$residentName • Flat $flatNo",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      priority.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: priorityColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  description,
                  style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                ),
              ),
              const SizedBox(height: 8),
              _infoRow(Icons.location_on, location),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.circle, size: 12, color: statusColor),
                  const SizedBox(width: 6),
                  Text(
                    statusDisplay,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ],
              ),

              // Action buttons
              if (status == "pending") ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _assignToSelf(requestId),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text("Accept & Assign to Me"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ] else if (status == "assigned") ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _markInProgress(requestId),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text("Start Working"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ] else if (status == "in_progress") ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _showResolveDialog(requestId),
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text("Mark as Resolved"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
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
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
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
    );
  }

  Future<void> _assignToSelf(String requestId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get request data to find resident
      final requestDoc = await FirebaseFirestore.instance
          .collection("security_requests")
          .doc(requestId)
          .get();

      final residentId = requestDoc.data()?["residentId"];
      final requestType =
          requestDoc.data()?["requestType"] ?? "security request";

      // Get security officer name
      final securityDoc = await FirebaseFirestore.instance
          .collection("workers")
          .doc(currentUser.uid)
          .get();
      final securityName =
          securityDoc.data()?["username"] ?? "Security Officer";

      await FirebaseFirestore.instance
          .collection("security_requests")
          .doc(requestId)
          .update({
            "status": "assigned",
            "assignedTo": currentUser.uid,
            "assignedAt": FieldValue.serverTimestamp(),
          });

      // Send notification to resident
      if (residentId != null) {
        await NotificationService.sendNotification(
          userId: residentId,
          userRole: 'user',
          title: "Request Accepted",
          body: "$securityName has accepted your ${requestType.replaceAll('_', ' ')} request and will address it soon.",
          type: "security_request_update",
          additionalData: {"requestId": requestId},
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Request assigned to you"),
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

  Future<void> _markInProgress(String requestId) async {
    try {
      // Get request data to find resident
      final requestDoc = await FirebaseFirestore.instance
          .collection("security_requests")
          .doc(requestId)
          .get();

      final residentId = requestDoc.data()?["residentId"];
      final requestType =
          requestDoc.data()?["requestType"] ?? "security request";

      await FirebaseFirestore.instance
          .collection("security_requests")
          .doc(requestId)
          .update({
            "status": "in_progress",
            "startedAt": FieldValue.serverTimestamp(),
          });

      // Send notification to resident
      if (residentId != null) {
        await NotificationService.sendNotification(
          userId: residentId,
          userRole: 'user',
          title: "Work Started",
          body: "Security has started working on your ${requestType.replaceAll('_', ' ')} request.",
          type: "security_request_update",
          additionalData: {"requestId": requestId},
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Status updated to In Progress"),
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

  Future<void> _showResolveDialog(String requestId) async {
    final notesController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Resolve Request"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Add resolution notes:"),
            const SizedBox(height: 8),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "What actions were taken?",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _resolveRequest(requestId, notesController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text("Resolve"),
          ),
        ],
      ),
    );
  }

  Future<void> _resolveRequest(String requestId, String notes) async {
    try {
      // Get request data to find resident
      final requestDoc = await FirebaseFirestore.instance
          .collection("security_requests")
          .doc(requestId)
          .get();

      final residentId = requestDoc.data()?["residentId"];
      final requestType =
          requestDoc.data()?["requestType"] ?? "security request";

      await FirebaseFirestore.instance
          .collection("security_requests")
          .doc(requestId)
          .update({
            "status": "resolved",
            "resolvedAt": FieldValue.serverTimestamp(),
            "resolvedBy": FirebaseAuth.instance.currentUser?.uid,
            "resolutionNotes": notes,
          });

      // Send notification to resident
      if (residentId != null) {
        await NotificationService.sendNotification(
          userId: residentId,
          userRole: 'user',
          title: "Request Resolved",
          body: "Your ${requestType.replaceAll('_', ' ')} request has been resolved. ${notes.isNotEmpty ? 'Notes: $notes' : ''}",
          type: "security_request_update",
          additionalData: {"requestId": requestId},
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Request marked as resolved"),
            backgroundColor: Colors.green,
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
