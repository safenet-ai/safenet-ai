import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../shared/widgets/profile_sidebar.dart';
import '../../shared/widgets/notification_dropdown.dart';

class ResidentSecurityRequestFormPage extends StatefulWidget {
  const ResidentSecurityRequestFormPage({super.key});

  @override
  State<ResidentSecurityRequestFormPage> createState() =>
      _ResidentSecurityRequestFormPageState();
}

class _ResidentSecurityRequestFormPageState
    extends State<ResidentSecurityRequestFormPage> {
  bool _isProfileOpen = false;
  bool _isSubmitting = false;

  final TextEditingController locationController = TextEditingController();
  final TextEditingController flatNoController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  String selectedRequestType = "suspicious_activity";
  String selectedPriority = "normal";

  List<PlatformFile> selectedFiles = [];

  final Map<String, String> requestTypeLabels = {
    "suspicious_activity": "Suspicious Activity",
    "emergency": "Emergency",
    "parking_issue": "Parking Issue",
    "noise_complaint": "Noise Complaint",
  };

  final Map<String, IconData> requestTypeIcons = {
    "suspicious_activity": Icons.warning_amber_rounded,
    "emergency": Icons.emergency,
    "parking_issue": Icons.local_parking,
    "noise_complaint": Icons.volume_up,
  };

  final Map<String, Color> priorityColors = {
    "normal": Colors.blue,
    "medium": Colors.orange,
    "urgent": Colors.red,
    "high": Colors.purple,
  };

  // Compress file before upload
  Future<Uint8List?> _compressFile(PlatformFile file) async {
    final isImage = [
      "png",
      "jpg",
      "jpeg",
    ].contains(file.extension?.toLowerCase());
    if (!isImage || file.bytes == null) return file.bytes;

    return await FlutterImageCompress.compressWithList(
      file.bytes!,
      minHeight: 1024,
      minWidth: 1024,
      quality: 70,
    );
  }

  // Pick files (max 4)
  Future<void> pickFile() async {
    if (selectedFiles.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You can only attach up to 4 photos.")),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.image,
    );

    if (result == null) return;

    int availableSlots = 4 - selectedFiles.length;
    final limitedFiles = result.files.take(availableSlots).toList();

    setState(() {
      selectedFiles.addAll(limitedFiles);
    });
  }

  // Remove a file
  void removeFile(int index) {
    setState(() {
      selectedFiles.removeAt(index);
    });
  }

  // Upload files to Firebase Storage
  Future<List<String>> uploadFiles() async {
    List<String> downloadUrls = [];

    for (var file in selectedFiles) {
      Uint8List? compressedData = await _compressFile(file);
      if (compressedData == null) continue;

      final ref = FirebaseStorage.instance
          .ref()
          .child("security_requests")
          .child("${DateTime.now().millisecondsSinceEpoch}_${file.name}");

      UploadTask uploadTask = ref.putData(compressedData);
      TaskSnapshot snapshot = await uploadTask;

      String url = await snapshot.ref.getDownloadURL();
      downloadUrls.add(url);
    }
    return downloadUrls;
  }

  // Submit security request
  Future<void> submitRequest() async {
    if (locationController.text.trim().isEmpty ||
        flatNoController.text.trim().isEmpty ||
        descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("All fields are required")));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("User not logged in. Please login again."),
          ),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      // Get resident details
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      String residentName = "Resident";
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null && data['username'] != null) {
          residentName = data['username'];
        }
      }

      // Upload files
      List<String> fileUrls = [];
      if (selectedFiles.isNotEmpty) {
        fileUrls = await uploadFiles();
      }

      // Submit request to Firestore
      await FirebaseFirestore.instance.collection("security_requests").add({
        "requestType": selectedRequestType,
        "description": descriptionController.text.trim(),
        "location": locationController.text.trim(),
        "flatNo": flatNoController.text.trim(),
        "residentName": residentName,
        "residentId": user.uid,
        "priority": selectedPriority,
        "status": "pending",
        "fileUrls": fileUrls,
        "timestamp": FieldValue.serverTimestamp(),
        "assignedTo": null,
        "assignedAt": null,
        "startedAt": null,
        "resolvedAt": null,
        "resolutionNotes": null,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Security request submitted successfully!"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error submitting request: $e")));
    } finally {
      setState(() => _isSubmitting = false);
    }
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
                        "Security Request",
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

                // Form
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Request Type Dropdown
                        _sectionTitle("Request Type *"),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedRequestType,
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down),
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                              items: requestTypeLabels.entries.map((entry) {
                                return DropdownMenuItem<String>(
                                  value: entry.key,
                                  child: Row(
                                    children: [
                                      Icon(
                                        requestTypeIcons[entry.key],
                                        size: 20,
                                        color: Colors.blue[700],
                                      ),
                                      const SizedBox(width: 12),
                                      Text(entry.value),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => selectedRequestType = value);
                                }
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Priority Selector
                        _sectionTitle("Priority Level *"),
                        const SizedBox(height: 8),
                        Row(
                          children: ["normal", "medium", "urgent", "high"].map((
                            priority,
                          ) {
                            final isSelected = selectedPriority == priority;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => selectedPriority = priority),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? priorityColors[priority]!.withOpacity(
                                            0.2,
                                          )
                                        : Colors.white.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? priorityColors[priority]!
                                          : Colors.grey[300]!,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Text(
                                    priority.toUpperCase(),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: isSelected
                                          ? priorityColors[priority]
                                          : Colors.black54,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 20),

                        // Location
                        _sectionTitle("Location *"),
                        const SizedBox(height: 8),
                        _textField(
                          controller: locationController,
                          hint: "E.g., Building A, Parking Area, Garden",
                          icon: Icons.location_on,
                        ),

                        const SizedBox(height: 20),

                        // Flat Number
                        _sectionTitle("Flat/Unit Number *"),
                        const SizedBox(height: 8),
                        _textField(
                          controller: flatNoController,
                          hint: "E.g., A-101, B-205",
                          icon: Icons.home,
                        ),

                        const SizedBox(height: 20),

                        // Description
                        _sectionTitle("Description *"),
                        const SizedBox(height: 8),
                        _textField(
                          controller: descriptionController,
                          hint: "Describe the issue in detail...",
                          icon: Icons.description,
                          maxLines: 5,
                        ),

                        const SizedBox(height: 20),

                        // Photo Attachments
                        _sectionTitle(
                          "Photo Attachments (Optional, max 4 photos)",
                        ),
                        const SizedBox(height: 8),

                        // Selected files
                        if (selectedFiles.isNotEmpty) ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: selectedFiles.asMap().entries.map((
                              entry,
                            ) {
                              final index = entry.key;
                              final file = entry.value;
                              return Stack(
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(12),
                                      image: file.bytes != null
                                          ? DecorationImage(
                                              image: MemoryImage(file.bytes!),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: file.bytes == null
                                        ? Icon(
                                            Icons.image,
                                            size: 40,
                                            color: Colors.grey[400],
                                          )
                                        : null,
                                  ),
                                  Positioned(
                                    top: -4,
                                    right: -4,
                                    child: IconButton(
                                      onPressed: () => removeFile(index),
                                      icon: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Add photo button
                        if (selectedFiles.length < 4)
                          GestureDetector(
                            onTap: pickFile,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.blue[300]!,
                                  width: 1,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate,
                                    color: Colors.blue[700],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Add Photos",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        const SizedBox(height: 32),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : submitRequest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 3,
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    "Submit Request",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
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
                userCollection: "users",
                onClose: () => setState(() => _isProfileOpen = false),
              ),
            ),
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
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400]),
          border: InputBorder.none,
          prefixIcon: Icon(icon, color: Colors.grey[600]),
        ),
      ),
    );
  }
}
