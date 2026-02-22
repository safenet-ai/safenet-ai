import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../shared/widgets/image_viewer.dart';
import '../../../services/notification_service.dart';
import '../../../core/channels/panic_channel.dart';

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
    final flatNo = data["flatNo"] ?? data["flatNumber"] ?? "Unknown";
    final buildingNo = data["buildingNumber"]?.toString() ?? "Unknown";
    final block = data["block"]?.toString() ?? "Unknown";
    final description = data["description"] ?? "No description";
    final status = data["status"] ?? "pending";
    final fileUrls = data["fileUrls"] as List<dynamic>? ?? [];
    final timestamp = (data["timestamp"] as Timestamp?)?.toDate();
    final phone = data["phone"] ?? "N/A";

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
                        "Resident: ${residentName ?? 'Loading...'}",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: statusColor.withOpacity(0.9),
                        ),
                      ),
                      if (phone != "N/A" && phone != "Unknown")
                        Text(
                          "Tap to Call: $phone",
                          style: TextStyle(
                            fontSize: 13,
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
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _infoRow(
                        Icons.business,
                        "Building & Block",
                        "Bldg $buildingNo (Blk $block)",
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: _infoRow(Icons.home, "Flat", flatNo),
                    ),
                  ],
                ),
                if (phone != "N/A" && phone != "Unknown") ...[
                  const SizedBox(height: 12),
                  _infoRow(Icons.phone, "Phone", phone),
                ],
                if (timestamp != null) ...[
                  const SizedBox(height: 12),
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
          if (requestType.toLowerCase() != "panic_alert") ...[
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
          ],

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

          // ========================================
          // ACTION BUTTONS
          // ========================================
          if (status.toLowerCase() == "pending") ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _assignToSelf(widget.requestId, data),
                icon: const Icon(Icons.person_add, size: 20),
                label: const Text(
                  "Accept & Assign to Me",
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ] else if (status.toLowerCase() == "assigned") ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _markInProgress(widget.requestId, data),
                icon: const Icon(Icons.play_arrow, size: 20),
                label: const Text(
                  "Start Working",
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ] else if (status.toLowerCase() == "in_progress") ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showResolveDialog(widget.requestId, data),
                icon: const Icon(Icons.check_circle, size: 20),
                label: const Text(
                  "Mark as Resolved",
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ========================================
  // STATUS UPDATE METHODS
  // ========================================

  Future<void> _assignToSelf(
    String requestId,
    Map<String, dynamic> data,
  ) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final requestType = data["requestType"] ?? "security request";

      if (requestType == "panic_alert") {
        await PanicChannel.stopSiren();
      }

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

      // Notify resident
      final residentId = data["residentId"];
      if (residentId != null) {
        await NotificationService.sendNotification(
          userId: residentId,
          userRole: 'user',
          title: "Request Accepted",
          body:
              "$securityName has accepted your ${requestType.replaceAll('_', ' ')} request.",
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

  Future<void> _markInProgress(
    String requestId,
    Map<String, dynamic> data,
  ) async {
    try {
      final requestType = data["requestType"] ?? "security request";

      if (requestType == "panic_alert") {
        await PanicChannel.stopSiren();
      }

      await FirebaseFirestore.instance
          .collection("security_requests")
          .doc(requestId)
          .update({
            "status": "in_progress",
            "startedAt": FieldValue.serverTimestamp(),
          });

      final residentId = data["residentId"];
      if (residentId != null) {
        await NotificationService.sendNotification(
          userId: residentId,
          userRole: 'user',
          title: "Work Started",
          body:
              "Security has started working on your ${requestType.replaceAll('_', ' ')} request.",
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

  Future<void> _showResolveDialog(
    String requestId,
    Map<String, dynamic> data,
  ) async {
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
              await _resolveRequest(requestId, notesController.text, data);
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

  Future<void> _resolveRequest(
    String requestId,
    String notes,
    Map<String, dynamic> data,
  ) async {
    try {
      final requestType = data["requestType"] ?? "security request";

      if (requestType == "panic_alert") {
        await PanicChannel.stopSiren();
      }

      await FirebaseFirestore.instance
          .collection("security_requests")
          .doc(requestId)
          .update({
            "status": "resolved",
            "resolvedAt": FieldValue.serverTimestamp(),
            "resolvedBy": FirebaseAuth.instance.currentUser?.uid,
            "resolutionNotes": notes,
          });

      final residentId = data["residentId"];
      if (residentId != null) {
        await NotificationService.sendNotification(
          userId: residentId,
          userRole: 'user',
          title: "Request Resolved",
          body:
              "Your ${requestType.replaceAll('_', ' ')} request has been resolved. ${notes.isNotEmpty ? 'Notes: $notes' : ''}",
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
