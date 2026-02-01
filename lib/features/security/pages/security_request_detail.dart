import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/widgets/image_viewer.dart';

class SecurityRequestDetailPage extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> requestData;

  const SecurityRequestDetailPage({
    super.key,
    required this.requestId,
    required this.requestData,
  });

  @override
  State<SecurityRequestDetailPage> createState() =>
      _SecurityRequestDetailPageState();
}

class _SecurityRequestDetailPageState extends State<SecurityRequestDetailPage> {
  String? residentName;
  bool isLoadingResident = true;

  @override
  void initState() {
    super.initState();
    _loadResidentDetails();
  }

  Future<void> _loadResidentDetails() async {
    try {
      final residentId = widget.requestData["residentId"];
      if (residentId != null) {
        final residentDoc = await FirebaseFirestore.instance
            .collection("users")
            .doc(residentId)
            .get();

        if (residentDoc.exists) {
          setState(() {
            residentName = residentDoc.data()?["username"] ?? "Resident";
            isLoadingResident = false;
          });
        } else {
          setState(() {
            residentName = "Resident";
            isLoadingResident = false;
          });
        }
      } else {
        setState(() {
          residentName = null;
          isLoadingResident = false;
        });
      }
    } catch (e) {
      setState(() {
        residentName = "Resident";
        isLoadingResident = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/bg1_img.png', fit: BoxFit.cover),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),
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
                        "Request Details",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      _circleButton(Icons.security),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection("security_requests")
                        .doc(widget.requestId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || !snapshot.data!.exists) {
                        return Center(
                          child: Text(
                            "Request not found",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        );
                      }
                      final data =
                          snapshot.data!.data() as Map<String, dynamic>;

                      // Update resident name when data changes
                      final residentId = data["residentId"];
                      if (residentId != null && residentName == null) {
                        _loadResidentDetails();
                      }

                      return _buildContent(data);
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

  Widget _buildContent(Map<String, dynamic> data) {
    final requestType = data["requestType"] ?? "Unknown";
    final priority = data["priority"] ?? "normal";
    final location = data["location"] ?? "Unknown";
    final flatNo = data["flatNo"] ?? "N/A";
    final description = data["description"] ?? "No description";
    final status = data["status"] ?? "pending";
    final fileUrls = data["fileUrls"] as List<dynamic>? ?? [];
    final timestamp = (data["timestamp"] as Timestamp?)?.toDate();

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
    IconData statusIcon;

    switch (status.toLowerCase()) {
      case "assigned":
        statusColor = Colors.blue;
        statusDisplay = "ASSIGNED";
        statusIcon = Icons.person_add;
        break;
      case "in_progress":
        statusColor = Colors.orange;
        statusDisplay = "IN PROGRESS";
        statusIcon = Icons.work;
        break;
      case "resolved":
        statusColor = Colors.green;
        statusDisplay = "RESOLVED";
        statusIcon = Icons.check_circle;
        break;
      default:
        statusColor = Colors.red;
        statusDisplay = "PENDING";
        statusIcon = Icons.pending;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor, width: 2),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusDisplay,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                      Text(
                        "From: ${residentName ?? 'Loading...'}",
                        style: TextStyle(
                          fontSize: 14,
                          color: statusColor.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Request Information
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
            ),
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
                      child: Icon(requestIcon, color: priorityColor, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            requestType.replaceAll('_', ' ').toUpperCase(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            "Priority: ${priority.toUpperCase()}",
                            style: TextStyle(
                              fontSize: 14,
                              color: priorityColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _infoRow(Icons.location_on, "Location", location),
                const SizedBox(height: 8),
                _infoRow(Icons.home, "Flat Number", flatNo),
                if (timestamp != null) ...[
                  const SizedBox(height: 8),
                  _infoRow(
                    Icons.access_time,
                    "Submitted",
                    _formatDateTime(timestamp),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Description
          _sectionTitle("Description"),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              description,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[800],
                height: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Attachments
          if (fileUrls.isNotEmpty) ...[
            _sectionTitle("Attachments (${fileUrls.length})"),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: fileUrls.asMap().entries.map((entry) {
                  return AttachmentThumbnail(
                    url: entry.value,
                    index: entry.key,
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ],
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

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          "$label: ",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 14, color: Colors.grey[800]),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return "${difference.inMinutes} minutes ago";
    } else if (difference.inHours < 24) {
      return "${difference.inHours} hours ago";
    } else if (difference.inDays < 7) {
      return "${difference.inDays} days ago";
    } else {
      return "${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}";
    }
  }
}
