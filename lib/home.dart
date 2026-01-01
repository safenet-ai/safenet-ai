import 'package:flutter/material.dart';
import 'login_authority.dart';
import 'login_residents.dart';
import 'login_security.dart';
import 'login_worker.dart';

class Homepage extends StatelessWidget {
  const Homepage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,

      body: Stack(
        children: [
          // Background gradient image
          Positioned.fill(
            child: Image.asset(
              'assets/bg1_img.png',
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
                      'assets/main_logo.png',
                      height: 90,
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      "SafeNet AI",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 30),

                    const Text(
                      "Select Your Role",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      "Choose your profile to continue",
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade700,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // ---------- FIXED RESPONSIVE GRID ----------
                    Wrap(
                      spacing: 20,
                      runSpacing: 20,
                      alignment: WrapAlignment.center,
                      children: [
                        roleBox(
                          context,
                          icon: Icons.shield_outlined,
                          label: "Authority",
                          bgColor: const Color(0xFFD9EFFF),
                        ),
                        roleBox(
                          context,
                          icon: Icons.home_outlined,
                          label: "Resident",
                          bgColor: const Color(0xFFD6F9E9),
                        ),
                        roleBox(
                          context,
                          icon: Icons.handyman_outlined,
                          label: "Worker",
                          bgColor: const Color(0xFFEEDAFA),
                        ),
                        roleBox(
                          context,
                          icon: Icons.verified_user_outlined,
                          label: "Security",
                          bgColor: const Color.fromARGB(255, 211, 242, 238),
                        ),
                      ],
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

  // ROLE BOX WIDGET
  Widget roleBox(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color bgColor,
  }) {
    return GestureDetector(
      onTap: () {
        if (label == "Authority") {
          Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AuthorityLoginPage()));
        } else if (label == "Resident") {
          Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ResidentLoginPage()));
        } else if (label == "Worker") {
          Navigator.push(context,
            MaterialPageRoute(builder: (_) => const WorkerLoginPage()));
        } else if (label == "Security") {
          Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SecurityLoginPage()));
        }
      },

      child: Container(
        width: 145,
        height: 145,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(4, 4),
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.8),
              blurRadius: 15,
              offset: const Offset(-4, -4),
            ),
          ],
        ),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 45, color: Colors.black54),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 17,
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
