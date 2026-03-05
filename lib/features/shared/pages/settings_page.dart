import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/notification_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _isLoading = true;
  //bool _darkModeEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreference();
  }

  Future<void> _loadNotificationPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('notifications_enabled') ?? true;

    // Check actual permission status
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.getNotificationSettings();

    setState(() {
      _notificationsEnabled =
          enabled &&
          settings.authorizationStatus == AuthorizationStatus.authorized;
      _isLoading = false;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    final messaging = FirebaseMessaging.instance;
    final prefs = await SharedPreferences.getInstance();

    if (value) {
      // 1. Request permission
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // 2. Permission granted - Get/Update Token
        await prefs.setBool('notifications_enabled', true);

        // Re-initialize notification service to save token and start listeners
        await NotificationService.initialize();

        setState(() {
          _notificationsEnabled = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Push notifications enabled'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Permission denied
        setState(() {
          _notificationsEnabled = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Notification permission denied. Please enable in system settings.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      // 1. Disable notifications in preference
      await prefs.setBool('notifications_enabled', false);

      try {
        // 2. Remove token from Firestore, delete locally, and stop listeners
        await NotificationService.removeFCMToken();
        await messaging.deleteToken();
        NotificationService.stopListening();
        print('FCM Token deleted and listeners stopped successfully.');
      } catch (e) {
        print('Error disabling FCM tokens/listeners: $e');
      }

      setState(() {
        _notificationsEnabled = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Push notifications disabled (System alerts stopped)',
            ),
          ),
        );
      }
    }
  }

  // Helper import for RE-INITIALIZING
  // (Assuming NotificationService is accessible)

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
      body: SizedBox.expand(
        child: Stack(
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
                          _isLoading
                              ? const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(),
                                )
                              : _switchTile(
                                  "Push Notifications",
                                  Icons.notifications_active_outlined,
                                  _notificationsEnabled,
                                  _toggleNotifications,
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
                            onTap: () => _showChangePasswordDialog(),
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
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  //  Change Password dialog
  // ──────────────────────────────────────────────────────────
  Future<void> _showChangePasswordDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final userRole = prefs.getString('user_role') ?? 'resident';

    // Authority uses a custom unique_id stored in Firestore,
    // not Firebase Auth — handle separately.
    if (userRole == 'authority') {
      _showAuthorityPasswordDialog();
      return;
    }

    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              '🔒 Change Password',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(
                  controller: currentPassCtrl,
                  label: 'Current Password',
                  obscure: obscureCurrent,
                  toggle: () =>
                      setDialogState(() => obscureCurrent = !obscureCurrent),
                ),
                const SizedBox(height: 12),
                _dialogField(
                  controller: newPassCtrl,
                  label: 'New Password',
                  obscure: obscureNew,
                  toggle: () => setDialogState(() => obscureNew = !obscureNew),
                ),
                const SizedBox(height: 12),
                _dialogField(
                  controller: confirmPassCtrl,
                  label: 'Confirm New Password',
                  obscure: obscureConfirm,
                  toggle: () =>
                      setDialogState(() => obscureConfirm = !obscureConfirm),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(dialogCtx),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final currentPass = currentPassCtrl.text.trim();
                        final newPass = newPassCtrl.text.trim();
                        final confirmPass = confirmPassCtrl.text.trim();

                        if (currentPass.isEmpty ||
                            newPass.isEmpty ||
                            confirmPass.isEmpty) {
                          _snack('Please fill all fields.');
                          return;
                        }
                        if (newPass.length < 6) {
                          _snack('New password must be at least 6 characters.');
                          return;
                        }
                        if (newPass != confirmPass) {
                          _snack('Passwords do not match.');
                          return;
                        }

                        setDialogState(() => isLoading = true);
                        try {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user == null || user.email == null) {
                            _snack('No logged-in user found.');
                            return;
                          }

                          // Re-authenticate first
                          final credential = EmailAuthProvider.credential(
                            email: user.email!,
                            password: currentPass,
                          );
                          await user.reauthenticateWithCredential(credential);

                          // Update password
                          await user.updatePassword(newPass);

                          if (mounted) Navigator.pop(dialogCtx);
                          _snack(
                            'Password changed successfully! ✅',
                            success: true,
                          );
                        } on FirebaseAuthException catch (e) {
                          String msg = 'Error changing password.';
                          // 'wrong-password' is the legacy code; newer Firebase
                          // SDK (v10+) returns 'invalid-credential' for the same
                          // error, so we must handle both.
                          if (e.code == 'wrong-password' ||
                              e.code == 'invalid-credential' ||
                              e.code == 'invalid-login-credentials') {
                            msg = 'Current password is incorrect.';
                          } else if (e.code == 'weak-password') {
                            msg = 'New password is too weak (min 6 chars).';
                          } else if (e.code == 'requires-recent-login') {
                            msg =
                                'Session expired. Please log out and log in again, then retry.';
                          } else if (e.code == 'too-many-requests') {
                            msg =
                                'Too many attempts. Please wait a moment and try again.';
                          } else if (e.code == 'network-request-failed') {
                            msg = 'Network error. Check your connection.';
                          }
                          _snack(msg);
                        } catch (e) {
                          _snack('Error: $e');
                        } finally {
                          if (mounted) {
                            setDialogState(() => isLoading = false);
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3CBDB0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Update'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Change password for Authority users (unique_id stored in Firestore)
  Future<void> _showAuthorityPasswordDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final authorityUid = prefs.getString('authority_uid');
    if (authorityUid == null) {
      _snack('Authority session not found. Please log in again.');
      return;
    }

    final currentIdCtrl = TextEditingController();
    final newIdCtrl = TextEditingController();
    final confirmIdCtrl = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              '🔒 Change Password',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(
                  controller: currentIdCtrl,
                  label: 'Current Password',
                  obscure: obscureCurrent,
                  toggle: () =>
                      setDialogState(() => obscureCurrent = !obscureCurrent),
                ),
                const SizedBox(height: 12),
                _dialogField(
                  controller: newIdCtrl,
                  label: 'New Password',
                  obscure: obscureNew,
                  toggle: () => setDialogState(() => obscureNew = !obscureNew),
                ),
                const SizedBox(height: 12),
                _dialogField(
                  controller: confirmIdCtrl,
                  label: 'Confirm New Password',
                  obscure: obscureConfirm,
                  toggle: () =>
                      setDialogState(() => obscureConfirm = !obscureConfirm),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(dialogCtx),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final current = currentIdCtrl.text.trim();
                        final newId = newIdCtrl.text.trim();
                        final confirmId = confirmIdCtrl.text.trim();

                        if (current.isEmpty ||
                            newId.isEmpty ||
                            confirmId.isEmpty) {
                          _snack('Please fill all fields.');
                          return;
                        }
                        if (newId != confirmId) {
                          _snack('Passwords do not match.');
                          return;
                        }

                        setDialogState(() => isLoading = true);
                        try {
                          // Verify current unique_id matches Firestore
                          final doc = await FirebaseFirestore.instance
                              .collection('authority')
                              .doc(authorityUid)
                              .get();

                          if (!doc.exists) {
                            _snack('Authority account not found.');
                            return;
                          }

                          final storedId = doc.data()?['unique_id'] ?? '';
                          if (storedId != current) {
                            _snack('Current password is incorrect.');
                            return;
                          }

                          // Update unique_id
                          await FirebaseFirestore.instance
                              .collection('authority')
                              .doc(authorityUid)
                              .update({'unique_id': newId});

                          if (mounted) Navigator.pop(dialogCtx);
                          _snack(
                            'Password changed successfully! ✅',
                            success: true,
                          );
                        } catch (e) {
                          _snack('Error: $e');
                        } finally {
                          if (mounted) {
                            setDialogState(() => isLoading = false);
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3CBDB0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Update'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _snack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green.shade700 : null,
      ),
    );
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback toggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
          onPressed: toggle,
        ),
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
