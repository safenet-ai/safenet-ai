import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import '../../shared/widgets/profile_sidebar.dart';
import '../../shared/widgets/notification_dropdown.dart';
import 'security_incident_history.dart';

class IncidentReportPage extends StatefulWidget {
  const IncidentReportPage({super.key});

  @override
  State<IncidentReportPage> createState() => _IncidentReportPageState();
}

class _IncidentReportPageState extends State<IncidentReportPage> {
  bool _isProfileOpen = false;
  bool _isSubmitting = false;

  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedType = "Suspicious Activity";
  String _selectedSeverity = "Medium";
  List<File> _selectedFiles = [];

  final List<String> _incidentTypes = [
    "Suspicious Activity",
    "Theft",
    "Vandalism",
    "Fire Hazard",
    "Medical Emergency",
    "Violence",
    "Property Damage",
    "Other",
  ];

  final List<String> _severityLevels = ["Low", "Medium", "High", "Critical"];

  @override
  void dispose() {
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

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
                        "Report Incident",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const SecurityIncidentHistoryPage(),
                                ),
                              );
                            },
                            child: _circleButton(Icons.history),
                          ),
                          const SizedBox(width: 10),
                          NotificationDropdown(role: "security"),
                          const SizedBox(width: 10),
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

                // Form
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Incident Type
                          _sectionTitle("Incident Type"),
                          _buildDropdown(
                            value: _selectedType,
                            items: _incidentTypes,
                            onChanged: (value) {
                              setState(() => _selectedType = value!);
                            },
                          ),

                          const SizedBox(height: 20),

                          // Severity Level
                          _sectionTitle("Severity Level"),
                          _buildSeveritySelector(),

                          const SizedBox(height: 20),

                          // Location
                          _sectionTitle("Location"),
                          _buildTextField(
                            controller: _locationController,
                            hint: "Enter location (e.g., Block C, Parking Lot)",
                            icon: Icons.location_on,
                          ),

                          const SizedBox(height: 20),

                          // Description
                          _sectionTitle("Description"),
                          _buildTextField(
                            controller: _descriptionController,
                            hint: "Describe the incident in detail...",
                            icon: Icons.description,
                            maxLines: 5,
                          ),

                          const SizedBox(height: 20),

                          // File upload
                          _sectionTitle("Attach Photos/Videos (Optional)"),
                          _buildFileUploadSection(),

                          const SizedBox(height: 30),

                          // Submit button
                          _isSubmitting
                              ? const Center(child: CircularProgressIndicator())
                              : ElevatedButton(
                                  onPressed: _submitReport,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(
                                      double.infinity,
                                      50,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text(
                                    "Submit Report",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ),
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

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        items: items.map((item) {
          return DropdownMenuItem(value: item, child: Text(item));
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSeveritySelector() {
    return Row(
      children: _severityLevels.map((level) {
        final isSelected = _selectedSeverity == level;
        Color color;
        switch (level) {
          case "Critical":
            color = Colors.red[700]!;
            break;
          case "High":
            color = Colors.red;
            break;
          case "Medium":
            color = Colors.orange;
            break;
          default:
            color = Colors.blue;
        }

        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedSeverity = level),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withOpacity(0.2)
                    : Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? color : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  level,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? color : Colors.black87,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.grey[600]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return "This field is required";
          }
          return null;
        },
      ),
    );
  }

  Widget _buildFileUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _pickFiles,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.blue[300]!,
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_upload, color: Colors.blue[600], size: 28),
                const SizedBox(width: 12),
                Text(
                  "Tap to upload files",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[600],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_selectedFiles.isNotEmpty) ...[
          const SizedBox(height: 12),
          ..._selectedFiles.asMap().entries.map((entry) {
            final index = entry.key;
            final file = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.attach_file, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      file.path.split('/').last,
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () {
                      setState(() => _selectedFiles.removeAt(index));
                    },
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'mp4', 'mov'],
      );

      if (result != null) {
        setState(() {
          _selectedFiles.addAll(result.files.map((file) => File(file.path!)));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error picking files: $e")));
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw "Not authenticated";

      // Upload files to Firebase Storage
      List<String> fileUrls = [];
      for (var file in _selectedFiles) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
        final ref = FirebaseStorage.instance
            .ref()
            .child('incident_reports')
            .child(fileName);
        await ref.putFile(file);
        final url = await ref.getDownloadURL();
        fileUrls.add(url);
      }

      // Create incident report document
      await FirebaseFirestore.instance.collection("incidents").add({
        "type": _selectedType,
        "severity": _selectedSeverity.toLowerCase(),
        "location": _locationController.text,
        "description": _descriptionController.text,
        "fileUrls": fileUrls,
        "reportedBy": currentUser.uid,
        "timestamp": FieldValue.serverTimestamp(),
        "status": "pending",
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Incident reported successfully"),
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
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
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
