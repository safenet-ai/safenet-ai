import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/widgets/image_viewer.dart';

class SecurityIncidentDetailPage extends StatefulWidget {
  final String incidentId;
  final Map<String, dynamic> incidentData;

  const SecurityIncidentDetailPage({
    super.key,
    required this.incidentId,
    required this.incidentData,
  });

  @override
  State<SecurityIncidentDetailPage> createState() =>
      _SecurityIncidentDetailPageState();
}

class _SecurityIncidentDetailPageState
    extends State<SecurityIncidentDetailPage> {
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
                        "Incident Details",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      _circleButton(Icons.report_problem),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection("incidents")
                        .doc(widget.incidentId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || !snapshot.data!.exists) {
                        return Center(
                          child: Text(
                            "Incident not found",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        );
                      }
                      final data =
                          snapshot.data!.data() as Map<String, dynamic>;
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
    final type = data["type"] ?? "Unknown";
    final severity = data["severity"] ?? "medium";
    final location = data["location"] ?? "Unknown";
    final description = data["description"] ?? "No description";
    final status = data["status"] ?? "pending";
    final fileUrls = data["fileUrls"] as List<dynamic>? ?? [];
    final timestamp = (data["timestamp"] as Timestamp?)?.toDate();
    final acknowledgedAt = (data["acknowledgedAt"] as Timestamp?)?.toDate();
    final resolvedAt = (data["resolvedAt"] as Timestamp?)?.toDate();
    final resolutionNotes = data["resolutionNotes"];

    Color severityColor;
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

    Color statusColor;
    String statusDisplay;
    IconData statusIcon;

    switch (status.toLowerCase()) {
      case "acknowledged":
        statusColor = Colors.blue;
        statusDisplay = "ACKNOWLEDGED";
        statusIcon = Icons.check_circle_outline;
        break;
      case "resolved":
        statusColor = Colors.green;
        statusDisplay = "RESOLVED";
        statusIcon = Icons.check_circle;
        break;
      default:
        statusColor = Colors.orange;
        statusDisplay = "PENDING";
        statusIcon = Icons.pending;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                        _getStatusMessage(status),
                        style: TextStyle(fontSize: 14, color: statusColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: severityColor.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      type.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
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
                const SizedBox(height: 8),
                _infoRow(Icons.location_on, location),
                if (timestamp != null)
                  _infoRow(
                    Icons.access_time,
                    "Reported: ${_formatDateTime(timestamp)}",
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
            const SizedBox(height: 16),
          ],
          _sectionTitle("Status Updates"),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _timelineItem(
                  Icons.report_problem,
                  "Incident Reported",
                  timestamp != null ? _formatDateTime(timestamp) : "N/A",
                  Colors.orange,
                  isFirst: true,
                ),
                if (acknowledgedAt != null)
                  _timelineItem(
                    Icons.check_circle_outline,
                    "Acknowledged by Authority",
                    _formatDateTime(acknowledgedAt),
                    Colors.blue,
                  ),
                if (resolvedAt != null)
                  _timelineItem(
                    Icons.check_circle,
                    "Incident Resolved",
                    _formatDateTime(resolvedAt),
                    Colors.green,
                    isLast: true,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (resolutionNotes != null && resolutionNotes.isNotEmpty) ...[
            _sectionTitle("Resolution Notes from Authority"),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.green.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    color: Colors.green[700],
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      resolutionNotes,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[800],
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getStatusMessage(String status) {
    switch (status.toLowerCase()) {
      case "acknowledged":
        return "Authority has acknowledged your report";
      case "resolved":
        return "This incident has been resolved";
      default:
        return "Waiting for authority response";
    }
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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

  Widget _timelineItem(
    IconData icon,
    String title,
    String time,
    Color color, {
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            if (!isFirst)
              Container(width: 2, height: 20, color: Colors.grey[300]),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            if (!isLast)
              Container(width: 2, height: 20, color: Colors.grey[300]),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              top: isFirst ? 0 : 8,
              bottom: isLast ? 0 : 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return "${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}";
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
