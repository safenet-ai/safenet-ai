import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ResidentProfilePage extends StatefulWidget {
  const ResidentProfilePage({Key? key}) : super(key: key);

  @override
  State<ResidentProfilePage> createState() => _ResidentProfilePageState();
}

class _ResidentProfilePageState extends State<ResidentProfilePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _flatNoController = TextEditingController();
  final TextEditingController _buildingNoController = TextEditingController();
  final TextEditingController _blockController = TextEditingController();

  String _role = "resident";
  String _emergencyType = "Normal";

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          _nameController.text = data['username'] ?? data['name'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _flatNoController.text = data['flatNumber'] ?? data['flatNo'] ?? '';
          _buildingNoController.text = data['buildingNumber'] ?? '';
          _blockController.text = data['block'] ?? '';
          _role = data['role'] ?? 'resident';
          _emergencyType = data['emergencyType'] ?? 'Normal';
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfileData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'username': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'flatNumber': _flatNoController.text.trim(),
          'buildingNumber': _buildingNoController.text.trim(),
          'block': _blockController.text.trim(),
          'role': _role,
          'emergencyType': _emergencyType,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(
            context,
            true,
          ); // Return true to indicate success to previous screen
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Resident Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background Gradient matching app theme
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade900, Colors.purple.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildGlassContainer(
                            child: Column(
                              children: [
                                _buildTextField(
                                  controller: _nameController,
                                  label: 'Full Name',
                                  icon: Icons.person,
                                  validator: (v) => v!.isEmpty
                                      ? 'Name cannot be empty'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _phoneController,
                                  label: 'Phone Number',
                                  icon: Icons.phone,
                                  keyboardType: TextInputType.phone,
                                  validator: (v) => v!.length < 10
                                      ? 'Enter valid phone number'
                                      : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildGlassContainer(
                            child: Column(
                              children: [
                                _buildTextField(
                                  controller: _flatNoController,
                                  label: 'Flat Number',
                                  icon: Icons.home,
                                  validator: (v) => v!.isEmpty
                                      ? 'Flat number required'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _buildingNoController,
                                  label: 'Building Number',
                                  icon: Icons.apartment,
                                  validator: (v) => v!.isEmpty
                                      ? 'Building number required'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _blockController,
                                  label: 'Block Name (Optional)',
                                  icon: Icons.domain,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildGlassContainer(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Settings & Status",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _buildDropdown(
                                  label: "Emergency Priority",
                                  value: _emergencyType,
                                  items: ["Normal", "Priority"],
                                  onChanged: (val) =>
                                      setState(() => _emergencyType = val!),
                                  icon: Icons.warning,
                                ),
                                const SizedBox(height: 16),
                                // Role is read-only
                                TextFormField(
                                  initialValue: _role.toUpperCase(),
                                  enabled: false,
                                  style: const TextStyle(color: Colors.white54),
                                  decoration: InputDecoration(
                                    labelText: 'Role',
                                    labelStyle: const TextStyle(
                                      color: Colors.white54,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.admin_panel_settings,
                                      color: Colors.white54,
                                    ),
                                    disabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.white.withOpacity(0.3),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                          ElevatedButton(
                            onPressed: _isSaving ? null : _saveProfileData,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.blue.shade900,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 8,
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'SAVE PROFILE',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassContainer({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        prefixIcon: Icon(icon, color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade300, width: 2),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
    required IconData icon,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: Colors.blue.shade900,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        prefixIcon: Icon(icon, color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white),
        ),
      ),
      items: items.map((String item) {
        return DropdownMenuItem<String>(value: item, child: Text(item));
      }).toList(),
      onChanged: onChanged,
    );
  }
}
