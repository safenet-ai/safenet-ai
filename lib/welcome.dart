import 'package:flutter/material.dart';
import 'home.dart';

class SafeNetWelcomePage extends StatelessWidget {
  const SafeNetWelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,

      body: Stack(
        children: [
          // Background Gradient Image
          Positioned.fill(
            child: Image.asset(
              'assets/bg1_img.png', // your background image
              fit: BoxFit.cover,
            ),
          ),

          // CONTENT
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),

                    // Logo
                    Image.asset(
                      'assets/main_logo.png', // your logo
                      height: 150

                    ),

                    const SizedBox(height: 20),

                    // Title
                    const Text(
                      "SafeNet AI",
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Subtitle
                    Text(
                      "Smart Residence Management",
                      style: TextStyle(
                        fontSize: 17,
                        color: Colors.grey.shade700,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Welcome Header
                    const Text(
                      "Welcome to SafeNet AI",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Description
                    Text(
                      "An AI-powered platform for managing safety, communication, "
                      "services, and waste in residential living.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: Colors.grey.shade700,
                      ),
                    ),

                    const SizedBox(height: 60),

                    // Get Started Button — glass style
                    Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFB7E9DA), // light mint gradient
                            Color(0xFFA4E0D0),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(40),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const Homepage(),
                            ),
                          );
                        },

                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(40),
                          ),
                        ),
                        child: const Text(
                          "Get Started",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
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
}
