import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../shared/widgets/profile_sidebar.dart';
import '../../shared/widgets/notification_dropdown.dart';

class AIAlertsPage extends StatefulWidget {
  const AIAlertsPage({super.key});

  @override
  State<AIAlertsPage> createState() => _AIAlertsPageState();
}

class _AIAlertsPageState extends State<AIAlertsPage> {
  bool _isProfileOpen = false;
  String selectedFilter = "Active";

  final List<String> filters = ["All", "Active", "Acknowledged", "Resolved"];

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
                        "AI Alerts",
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
                                  ? Colors.purple.withOpacity(0.2)
                                  : Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.purple
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
                                    ? Colors.purple
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

                // Alerts list
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _getAlertsStream(),
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
                                Icons.notifications_off,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "No alerts found",
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

                      final alerts = snapshot.data!.docs;

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: alerts.length,
                        itemBuilder: (context, index) {
                          final data =
                              alerts[index].data() as Map<String, dynamic>;
                          return _alertCard(alerts[index].id, data);
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

  Stream<QuerySnapshot> _getAlertsStream() {
    Query query = FirebaseFirestore.instance.collection("ai_alerts");

    if (selectedFilter != "All") {
      query = query.where("status", isEqualTo: selectedFilter.toLowerCase());
    }

    return query.orderBy("timestamp", descending: true).snapshots();
  }

  Widget _alertCard(String alertId, Map<String, dynamic> data) {
    final type = data["type"] ?? "unknown";
    final severity = data["severity"] ?? "medium";
    final location = data["location"] ?? "Unknown";
    final status = data["status"] ?? "active";
    final cameraId = data["cameraId"] ?? "N/A";
    final description = data["description"] ?? "No description available";

    Color severityColor;
    IconData alertIcon;

    switch (severity.toLowerCase()) {
      case "critical":
        severityColor = Colors.red[700]!;
        break;
      case "high":
        severityColor = Colors.red;
        break;
      case "medium":
        severityColor = Colors.orange;
        break;
      default:
        severityColor = Colors.blue;
    }

    switch (type.toLowerCase()) {
      case "motion":
        alertIcon = Icons.directions_walk;
        break;
      case "intrusion":
        alertIcon = Icons.warning;
        break;
      case "fire":
        alertIcon = Icons.local_fire_department;
        break;
      case "unusual_activity":
        alertIcon = Icons.visibility;
        break;
      default:
        alertIcon = Icons.notification_important;
    }

    Color statusColor;
    String statusDisplay;

    switch (status.toLowerCase()) {
      case "acknowledged":
        statusColor = Colors.blue;
        statusDisplay = "ACKNOWLEDGED";
        break;
      case "resolved":
        statusColor = Colors.green;
        statusDisplay = "RESOLVED";
        break;
      default:
        statusColor = Colors.red;
        statusDisplay = "ACTIVE";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: severityColor.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: severityColor.withOpacity(0.2),
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
                    color: severityColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(alertIcon, color: severityColor, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        location,
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
                    color: severityColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    severity.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: severityColor,
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
            _infoRow(Icons.videocam, "Camera ID: $cameraId"),
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
            if (status == "active") ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _acknowledgeAlert(alertId),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text("Acknowledge"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
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
                      onPressed: () => _showResolveDialog(alertId),
                      icon: const Icon(Icons.done_all, size: 18),
                      label: const Text("Resolve"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (status == "acknowledged") ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _showResolveDialog(alertId),
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

  Future<void> _acknowledgeAlert(String alertId) async {
    try {
      await FirebaseFirestore.instance
          .collection("ai_alerts")
          .doc(alertId)
          .update({
            "status": "acknowledged",
            "acknowledgedAt": FieldValue.serverTimestamp(),
            "acknowledgedBy": FirebaseAuth.instance.currentUser?.uid,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Alert acknowledged"),
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

  Future<void> _showResolveDialog(String alertId) async {
    final notesController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Resolve Alert"),
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
                hintText: "Describe the actions taken...",
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
              await _resolveAlert(alertId, notesController.text);
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

  Future<void> _resolveAlert(String alertId, String notes) async {
    try {
      await FirebaseFirestore.instance
          .collection("ai_alerts")
          .doc(alertId)
          .update({
            "status": "resolved",
            "resolvedAt": FieldValue.serverTimestamp(),
            "resolvedBy": FirebaseAuth.instance.currentUser?.uid,
            "resolutionNotes": notes,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Alert resolved successfully"),
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
