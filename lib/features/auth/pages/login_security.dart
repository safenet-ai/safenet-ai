import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/notification_service.dart'; // Added Import
import './role_selection.dart';
import '../../security/pages/security_dashboard.dart';

class SecurityLoginPage extends StatefulWidget {
  const SecurityLoginPage({super.key});

  @override
  State<SecurityLoginPage> createState() => _SecurityLoginPageState();
}

class _SecurityLoginPageState extends State<SecurityLoginPage> {
  bool _obscure = true;

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  // ------------------- LOGIN FUNCTION -------------------

  Future<void> _loginSecurity() async {
    final input = _emailCtrl.text.trim();
    final password = _passCtrl.text.trim();

    if (input.isEmpty || password.isEmpty) {
      _showMsg("Please enter username/email/phone and password");
      return;
    }

    try {
      DocumentSnapshot? snap;

      // Detect input type
      bool isEmail = input.contains("@");
      bool isPhone = RegExp(r'^[0-9]{10,}$').hasMatch(input); // 10+ digits

      // 1️⃣ Search workers collection according to input
      if (isEmail) {
        snap = await FirebaseFirestore.instance
            .collection("workers")
            .where("email", isEqualTo: input)
            .limit(1)
            .get()
            .then((q) => q.docs.isNotEmpty ? q.docs.first : null);
      } else if (isPhone) {
        snap = await FirebaseFirestore.instance
            .collection("workers")
            .where("phone", isEqualTo: "+91$input")
            .limit(1)
            .get()
            .then((q) => q.docs.isNotEmpty ? q.docs.first : null);
      } else {
        // Username login
        snap = await FirebaseFirestore.instance
            .collection("workers")
            .where("username", isEqualTo: input)
            .limit(1)
            .get()
            .then((q) => q.docs.isNotEmpty ? q.docs.first : null);
      }

      if (snap == null) {
        _showMsg("No security worker found");
        return;
      }

      final data = snap.data() as Map<String, dynamic>;

      final email = data["email"];
      if (email == null) {
        _showMsg("Account does not have a valid email");
        return;
      }

      // 2️⃣ Firebase login using email
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 3️⃣ Validate security role
      if (data["role"] == "worker" &&
          data["profession"].toString().toLowerCase().contains("security")) {
        _showMsg("Login Successful!");

        // Clear any authority session
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('authority_uid');
        await prefs.setString('user_role', 'security');

        // 🔔 Save FCM Token immediately
        await NotificationService.saveFCMToken();

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => SecurityDashboardPage()),
          (route) => false,
        );
      } else {
        _showMsg("This account is NOT a security worker");
        FirebaseAuth.instance.signOut();
      }
    } catch (e) {
      _showMsg("Login failed: $e");
    }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: Icon(Icons.arrow_back, color: Colors.grey.shade800),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Security Login Page",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),

      // ---------------- UI ----------------
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/bg1_img.png', fit: BoxFit.cover),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 100),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/logo.png', height: 60),
                      const SizedBox(width: 12),
                      Text(
                        "SafeNet AI",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 50),

                  // Email
                  _glassTextField(
                    controller: _emailCtrl,
                    label: "Email",
                    obscureText: false,
                  ),

                  const SizedBox(height: 18),

                  // Password
                  _glassTextField(
                    controller: _passCtrl,
                    label: "Password",
                    obscureText: _obscure,
                    suffix: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "Forgot password?",
                      style: TextStyle(
                        color: Colors.teal.shade400,
                        fontSize: 14,
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ---------------- LOGIN BUTTON ----------------
                  GestureDetector(
                    onTap: _loginSecurity,
                    child: Container(
                      height: 54,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3CBDB0), Color(0xFF128071)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          "Log in",
                          style: TextStyle(
                            color: Colors.grey.shade800,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 1,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 10),
                      Text("OR", style: TextStyle(color: Colors.grey.shade600)),
                      const SizedBox(width: 10),
                      Container(
                        width: 40,
                        height: 1,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  Text(
                    "Don’t have an account?",
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                  ),

                  const SizedBox(height: 5),

                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RoleSelectionPage(),
                        ),
                      );
                    },
                    child: Text(
                      "Sign up",
                      style: TextStyle(
                        fontSize: 17,
                        color: Colors.teal.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Glass-like TextField
  Widget _glassTextField({
    required String label,
    required bool obscureText,
    required TextEditingController controller,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: TextStyle(color: Colors.grey.shade800),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: TextStyle(color: Colors.grey.shade700),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 17,
          ),
          suffixIcon: suffix,
        ),
      ),
    );
  }
}
