import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../shared/widgets/image_viewer.dart';

class AuthorityIncidentDetailPage extends StatefulWidget {
  final String incidentId;
  final Map<String, dynamic> incidentData;

  const AuthorityIncidentDetailPage({
    super.key,
    required this.incidentId,
    required this.incidentData,
  });

  @override
  State<AuthorityIncidentDetailPage> createState() =>
      _AuthorityIncidentDetailPageState();
}

class _AuthorityIncidentDetailPageState
    extends State<AuthorityIncidentDetailPage> {
  String? securityName;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSecurityDetails();
  }

  Future<void> _loadSecurityDetails() async {
    try {
      final reportedBy = widget.incidentData["reportedBy"];
      if (reportedBy != null) {
        final securityDoc = await FirebaseFirestore.instance
            .collection("workers")
            .doc(reportedBy)
            .get();

        if (securityDoc.exists) {
          setState(() {
            securityName =
                securityDoc.data()?["username"] ?? "Security Personnel";
            isLoading = false;
          });
        } else {
          setState(() {
            securityName = "Security Personnel";
            isLoading = false;
          });
        }
      } else {
        setState(() {
          securityName = "Unknown";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        securityName = "Unknown";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.incidentData["type"] ?? "Unknown";
    final severity = widget.incidentData["severity"] ?? "medium";
    final location = widget.incidentData["location"] ?? "Unknown";
    final description = widget.incidentData["description"] ?? "No description";
    final status = widget.incidentData["status"] ?? "pending";
    final fileUrls = widget.incidentData["fileUrls"] as List<dynamic>? ?? [];
    final timestamp = (widget.incidentData["timestamp"] as Timestamp?)
        ?.toDate();

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

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Type and Severity
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                              _infoRow(
                                Icons.person,
                                isLoading
                                    ? "Loading..."
                                    : "Reported by: $securityName",
                              ),
                              if (timestamp != null)
                                _infoRow(
                                  Icons.access_time,
                                  _formatDateTime(timestamp),
                                ),
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
                          const SizedBox(height: 16),
                        ],

                        // Status Actions
                        if (status == "pending") ...[
                          _sectionTitle("Actions"),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _updateStatus("acknowledged"),
                                  icon: const Icon(Icons.check, size: 18),
                                  label: const Text("Acknowledge"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _showResolveDialog(),
                                  icon: const Icon(
                                    Icons.check_circle,
                                    size: 18,
                                  ),
                                  label: const Text("Resolve"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else if (status == "acknowledged") ...[
                          _sectionTitle("Actions"),
                          ElevatedButton.icon(
                            onPressed: () => _showResolveDialog(),
                            icon: const Icon(Icons.check_circle, size: 18),
                            label: const Text("Mark as Resolved"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 50),
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
              ],
            ),
          ),
        ],
      ),
    );
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

  String _formatDateTime(DateTime dateTime) {
    return "${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _updateStatus(String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection("incidents")
          .doc(widget.incidentId)
          .update({
            "status": newStatus,
            "acknowledgedBy": FirebaseAuth.instance.currentUser?.uid,
            "acknowledgedAt": FieldValue.serverTimestamp(),
          });

      // Send notification to security personnel
      final reportedBy = widget.incidentData["reportedBy"];
      if (reportedBy != null) {
        await FirebaseFirestore.instance.collection("notifications").add({
          "toUid": reportedBy,
          "toRole": "security",
          "title": "Incident Acknowledged",
          "message":
              "Your ${widget.incidentData["type"]} incident report at ${widget.incidentData["location"]} has been acknowledged by authority.",
          "timestamp": FieldValue.serverTimestamp(),
          "isRead": false,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Incident $newStatus"),
            backgroundColor: Colors.blue,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _showResolveDialog() async {
    final notesController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Resolve Incident"),
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
              await _resolveIncident(notesController.text);
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

  Future<void> _resolveIncident(String notes) async {
    try {
      await FirebaseFirestore.instance
          .collection("incidents")
          .doc(widget.incidentId)
          .update({
            "status": "resolved",
            "resolvedAt": FieldValue.serverTimestamp(),
            "resolvedBy": FirebaseAuth.instance.currentUser?.uid,
            "resolutionNotes": notes,
          });

      // Send notification to security personnel
      final reportedBy = widget.incidentData["reportedBy"];
      if (reportedBy != null) {
        await FirebaseFirestore.instance.collection("notifications").add({
          "toUid": reportedBy,
          "toRole": "security",
          "title": "Incident Resolved",
          "message":
              "Your ${widget.incidentData["type"]} incident report at ${widget.incidentData["location"]} has been resolved. ${notes.isNotEmpty ? 'Resolution: $notes' : ''}",
          "timestamp": FieldValue.serverTimestamp(),
          "isRead": false,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Incident resolved successfully"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
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
