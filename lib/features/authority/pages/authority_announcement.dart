import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../../../services/notification_service.dart';

class AuthorityAnnouncementPage extends StatefulWidget {
  const AuthorityAnnouncementPage({super.key});

  @override
  State<AuthorityAnnouncementPage> createState() =>
      _AuthorityAnnouncementPageState();
}

class _AuthorityAnnouncementPageState extends State<AuthorityAnnouncementPage> {
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  String selectedCategory = "General Notice";
  String selectedAudience = "All Residents";
  String selectedPriority = "normal";
  File? _selectedImage;
  String? _imageFileName;
  bool _isLoading = false;

  final List<Map<String, dynamic>> categories = [
    {"name": "General Notice", "icon": Icons.info_outline},
    {"name": "Maintenance / Repair", "icon": Icons.build_outlined},
    {"name": "Emergency / Alert", "icon": Icons.warning_amber_outlined},
    {"name": "Events & Meetings", "icon": Icons.event_outlined},
    {"name": "Payments & Dues", "icon": Icons.payment_outlined},
    {"name": "Security Updates", "icon": Icons.security_outlined},
    {"name": "Rules & Guidelines", "icon": Icons.gavel_outlined},
    {"name": "Facilities / Amenities", "icon": Icons.apartment_outlined},
  ];

  final List<String> audiences = [
    "All Residents",
    "All Workers",
    "All Security",
    "Everyone",
  ];

  final List<Map<String, dynamic>> priorities = [
    {"name": "Normal", "value": "normal", "icon": Icons.notifications_none},
    {"name": "Medium", "value": "medium", "icon": Icons.notifications},
    {"name": "Urgent", "value": "urgent", "icon": Icons.notifications_active},
  ];

  Future<void> _pickImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null) {
        setState(() {
          _selectedImage = File(result.files.single.path!);
          _imageFileName = result.files.single.name;
        });
      }
    } catch (e) {
      _showMsg("Error picking image: $e");
    }
  }

  Future<void> _publishAnnouncement() async {
    if (_titleCtrl.text.trim().isEmpty) {
      _showMsg("Please enter announcement title");
      return;
    }

    if (_descriptionCtrl.text.trim().isEmpty) {
      _showMsg("Please enter description");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get authority UID
      final prefs = await SharedPreferences.getInstance();
      final authorityUid = prefs.getString('authority_uid');

      if (authorityUid == null) {
        _showMsg("Authority user not found. Please login again.");
        setState(() => _isLoading = false);
        return;
      }

      // Upload image if selected
      String? imageUrl;
      if (_selectedImage != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('announcements')
            .child('${DateTime.now().millisecondsSinceEpoch}_$_imageFileName');

        final uploadTask = await storageRef.putFile(_selectedImage!);
        imageUrl = await uploadTask.ref.getDownloadURL();
      }

      // Determine target collection(s)
      String targetCollection = "";
      if (selectedAudience == "All Residents") {
        targetCollection = "users";
      } else if (selectedAudience == "All Workers") {
        targetCollection = "workers";
      } else if (selectedAudience == "All Security") {
        targetCollection = "security";
      } else {
        targetCollection = "everyone";
      }

      // Create announcement document
      await FirebaseFirestore.instance.collection("announcements").add({
        "title": _titleCtrl.text.trim(),
        "category": selectedCategory,
        "description": _descriptionCtrl.text.trim(),
        "imageUrl": imageUrl ?? "",
        "targetAudience": targetCollection,
        "priority": selectedPriority,
        "authorityUid": authorityUid,
        "timestamp": FieldValue.serverTimestamp(),
        "isActive": true,
      });

      // Send notifications to target audience
      await _sendAnnouncementNotifications(targetCollection);

      _showMsg("Announcement published successfully!");

      // Clear form
      _titleCtrl.clear();
      _descriptionCtrl.clear();
      setState(() {
        selectedCategory = "General Notice";
        selectedAudience = "All Residents";
        selectedPriority = "normal";
        _selectedImage = null;
        _imageFileName = null;
      });

      // Navigate back after delay
      await Future.delayed(const Duration(seconds: 2));
      Navigator.pop(context);
    } catch (e) {
      _showMsg("Error publishing announcement: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendAnnouncementNotifications(String targetCollection) async {
    try {
      final title = _titleCtrl.text.trim();
      final category = selectedCategory;
      int totalSent = 0;

      if (targetCollection == "everyone") {
        // Send to all users, workers, and security
        totalSent += await _sendToCollection("users", title, category);
        totalSent += await _sendToCollection("workers", title, category);
        totalSent += await _sendToCollection("security", title, category);
      } else {
        // Send to specific collection
        totalSent += await _sendToCollection(targetCollection, title, category);
      }

      print("Total notifications sent: $totalSent");
    } catch (e) {
      print("Error sending notifications: $e");
    }
  }

  Future<int> _sendToCollection(
    String collection,
    String title,
    String category,
  ) async {
    try {
      // Get all active/approved users from the target collection
      Query query = FirebaseFirestore.instance.collection(collection);

      // For workers, only send to approved/active ones
      if (collection == "workers") {
        query = query.where("isActive", isEqualTo: true);
      } else if (collection == "security") {
        // Security users are in 'workers' collection with profession 'Security'
        query = FirebaseFirestore.instance
            .collection("workers")
            .where("profession", isEqualTo: "Security")
            .where("isActive", isEqualTo: true);
      }

      final usersSnapshot = await query.get();

      print(
        "Sending notifications to ${usersSnapshot.docs.length} users in $collection",
      );

      // Create notification for each user
      int sent = 0;
      for (var userDoc in usersSnapshot.docs) {
        final docId = userDoc.id;

        // Use NotificationService for consistency and FCM support
        await NotificationService.sendNotification(
          userId: docId,
          userRole: collection == 'users'
              ? 'user'
              : (collection == 'workers' ? 'worker' : 'security'),
          title: 'New Announcement: $category',
          body: title,
          type: 'announcement',
          priority: selectedPriority,
          additionalData: {'category': category},
        );

        print("Notification sent to $collection user: $docId");
        sent++;
      }

      print("Successfully sent $sent notifications to $collection");
      return sent;
    } catch (e) {
      print("Error sending to $collection: $e");
      return 0;
    }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset('assets/bg1_img.png', fit: BoxFit.cover),
          ),

          // Content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Container(
                constraints: BoxConstraints(
                  minHeight:
                      MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title
                    const Text(
                      "Create Announcement",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 35),

                    // Announcement Title Field
                    _buildTextField(
                      controller: _titleCtrl,
                      hint: "Announcement Title",
                    ),

                    const SizedBox(height: 16),

                    // Category Dropdown
                    _buildDropdown(
                      value: selectedCategory,
                      items: categories
                          .map((cat) => cat["name"] as String)
                          .toList(),
                      hint: "Category",
                      onChanged: (value) {
                        setState(() => selectedCategory = value!);
                      },
                      prefixIcon: categories.firstWhere(
                        (cat) => cat["name"] == selectedCategory,
                      )["icon"],
                    ),

                    const SizedBox(height: 16),

                    // Description Field
                    _buildTextField(
                      controller: _descriptionCtrl,
                      hint: "Description",
                      maxLines: 5,
                    ),

                    const SizedBox(height: 16),

                    // Attach Image Button
                    _buildImagePicker(),

                    const SizedBox(height: 24),

                    // Priority Label
                    const Text(
                      "Notification Priority",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Priority Dropdown
                    _buildDropdown(
                      value: selectedPriority,
                      items: priorities
                          .map((p) => p["value"] as String)
                          .toList(),
                      hint: "Select Priority",
                      onChanged: (value) {
                        setState(() => selectedPriority = value!);
                      },
                      itemLabel: (value) => priorities.firstWhere(
                        (p) => p["value"] == value,
                      )["name"],
                      prefixIcon: priorities.firstWhere(
                        (p) => p["value"] == selectedPriority,
                      )["icon"],
                    ),

                    const SizedBox(height: 24),

                    // Select Target Audience Label
                    const Text(
                      "Select Target Audience",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Target Audience Dropdown
                    _buildDropdown(
                      value: selectedAudience,
                      items: audiences,
                      hint: "Select Audience",
                      onChanged: (value) {
                        setState(() => selectedAudience = value!);
                      },
                    ),

                    const SizedBox(height: 35),

                    // Publish Button
                    _buildPublishButton(),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),

          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 16, color: Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade600),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required String hint,
    required Function(String?) onChanged,
    String Function(String)? itemLabel,
    IconData? prefixIcon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (prefixIcon != null) ...[
            Icon(prefixIcon, color: Colors.grey.shade700, size: 22),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.grey.shade600,
                ),
                style: const TextStyle(fontSize: 16, color: Colors.black87),
                items: items.map((String item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(itemLabel != null ? itemLabel(item) : item),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.upload_outlined,
                color: Colors.grey.shade700,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                _imageFileName ?? "Attach Image (optional)",
                style: TextStyle(
                  fontSize: 16,
                  color: _imageFileName != null
                      ? Colors.black87
                      : Colors.grey.shade600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPublishButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _publishAnnouncement,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF7DD3C0), const Color(0xFF5FB8A9)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7DD3C0).withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Text(
          "Publish Announcement",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }
}
