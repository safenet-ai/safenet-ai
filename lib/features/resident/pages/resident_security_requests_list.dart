import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../shared/widgets/profile_sidebar.dart';
import '../../shared/widgets/notification_dropdown.dart';
import 'resident_security_request_form.dart';
import 'resident_security_request_detail.dart';

class ResidentSecurityRequestsListPage extends StatefulWidget {
  const ResidentSecurityRequestsListPage({super.key});

  @override
  State<ResidentSecurityRequestsListPage> createState() =>
      _ResidentSecurityRequestsListPageState();
}

class _ResidentSecurityRequestsListPageState
    extends State<ResidentSecurityRequestsListPage> {
  bool _isProfileOpen = false;
  String selectedFilter = "All";

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
                          const NotificationDropdown(role: "resident"),
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

                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.red[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "Error loading requests",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                snapshot.error.toString(),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
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
                              const SizedBox(height: 8),
                              Text(
                                "Tap + to create a new request",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
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

          // Floating action button
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const ResidentSecurityRequestFormPage(),
                  ),
                );
              },
              backgroundColor: Colors.red,
              child: const Icon(Icons.add, color: Colors.white),
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
                userCollection: "users",
                onClose: () => setState(() => _isProfileOpen = false),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getRequestStream() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Stream.empty();
    }

    Query query = FirebaseFirestore.instance
        .collection("security_requests")
        .where("residentId", isEqualTo: currentUser.uid);

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
    final flatNo = data["flatNo"] ?? "N/A";
    final location = data["location"] ?? "N/A";
    final priority = data["priority"] ?? "normal";
    final timestamp = data["timestamp"] as Timestamp?;

    Color priorityColor;
    IconData requestIcon;

    switch (priority.toLowerCase()) {
      case "urgent":
      case "high":
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
        requestIcon = Icons.warning_amber_rounded;
        break;
      case "emergency":
        requestIcon = Icons.emergency;
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

    String timeAgo = "";
    if (timestamp != null) {
      final duration = DateTime.now().difference(timestamp.toDate());
      if (duration.inMinutes < 60) {
        timeAgo = "${duration.inMinutes}m ago";
      } else if (duration.inHours < 24) {
        timeAgo = "${duration.inHours}h ago";
      } else {
        timeAgo = "${duration.inDays}d ago";
      }
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResidentSecurityRequestDetailPage(
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
                          "Flat $flatNo • $timeAgo",
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      location,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
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
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleButton(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        width: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.3),
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }
}
