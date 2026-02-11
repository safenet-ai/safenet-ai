import 'dart:ui';
import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  //bool _darkModeEnabled = false;

  @override
  Widget build(BuildContext context) {
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
        title: const Text(
          "Settings",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset('assets/bg1_img.png', fit: BoxFit.cover),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader("Preferences"),
                  const SizedBox(height: 10),
                  _glassContainer(
                    child: Column(
                      children: [
                        _switchTile(
                          "Push Notifications",
                          Icons.notifications_active_outlined,
                          _notificationsEnabled,
                          (val) => setState(() => _notificationsEnabled = val),
                        ),
                        // Divider(height: 1, color: Colors.black12), // Optional
                        // _switchTile(
                        //   "Dark Mode",
                        //   Icons.dark_mode_outlined,
                        //   _darkModeEnabled,
                        //   (val) => setState(() => _darkModeEnabled = val)
                        // ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  _sectionHeader("Account"),
                  const SizedBox(height: 10),
                  _glassContainer(
                    child: Column(
                      children: [
                        _actionTile(
                          "Change Password",
                          Icons.lock_outline,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Change Password feature coming soon",
                                ),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1, color: Colors.black12),
                        _actionTile(
                          "Privacy Policy",
                          Icons.privacy_tip_outlined,
                          onTap: () {
                            // Open URL or Show Dialog
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  _sectionHeader("About"),
                  const SizedBox(height: 10),
                  _glassContainer(
                    child: Column(
                      children: [
                        _actionTile(
                          "Version 1.0.0",
                          Icons.info_outline,
                          showArrow: false,
                        ),
                        const Divider(height: 1, color: Colors.black12),
                        _actionTile(
                          "Check for Updates",
                          Icons.update,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("App is up to date!"),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _glassContainer({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _switchTile(
    String title,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueGrey),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF3CBDB0),
          ),
        ],
      ),
    );
  }

  Widget _actionTile(
    String title,
    IconData icon, {
    VoidCallback? onTap,
    bool showArrow = true,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: Colors.blueGrey),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            if (showArrow)
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
