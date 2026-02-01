import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'authority_incident_detail.dart';

class AuthoritySecurityAlertsPage extends StatefulWidget {
  const AuthoritySecurityAlertsPage({super.key});

  @override
  State<AuthoritySecurityAlertsPage> createState() =>
      _AuthoritySecurityAlertsPageState();
}

class _AuthoritySecurityAlertsPageState
    extends State<AuthoritySecurityAlertsPage> {
  String selectedFilter = "All";

  final List<String> filters = ["All", "Pending", "Acknowledged", "Resolved"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                        "Security Alerts",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      _circleButton(Icons.shield),
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

                // Incidents list
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _getIncidentsStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      // Handle errors (including index building)
                      if (snapshot.hasError) {
                        final error = snapshot.error.toString();
                        if (error.contains('index') ||
                            error.contains('FAILED_PRECONDITION')) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const CircularProgressIndicator(),
                                  const SizedBox(height: 24),
                                  Icon(
                                    Icons.cloud_sync,
                                    size: 64,
                                    color: Colors.orange[400],
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    "Setting up database...",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Database indexes are being created.\nThis usually takes 5-10 minutes.\nPlease wait...",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      setState(() {}); // Trigger rebuild
                                    },
                                    icon: const Icon(Icons.refresh),
                                    label: const Text("Retry"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.red[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "Error loading incidents",
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

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.report_off,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "No incidents found",
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

                      final incidents = snapshot.data!.docs;

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: incidents.length,
                        itemBuilder: (context, index) {
                          final data =
                              incidents[index].data() as Map<String, dynamic>;
                          return _incidentCard(incidents[index].id, data);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getIncidentsStream() {
    Query query = FirebaseFirestore.instance.collection("incidents");

    if (selectedFilter != "All") {
      String filterStatus = selectedFilter.toLowerCase();
      query = query.where("status", isEqualTo: filterStatus);
    }

    return query.orderBy("timestamp", descending: true).snapshots();
  }

  Widget _incidentCard(String incidentId, Map<String, dynamic> data) {
    final type = data["type"] ?? "Unknown";
    final severity = data["severity"] ?? "medium";
    final location = data["location"] ?? "Unknown";
    final status = data["status"] ?? "pending";
    final description = data["description"] ?? "No description";
    final timestamp = (data["timestamp"] as Timestamp?)?.toDate();

    Color severityColor;
    IconData incidentIcon;

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
      case "theft":
        incidentIcon = Icons.shopping_bag_outlined;
        break;
      case "vandalism":
        incidentIcon = Icons.broken_image;
        break;
      case "fire hazard":
        incidentIcon = Icons.local_fire_department;
        break;
      case "medical emergency":
        incidentIcon = Icons.medical_services;
        break;
      case "violence":
        incidentIcon = Icons.warning;
        break;
      case "property damage":
        incidentIcon = Icons.home_repair_service;
        break;
      default:
        incidentIcon = Icons.report_problem;
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
        statusDisplay = "PENDING";
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AuthorityIncidentDetailPage(
              incidentId: incidentId,
              incidentData: data,
            ),
          ),
        );
      },
      child: Container(
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
                    child: Icon(incidentIcon, color: severityColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          location,
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
                      color: severityColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      severity.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                  if (timestamp != null)
                    Text(
                      _formatTimestamp(timestamp),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 60) {
      return "${diff.inMinutes}m ago";
    } else if (diff.inHours < 24) {
      return "${diff.inHours}h ago";
    } else {
      return "${diff.inDays}d ago";
    }
  }

  Widget _circleButton(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }
}
