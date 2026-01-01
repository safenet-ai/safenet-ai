import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_residents.dart';

class ResidentRegisterPage extends StatefulWidget {
  const ResidentRegisterPage({super.key});

  @override
  State<ResidentRegisterPage> createState() => _ResidentRegisterPageState();
}

class _ResidentRegisterPageState extends State<ResidentRegisterPage> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  final _scrollController = ScrollController();

  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpNodes = List.generate(6, (_) => FocusNode());

  // OTP state
  String? _verificationId;
  bool _otpSent = false;
  bool _phoneVerified = false;
  int _secondsRemaining = 0;
  Timer? _timer;

  // Country codes
  final List<String> _countryCodes = const [
    '+1', '+7', '+20', '+27', '+30', '+31', '+32', '+33', '+34', '+36', '+39',
    '+40', '+44', '+45', '+46', '+47', '+48', '+49', '+51', '+52', '+53', '+54',
    '+55', '+56', '+57', '+60', '+61', '+62', '+63', '+64', '+65', '+66', '+81',
    '+82', '+84', '+86', '+90', '+91', '+92', '+93', '+94', '+95', '+98',
    '+212', '+213', '+218', '+971', '+974', '+965', '+966', '+880', '+370',
    '+371', '+372', '+420', '+353', '+358', '+380'
  ];

  String _selectedCountryCode = '+91';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _scrollController.dispose();

    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final n in _otpNodes) {
      n.dispose();
    }

    _timer?.cancel();
    super.dispose();
  }

  // COUNTDOWN TIMER
  void _startCountdown() {
    _timer?.cancel();
    setState(() {
      _secondsRemaining = 60;
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

  // SEND OTP
  Future<void> _sendOtp() async {
    final rawPhone = _phoneCtrl.text.trim();

    if (rawPhone.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Enter phone number")));
      return;
    }

    setState(() {
      _otpSent = false;
      _phoneVerified = false;
    });

    final phoneNumber = "$_selectedCountryCode$rawPhone";

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),

        verificationCompleted: (PhoneAuthCredential credential) {},

        verificationFailed: (FirebaseAuthException e) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("OTP Failed: ${e.message}")));
        },

        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _otpSent = true;
          });

          _startCountdown();

          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text("OTP Sent")));
        },

        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Failed to send OTP: $e")));
    }
  }

  // VERIFY OTP (AUTO when 6 digits entered)
  Future<bool> _verifyOtp() async {
    final otp = _otpControllers.map((c) => c.text).join();

    if (otp.length != 6) {
      return false;
    }

    if (_verificationId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Send OTP first")));
      return false;
    }

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      await FirebaseAuth.instance.signOut();

      setState(() => _phoneVerified = true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Phone verified successfully")),
      );

      return true;
    } catch (e) {
      _clearOtpFields();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Invalid OTP")));
      return false;
    }
  }

  void _clearOtpFields() {
    for (final c in _otpControllers) {
      c.clear();
    }
    FocusScope.of(context).requestFocus(_otpNodes[0]);
    setState(() => _phoneVerified = false);
  }

  // REGISTER USER
  Future<void> _registerUser() async {
    final username = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final pass = _passwordCtrl.text.trim();
    final confirmPass = _confirmPasswordCtrl.text.trim();

    if (username.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        pass.isEmpty ||
        confirmPass.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    if (pass != confirmPass) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Passwords do not match")));
      return;
    }

    if (!_phoneVerified) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Please verify OTP first")));
      return;
    }

    try {
      UserCredential user =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );

      final uid = user.user!.uid;

      await FirebaseFirestore.instance.collection("users").doc(uid).set({
        "uid": uid,
        "username": username,
        "email": email,
        "phone": "$_selectedCountryCode$phone",
        "role": "resident",

        // 🔐 NEW
        "approvalStatus": "pending",
        "isActive": false,

        "created_at": FieldValue.serverTimestamp(),

       /* // 🔐 Authority approval system
        "approvalStatus": "pending",   // pending | approved | rejected
        "approvedBy": null,
        "approvedAt": null,*/
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Registration Successful!"),
          duration: Duration(seconds: 2),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ResidentLoginPage()),
        );
      }
    } catch (e) {
      print("[v0] Registration error: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // OTP BOX UI — UPDATED WITH AUTO VERIFY
  Widget _otpBox(int i) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _phoneVerified ? Colors.green.shade600 : Colors.white.withOpacity(0.28),
          width: _phoneVerified ? 2 : 1,
        ),
      ),
      child: TextField(
        controller: _otpControllers[i],
        focusNode: _otpNodes[i],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        decoration: const InputDecoration(counterText: "", border: InputBorder.none),
        onChanged: (value) async {
          if (value.isNotEmpty && i < 5) {
            _otpNodes[i + 1].requestFocus();
          }

          final otp = _otpControllers.map((c) => c.text).join();
          if (otp.length == 6) {
            bool ok = await _verifyOtp();
            if (!ok) _clearOtpFields();
          }
        },
        style: TextStyle(
          color: Colors.grey.shade800,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // OTP BUTTON
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
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      border: InputBorder.none,
      isCollapsed: true,
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade700),
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
    );
  }

  Widget _simpleField({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.28)),
      ),
      child: child,
    );
  }

  // --------------------------
  // UI BUILD
  // --------------------------
  @override
  Widget build(BuildContext context) {
    final double w = MediaQuery.of(context).size.width;

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
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Resident Registration Page",
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

      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset("assets/bg1_img.png", fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: Container(color: Colors.white.withOpacity(0.02)),
            ),

            SafeArea(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.symmetric(horizontal: w * 0.06),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
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

                    const SizedBox(height: 10),

                    Text(
                      "Join SafeNet AI to manage your\nresidence securely",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
                    ),

                    const SizedBox(height: 20),

                    // USERNAME
                    _simpleField(
                      child: TextField(
                        controller: _nameCtrl,
                        decoration: _inputDecoration("Username"),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // EMAIL
                    _simpleField(
                      child: TextField(
                        controller: _emailCtrl,
                        decoration: _inputDecoration("Email"),
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // PHONE + OTP
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _simpleField(
                            child: Row(
                              children: [
                                DropdownButtonHideUnderline(
                                  child: DropdownButton(
                                    value: _selectedCountryCode,
                                    items: _countryCodes
                                        .map(
                                          (code) => DropdownMenuItem(
                                            value: code,
                                            child: Text(code),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() => _selectedCountryCode = v);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const VerticalDivider(color: Colors.white24),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _phoneCtrl,
                                    keyboardType: TextInputType.phone,
                                    decoration: _inputDecoration("Phone Number"),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _otpButton(),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // OTP BOXES
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (i) => _otpBox(i)),
                    ),

                    const SizedBox(height: 10),

                    if (_secondsRemaining > 0)
                      Text("Resend in $_secondsRemaining sec",
                          style: TextStyle(color: Colors.grey.shade700)),

                    const SizedBox(height: 20),

                    // PASSWORD
                    _simpleField(
                      child: ObscurableTextField(
                        controller: _passwordCtrl,
                        hintText: "Password",
                      ),
                    ),

                    const SizedBox(height: 14),

                    // CONFIRM PASSWORD
                    _simpleField(
                      child: ObscurableTextField(
                        controller: _confirmPasswordCtrl,
                        hintText: "Confirm Password",
                      ),
                    ),

                    const SizedBox(height: 20),

                    // REGISTER BUTTON — UPDATED
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
                        onPressed: () async {
                          if (!_phoneVerified) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Please verify OTP first")),
                            );
                            return;
                          }

                          await _registerUser();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          "Register",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Already have an account?",
                            style: TextStyle(color: Colors.grey.shade700)),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const ResidentLoginPage()));
                          },
                          child: Text(
                            " Log in",
                            style: TextStyle(
                              color: Colors.teal.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// PASSWORD FIELD
class ObscurableTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  const ObscurableTextField({
    super.key,
    required this.controller,
    required this.hintText,
  });

  @override
  State<ObscurableTextField> createState() => _ObscurableTextFieldState();
}

class _ObscurableTextFieldState extends State<ObscurableTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: widget.controller,
            obscureText: _obscure,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: widget.hintText,
              hintStyle: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        ),
        GestureDetector(
          onTap: () => setState(() => _obscure = !_obscure),
          child: Icon(
            _obscure ? Icons.visibility : Icons.visibility_off,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}
