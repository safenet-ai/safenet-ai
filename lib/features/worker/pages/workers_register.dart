import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../auth/pages/login_security.dart';
import '../../auth/pages/login_worker.dart'; // <-- adjust if your worker login file/class is different

class WorkersRegisterPage extends StatefulWidget {
  const WorkersRegisterPage({super.key});

  @override
  State<WorkersRegisterPage> createState() => _WorkersRegisterPageState();
}

class _WorkersRegisterPageState extends State<WorkersRegisterPage> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _obscure = true;
  bool _confirmObscure = true;

  String _selectedCountryCode = "+91"; // Default India
  String? _selectedProfession;
  final _professions = [
    "Electrician",
    "Plumber",
    "Carpenter",
    "Security",
    "Cleaner",
    "Water Supplier",
    "Other",
  ];

  final _otherProfessionCtrl = TextEditingController();

  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _otpNodes = List.generate(6, (index) => FocusNode());

  // Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // OTP state
  String? _verificationId;
  ConfirmationResult? _webConfirmationResult;
  bool _otpSent = false;
  bool _phoneVerified = false;
  bool _otpError = false;
  int _secondsRemaining = 0;
  Timer? _timer;
  bool _isVerifyingOtp = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _otherProfessionCtrl.dispose();

    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final n in _otpNodes) {
      n.dispose();
    }

    _timer?.cancel();
    super.dispose();
  }

  // -------------------------------------------------------------
  // 🔹 OTP TIMER
  // -------------------------------------------------------------
  void _startCountdown({required int seconds}) {
    _timer?.cancel();
    setState(() {
      _secondsRemaining = seconds;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 0) {
        timer.cancel();
        setState(() {});
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  // -------------------------------------------------------------
  // 🔹 SEND OTP (web + mobile)
  // -------------------------------------------------------------
  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();

    if (phone.isEmpty || phone.length < 6) {
      _msg("Enter a valid phone number");
      return;
    }

    setState(() {
      _otpSent = false;
      _phoneVerified = false;
      _otpError = false;
    });

    final phoneNumber = "$_selectedCountryCode$phone"; // Add country code

    try {
      if (kIsWeb) {
        // Web: signInWithPhoneNumber (uses reCAPTCHA)
        _webConfirmationResult = await _auth.signInWithPhoneNumber(phoneNumber);

        if (!mounted) return;

        setState(() {
          _otpSent = true;
        });

        _startCountdown(seconds: 180);

        _msg("OTP sent to $_selectedCountryCode$phone!");
      } else {
        // Mobile: verifyPhoneNumber
        await _auth.verifyPhoneNumber(
          phoneNumber: phoneNumber,
          verificationCompleted: (PhoneAuthCredential credential) {
            // We don't auto-complete login here (manual OTP entry only)
          },
          verificationFailed: (FirebaseAuthException e) {
            _msg("OTP failed: ${e.message}");
          },
          codeSent: (String verificationId, int? resendToken) {
            setState(() {
              _verificationId = verificationId;
              _otpSent = true;
            });

            _startCountdown(seconds: 60);
            _msg("OTP sent to $_selectedCountryCode$phone");
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            _verificationId = verificationId;
          },
        );
      }
    } catch (e) {
      _msg("Failed to send OTP: $e");
    }
  }

  // -------------------------------------------------------------
  // 🔹 VERIFY OTP (auto triggered when 6 digits entered)
  // -------------------------------------------------------------
  Future<void> _autoVerifyOtpIfComplete() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 6) return;
    if (_isVerifyingOtp) return; // avoid double calls

    _isVerifyingOtp = true;

    try {
      if (kIsWeb) {
        if (_webConfirmationResult == null) {
          _msg("Send OTP first");
          _setOtpStatus(error: true);
          _isVerifyingOtp = false;
          return;
        }

        await _webConfirmationResult!.confirm(otp);

        // Sign out temp phone user to avoid conflicts with email/password signup
        await _auth.signOut();

        if (!mounted) return;

        _setOtpStatus(success: true);
        _msg("Phone verified successfully");
      } else {
        if (_verificationId == null) {
          _msg("Send OTP first");
          _setOtpStatus(error: true);
          _isVerifyingOtp = false;
          return;
        }

        final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: otp,
        );

        await _auth.signInWithCredential(credential);

        // Sign out temp phone user
        await _auth.signOut();

        if (!mounted) return;

        _setOtpStatus(success: true);
        _msg("Phone verified successfully");
      }
    } catch (e) {
      _clearOtpFields();
      _setOtpStatus(error: true);
      _msg("Invalid OTP");
    } finally {
      _isVerifyingOtp = false;
    }
  }

  void _setOtpStatus({bool success = false, bool error = false}) {
    setState(() {
      _phoneVerified = success;
      _otpError = error;
    });
  }

  void _clearOtpFields() {
    for (final c in _otpControllers) {
      c.clear();
    }
    if (_otpNodes.isNotEmpty) {
      FocusScope.of(context).requestFocus(_otpNodes[0]);
    }
  }

  // -------------------------------------------------------------
  // 🔹 REGISTER WORKER (requires OTP verified)
  // -------------------------------------------------------------
  Future<void> _registerWorker() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final pass = _passwordCtrl.text.trim();
    final confirm = _confirmPasswordCtrl.text.trim();

    if (name.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        pass.isEmpty ||
        confirm.isEmpty ||
        _selectedProfession == null) {
      _msg("Please fill all fields");
      return;
    }

    if (!email.contains('@')) {
      _msg("Enter a valid email address");
      return;
    }

    if (pass.length < 8) {
      _msg("Password must be at least 8 characters");
      return;
    }

    if (pass != confirm) {
      _msg("Passwords do not match");
      return;
    }

    if (!_phoneVerified) {
      _msg("Please verify OTP first");
      return;
    }

    String finalProfession = _selectedProfession!;
    if (finalProfession == "Other") {
      if (_otherProfessionCtrl.text.trim().isEmpty) {
        _msg("Please enter your profession");
        return;
      }
      finalProfession = _otherProfessionCtrl.text.trim();
    }

    try {
      UserCredential user = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );

      final uid = user.user!.uid;

      await FirebaseFirestore.instance.collection("workers").doc(uid).set({
        "uid": uid,
        "username": name,
        "email": email,
        "phone": phone,
        "profession": finalProfession,
        "role": "worker",

        // 🔐 NEW
        "approvalStatus": "pending", // Authority must approve
        "isActive": false, // Optional safety flag

        "created_at": FieldValue.serverTimestamp(),

        /* 🔐 Authority approval system
        "approvalStatus": "pending",
        "approvedBy": null,
        "approvedAt": null,*/
      });

      if (!mounted) return;

      _msg("Registration successful!");

      // Delay 2 seconds before redirect
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      // Redirect based on profession
      final lower = finalProfession.toLowerCase();
      if (lower.contains("security")) {
        // Security Guard → Authority login
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SecurityLoginPage()),
        );
      } else {
        // Other workers → Workers login
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const WorkerLoginPage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String msg = "Registration failed";
      if (e.code == 'email-already-in-use') {
        msg = "This email is already registered. Please log in instead.";
      } else if (e.code == 'weak-password') {
        msg = "Password is too weak. Please choose a stronger password.";
      } else if (e.code == 'invalid-email') {
        msg = "Please enter a valid email address.";
      }
      _msg(msg);
    } catch (e) {
      _msg("Error: $e");
    }
  }

  void _msg(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // -------------------------------------------------------------
  // UI WIDGETS (Glass Field, OTP, Buttons)
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white.withOpacity(0.3),
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
                    ),
                    child: Icon(Icons.arrow_back, color: Colors.grey.shade800),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Worker Registration Page",
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
            child: Image.asset("assets/bg1_img.png", fit: BoxFit.cover),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: w * 0.06),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Image.asset("assets/logo.png", height: 80),
                  const SizedBox(height: 12),
                  Text(
                    "Create Your Account",
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 20),

                  _glassField(
                    child: TextField(
                      controller: _nameCtrl,
                      decoration: _inputDecoration("Full Name / Username"),
                      style: TextStyle(color: Colors.grey.shade800),
                    ),
                  ),
                  const SizedBox(height: 14),

                  _glassField(
                    child: TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecoration("Email Address"),
                      style: TextStyle(color: Colors.grey.shade800),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      // Country Code Dropdown
                      Container(
                        width: 90,
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.28),
                          ),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedCountryCode,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: "+1", child: Text("+1")),
                            DropdownMenuItem(value: "+44", child: Text("+44")),
                            DropdownMenuItem(value: "+91", child: Text("+91")),
                            DropdownMenuItem(value: "+92", child: Text("+92")),
                            DropdownMenuItem(value: "+93", child: Text("+93")),
                            DropdownMenuItem(
                              value: "+880",
                              child: Text("+880"),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedCountryCode = value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: _glassField(
                          child: TextField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: _inputDecoration("Phone Number"),
                            style: TextStyle(color: Colors.grey.shade800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _otpButton(),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (i) => _otpBox(i)),
                  ),

                  const SizedBox(height: 14),

                  _glassField(
                    child: DropdownButtonFormField<String>(
                      value: _selectedProfession,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isCollapsed: true,
                      ),
                      hint: const Text("Profession / Work Type"),
                      items: _professions
                          .map(
                            (p) => DropdownMenuItem(value: p, child: Text(p)),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() => _selectedProfession = value);
                      },
                    ),
                  ),

                  const SizedBox(height: 14),

                  if (_selectedProfession == "Other")
                    _glassField(
                      child: TextField(
                        controller: _otherProfessionCtrl,
                        decoration: _inputDecoration(
                          "Enter your profession manually",
                        ),
                      ),
                    ),

                  const SizedBox(height: 14),

                  _glassField(
                    child: TextField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        hintText: "Password",
                        border: InputBorder.none,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility : Icons.visibility_off,
                            color: Colors.grey.shade600,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  _glassField(
                    child: TextField(
                      controller: _confirmPasswordCtrl,
                      obscureText: _confirmObscure,
                      decoration: InputDecoration(
                        hintText: "Confirm Password",
                        border: InputBorder.none,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _confirmObscure
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.grey.shade600,
                          ),
                          onPressed: () => setState(
                            () => _confirmObscure = !_confirmObscure,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Container(
                    height: 56,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3CBDB0), Color(0xFF128071)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ElevatedButton(
                      onPressed: _registerWorker,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                      ),
                      child: const Text(
                        "Register",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
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
    );
  }

  Widget _glassField({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.28)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: child,
        ),
      ),
    );
  }

  Widget _otpBox(int index) {
    Color borderColor;
    if (_phoneVerified) {
      borderColor = Colors.green.shade600;
    } else if (_otpError) {
      borderColor = Colors.red.shade600;
    } else {
      borderColor = Colors.white.withOpacity(0.28);
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: _phoneVerified ? 2 : 1),
      ),
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _otpNodes[index],
        textAlign: TextAlign.center,
        maxLength: 1,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          counterText: "",
          border: InputBorder.none,
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            FocusScope.of(context).requestFocus(_otpNodes[index + 1]);
          }
          if (value.isEmpty && index > 0) {
            FocusScope.of(context).requestFocus(_otpNodes[index - 1]);
          }

          // Auto verify when 6 digits entered
          _autoVerifyOtpIfComplete();
        },
      ),
    );
  }

  Widget _otpButton() {
    return Container(
      width: 110,
      height: 46,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3CBDB0), Color(0xFF128071)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextButton(
        onPressed: _secondsRemaining == 0 ? _sendOtp : null,
        child: Text(
          _secondsRemaining == 0
              ? (_otpSent ? "Resend OTP" : "Send OTP")
              : "Wait $_secondsRemaining s",
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      border: InputBorder.none,
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade700),
    );
  }
}
