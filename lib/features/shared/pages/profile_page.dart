import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  final String userCollection; // "users" (resident), "workers", "authority"

  const ProfilePage({super.key, required this.userCollection});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isEditing = false;
  bool _isLoading = true;
  String? _uid;
  Map<String, dynamic> _userData = {};

  // Controllers
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();
  final _buildingCtrl = TextEditingController();

  // Family Members (Dynamic List)
  List<TextEditingController> _familyControllers = [];

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      if (widget.userCollection == "authority") {
        final prefs = await SharedPreferences.getInstance();
        _uid = prefs.getString('authority_uid');
      } else {
        _uid = FirebaseAuth.instance.currentUser?.uid;
      }

      if (_uid == null) {
        setState(() => _isLoading = false);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection(widget.userCollection)
          .doc(_uid)
          .get();

      if (doc.exists) {
        _userData = doc.data()!;
        _populateControllers();
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _populateControllers() {
    _nameCtrl.text = _userData['username'] ?? '';
    _emailCtrl.text = _userData['email'] ?? '';
    _phoneCtrl.text = _userData['phone'] ?? '';
    _roomCtrl.text =
        _userData['flatNumber'] ??
        _userData['flatNo'] ??
        _userData['roomNo'] ??
        '';
    _buildingCtrl.text =
        _userData['buildingNumber'] ?? _userData['buildingNo'] ?? '';

    // Populate family members
    _familyControllers.clear();
    if (_userData['familyMembers'] != null) {
      for (var member in List<String>.from(_userData['familyMembers'])) {
        _familyControllers.add(TextEditingController(text: member));
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_uid == null) return;

    setState(() => _isLoading = true);

    try {
      Map<String, dynamic> updates = {
        'username': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
      };

      // Resident specific fields
      if (widget.userCollection == 'users') {
        updates['flatNumber'] = _roomCtrl.text.trim();
        updates['flatNo'] = _roomCtrl.text.trim();
        updates['buildingNumber'] = _buildingCtrl.text.trim();
        updates['familyMembers'] = _familyControllers
            .map((c) => c.text.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }

      await FirebaseFirestore.instance
          .collection(widget.userCollection)
          .doc(_uid)
          .update(updates);

      await _fetchUserData(); // Refresh data
      setState(() => _isEditing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to update profile: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addFamilyMember() {
    setState(() {
      _familyControllers.add(TextEditingController());
    });
  }

  void _removeFamilyMember(int index) {
    setState(() {
      _familyControllers.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isResident =
        widget.userCollection == 'users'; // Residents are in 'users'

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.45),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.black87),
          ),
        ),
        title: Text(
          _isEditing ? "Edit Profile" : "My Profile",
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () {
              if (_isEditing) {
                _saveProfile();
              } else {
                setState(() => _isEditing = true);
              }
            },
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _isEditing
                    ? const Color(0xFF3CBDB0)
                    : Colors.white.withOpacity(0.45),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  _isEditing ? "Save" : "Edit",
                  style: TextStyle(
                    color: _isEditing ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SizedBox.expand(
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset('assets/bg1_img.png', fit: BoxFit.cover),
            ),
            SafeArea(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                const CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.blueGrey,
                                  child: Icon(
                                    Icons.person,
                                    size: 50,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (_isEditing)
                                  TextButton.icon(
                                    onPressed: () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Upload photo coming soon",
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.camera_alt),
                                    label: const Text("Change Photo"),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),

                          _sectionTitle("Basic Info"),
                          _glassTextField(
                            "Name",
                            _nameCtrl,
                            enabled: _isEditing,
                          ),
                          const SizedBox(height: 12),
                          _glassTextField(
                            "Email",
                            _emailCtrl,
                            enabled: _isEditing,
                          ), // Maybe readonly?
                          const SizedBox(height: 12),
                          _glassTextField(
                            "Phone",
                            _phoneCtrl,
                            enabled: _isEditing,
                            isPhone: true,
                          ),

                          // Resident Specific Fields
                          if (isResident) ...[
                            const SizedBox(height: 24),
                            _sectionTitle("Address Info"),
                            Row(
                              children: [
                                Expanded(
                                  child: _glassTextField(
                                    "Flat No",
                                    _roomCtrl,
                                    enabled: _isEditing,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _glassTextField(
                                    "Building & Block",
                                    _buildingCtrl,
                                    enabled: _isEditing,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),
                            _sectionTitle("Family Members"),
                            if (_familyControllers.isEmpty && !_isEditing)
                              const Padding(
                                padding: EdgeInsets.only(left: 8.0, top: 4.0),
                                child: Text(
                                  "No family members added.",
                                  style: TextStyle(color: Colors.black54),
                                ),
                              ),

                            ..._familyControllers.asMap().entries.map((entry) {
                              int idx = entry.key;
                              TextEditingController ctrl = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _glassTextField(
                                        "Member Name",
                                        ctrl,
                                        enabled: _isEditing,
                                      ),
                                    ),
                                    if (_isEditing)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle,
                                          color: Colors.redAccent,
                                        ),
                                        onPressed: () =>
                                            _removeFamilyMember(idx),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),

                            if (_isEditing)
                              TextButton.icon(
                                onPressed: _addFamilyMember,
                                icon: const Icon(Icons.add),
                                label: const Text("Add Family Member"),
                              ),
                          ],

                          // Worker/Security Specific Fields
                          if (widget.userCollection == 'workers') ...[
                            const SizedBox(height: 24),
                            _sectionTitle("Work Info"),
                            _glassDisplayField(
                              "Role",
                              _userData['role'] ?? 'Worker',
                            ),
                            const SizedBox(height: 12),
                            _glassDisplayField(
                              "Profession",
                              _userData['profession'] ?? 'N/A',
                            ),
                          ],

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _glassTextField(
    String label,
    TextEditingController controller, {
    bool isPhone = false,
    bool enabled = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.6)),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          labelStyle: const TextStyle(color: Colors.black54),
        ),
      ),
    );
  }

  Widget _glassDisplayField(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
