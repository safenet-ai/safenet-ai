import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class AuthoritySecurityRequestDetailPage extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> requestData;

  const AuthoritySecurityRequestDetailPage({
    super.key,
    required this.requestId,
    required this.requestData,
  });

  @override
  State<AuthoritySecurityRequestDetailPage> createState() =>
      _AuthoritySecurityRequestDetailPageState();
}

class _AuthoritySecurityRequestDetailPageState
    extends State<AuthoritySecurityRequestDetailPage> {
  bool _isUpdating = false;
  late String currentStatus;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    currentStatus = widget.requestData["status"] ?? "pending";
    if (widget.requestData["resolutionNotes"] != null) {
      _notesController.text = widget.requestData["resolutionNotes"];
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdating = true);

    try {
      final updateData = <String, dynamic>{
        "status": newStatus,
        "resolutionNotes": _notesController.text.trim(),
      };

      if (newStatus == "in_progress" &&
          widget.requestData["startedAt"] == null) {
        updateData["startedAt"] = FieldValue.serverTimestamp();
      }

      if (newStatus == "resolved") {
        updateData["resolvedAt"] = FieldValue.serverTimestamp();
      }

      await FirebaseFirestore.instance
          .collection("security_requests")
          .doc(widget.requestId)
          .update(updateData);

      setState(() => currentStatus = newStatus);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Request updated to ${newStatus.replaceAll('_', ' ').toUpperCase()}"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error updating request: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      if (mounted) {
        ScaffoldMessenger.of(
            context).showSnackBar(const SnackBar(content: Text("Could not open file")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.requestData;
    final requestType = data["requestType"] ?? "Unknown";
    final description = data["description"] ?? "No description";
    final location = data["location"] ?? "Unknown";
    final flatNo = data["flatNo"] ?? "Unknown";
    final residentName = data["residentName"] ?? "Resident";
    final priority = data["priority"] ?? "normal";
    final fileUrls = List<String>.from(data["fileUrls"] ?? []);
    final timestamp = data["timestamp"] as Timestamp?;

    Color priorityColor;
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

                // Header
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
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 40),
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
                        // Status Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _getStatusColor(currentStatus),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                "Current Status",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currentStatus
                                    .replaceAll('_', ' ')
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: _getStatusColor(currentStatus),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Details Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Type & Priority
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "TYPE",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          requestType
                                              .replaceAll('_', ' ')
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
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
                                      color: priorityColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: priorityColor, width: 1),
                                    ),
                                    child: Text(
                                      priority.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: priorityColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const Divider(height: 30),

                              // Resident Info
                              _detailRow(
                                Icons.person,
                                "Resident",
                                "$residentName (Flat $flatNo)",
                              ),

                              const SizedBox(height: 16),

                              // Location
                              _detailRow(
                                Icons.location_on,
                                "Location",
                                location,
                              ),

                              const SizedBox(height: 16),

                              // Time
                              if (timestamp != null)
                                _detailRow(
                                  Icons.access_time,
                                  "Submitted",
                                  timestamp.toDate().toString().split('.')[0],
                                ),

                              const Divider(height: 30),

                              // Description
                              Text(
                                "DESCRIPTION",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[500],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                description,
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.5,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Photos
                        if (fileUrls.isNotEmpty) ...[
                          const Text(
                            "Attachments",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 120,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: fileUrls.length,
                              itemBuilder: (context, index) {
                                return GestureDetector(
                                  onTap: () => _launchUrl(fileUrls[index]),
                                  child: Container(
                                    width: 120,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      image: DecorationImage(
                                        image: NetworkImage(fileUrls[index]),
                                        fit: BoxFit.cover,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 5,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Actions Section
                        const Text(
                          "Update Request",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Resolution Notes",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _notesController,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  hintText: "Add notes about actions taken...",
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  if (currentStatus != "in_progress" &&
                                      currentStatus != "resolved")
                                    Expanded(
                                      child: _actionButton(
                                        "Mark In Progress",
                                        Colors.orange,
                                        () => _updateStatus("in_progress"),
                                      ),
                                    ),
                                  if (currentStatus != "in_progress" &&
                                      currentStatus != "resolved")
                                    const SizedBox(width: 12),
                                  if (currentStatus != "resolved")
                                    Expanded(
                                      child: _actionButton(
                                        "Resolve Request",
                                        Colors.green,
                                        () => _updateStatus("resolved"),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
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

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: _isUpdating ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
      child: _isUpdating
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          : Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "pending":
        return Colors.red;
      case "assigned":
        return Colors.blue;
      case "in_progress":
        return Colors.orange;
      case "resolved":
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
