import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'role_selection.dart';
import 'worker_dashboard.dart';

class WorkerLoginPage extends StatefulWidget {
  const WorkerLoginPage({super.key});

  @override
  State<WorkerLoginPage> createState() => _SafeNetLoginPageState();
}

class _SafeNetLoginPageState extends State<WorkerLoginPage> {
  bool _obscure = true;

  // 🔹 Added controllers
  final TextEditingController _loginCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  // -------------------------------------------------------------------
  // 🔥 WORKER LOGIN METHOD (email / username / phone)
  // -------------------------------------------------------------------
  Future<void> _loginWorker() async {
    final input = _loginCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (input.isEmpty || password.isEmpty) {
      _showMsg("Please fill all fields");
      return;
    }

    try {
      String email = "";
      final workers = FirebaseFirestore.instance.collection("workers");

      QuerySnapshot snap;

      // 🔹 If email
      if (input.contains("@")) {
        snap = await workers.where("email", isEqualTo: input).limit(1).get();
      }
      // 🔹 If phone number
      else if (RegExp(r'^[0-9]{10}$').hasMatch(input)) {
        snap = await workers.where("phone", isEqualTo: input).limit(1).get();
      }
      // 🔹 If username
      else {
        snap = await workers.where("username", isEqualTo: input).limit(1).get();
      }

      // 🔥 Check worker exists
      if (snap.docs.isEmpty) {
        _showMsg("No worker found with this username/phone/email");
        return;
      }

      final data = snap.docs.first.data() as Map<String, dynamic>;
      email = data["email"];

      // 🔥 Login using Firebase Auth
      final userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 🔍 Verify worker role again
      final uid = userCred.user!.uid;
      final userDoc = await workers.doc(uid).get();

      if (!userDoc.exists || userDoc["role"] != "worker") {
        FirebaseAuth.instance.signOut();
        _showMsg("Access Denied! Not a worker.");
        return;
      }

      // SUCCESS
      _showMsg("Worker Login Successful!");

      // Clear any authority session
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('authority_uid');
      await prefs.setString('user_role', 'worker');

      await Future.delayed(const Duration(seconds: 2));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => WorkerDashboardPage()),
      );
    } catch (e) {
      _showMsg("Login failed: $e");
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
            // 🔙 Custom Glass Back Button
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
                "Worker Login Page",
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

                  // 🔹 Login field (email/username/phone)
                  _glassTextField(
                    label: "Email / Username / Phone",
                    obscureText: false,
                    controller: _loginCtrl,
                  ),

                  const SizedBox(height: 18),

                  // 🔹 Password
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

                  // ------------------------------------------------------------------
                  // 🔥 LOGIN BUTTON connected to _loginWorker()
                  // ------------------------------------------------------------------
                  GestureDetector(
                    onTap: _loginWorker,
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

  // Glass-like TextField WITH controller
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
