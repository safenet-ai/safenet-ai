import 'package:flutter/material.dart';
import 'workers_register.dart';
import 'residents_register.dart';
import 'home.dart';

class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,

      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset(
              "assets/bg1_img.png",
              fit: BoxFit.cover,
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Logo
                    Image.asset(
                      "assets/logo.png",
                      height: 100,
                    ),

                    const SizedBox(height: 30),

                    // Title
                    const Text(
                      "Choose Your\nRegistration Type",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: Color.fromARGB(255, 15, 15, 15),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Subtitle
                    Text(
                      "Select how you want to join Safe\nNet AI",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.4,
                        color: const Color.fromARGB(255, 12, 12, 12).withOpacity(0.85),
                      ),
                    ),

                    const SizedBox(height: 50),

                    // Register as Resident
                   _glassButton(
                      context,
                      color: const Color(0xFFDFFBEA),
                      icon: Icons.home_outlined,
                      text: "Register as Resident",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ResidentRegisterPage(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 25),

                    // Register as Worker Button
                    _glassButton(
                      context,
                      color: const Color(0xFFE9DBFF),
                      icon: Icons.build_outlined,
                      text: "Register as Worker",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WorkersRegisterPage(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 35),
                    // Already have account
                    Text(
                      "Already have an account?",
                      style: TextStyle(
                        fontSize: 16,
                        color: const Color.fromARGB(255, 12, 12, 12),
                      ),
                    ),
                    GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const Homepage(),
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
          ),
        ],
      ),
    );
  }

  // Glass Button Widget
  Widget _glassButton(
    BuildContext context, {
    required Color color,
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      height: 65,
      decoration: BoxDecoration(
        color: color.withOpacity(0.85),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.6),
            blurRadius: 12,
            offset: const Offset(-4, -4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: Colors.black54),
            const SizedBox(height: 8),
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
