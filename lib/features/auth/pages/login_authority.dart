import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './role_selection.dart';
import '../../authority/pages/authority_dashboard.dart';

class AuthorityLoginPage extends StatefulWidget {
  const AuthorityLoginPage({super.key});

  @override
  State<AuthorityLoginPage> createState() => _SafeNetLoginPageState();
}

class _SafeNetLoginPageState extends State<AuthorityLoginPage> {
  bool _obscure = true;

  // 🔹 Add controllers
  final TextEditingController _emailOrUsernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  // -------------------------------------------------------------------
  // 🔥 AUTHORITY LOGIN METHOD (ONLY THIS IS ADDED)
  // -------------------------------------------------------------------
  Future<void> _loginAuthority() async {
    final input = _emailOrUsernameCtrl.text.trim(); // email or username
    final password = _passwordCtrl.text.trim(); // unique_id

    if (input.isEmpty || password.isEmpty) {
      _showMsg("Please enter Email/Username and Password");
      return;
    }

    try {
      final authorityRef = FirebaseFirestore.instance.collection("authority");

      QuerySnapshot<Map<String, dynamic>> snap;

      // 🔹 If input contains "@", it's an email
      if (input.contains("@")) {
        snap = await authorityRef
            .where("email", isEqualTo: input)
            .where("unique_id", isEqualTo: password)
            .limit(1)
            .get();
      } else {
        // 🔹 Otherwise it's a username
        snap = await authorityRef
            .where("username", isEqualTo: input)
            .where("unique_id", isEqualTo: password)
            .limit(1)
            .get();
      }

      if (snap.docs.isEmpty) {
        _showMsg("Invalid Email/Username or Password");
        return;
      }

      final data = snap.docs.first.data();
      final authorityUid = snap.docs.first.id;

      // 🔒 Extra safety: Verify role
      if (data["role"] != "authority") {
        _showMsg("Access denied: Not an authority account");
        return;
      }

      // 🔥 Sign out any existing Firebase Auth session
      await FirebaseAuth.instance.signOut();

      // 🔥 Store authority UID in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('authority_uid', authorityUid);
      await prefs.setString('user_role', 'authority');

      // ⭐ SHOW SUCCESS MESSAGE
      _showMsg("Login Successful!");

      // ⭐ WAIT 2 SECONDS
      await Future.delayed(const Duration(seconds: 2));

      // ⭐ REDIRECT AFTER DELAY
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthorityDashboardPage()),
        (route) => false,
      );
    } catch (e) {
      _showMsg("Login failed. Please try again.");
    }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // -------------------------------------------------------------------

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
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.07),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(Icons.arrow_back, color: Colors.grey.shade800),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            const Expanded(
              child: Text(
                "Authority Login Page",
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

                  // 🔹 EMAIL OR USERNAME FIELD (controller mapped)
                  _glassTextField(
                    label: "Email or Username",
                    obscureText: false,
                    controller: _emailOrUsernameCtrl,
                  ),

                  const SizedBox(height: 18),

                  // 🔹 PASSWORD FIELD (controller mapped)
                  _glassTextField(
                    label: "Password",
                    obscureText: _obscure,
                    controller: _passwordCtrl,
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

                  // -------------------------------------------------------------------
                  // 🔥 LOGIN BUTTON — CONNECTED TO FIREBASE LOGIN
                  // -------------------------------------------------------------------
                  GestureDetector(
                    onTap: _loginAuthority,
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

                  // -------------------------------------------------------------------
                  const SizedBox(height: 30),

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

  // Glass-like TextField (updated to accept controller)
  Widget _glassTextField({
    required String label,
    required bool obscureText,
    Widget? suffix,
    TextEditingController? controller,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
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
