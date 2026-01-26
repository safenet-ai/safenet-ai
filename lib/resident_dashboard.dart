import 'package:flutter/material.dart';
import 'resident_complaint.dart';
import 'resident_service.dart';
import 'resident_waste.dart';
import 'resident_chat.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'widget/profile_sidebar.dart';
import 'approval_guard.dart';
import 'widget/notification_dropdown.dart';


class ResidentDashboardPage extends StatefulWidget {
  const ResidentDashboardPage({super.key});

  @override
  State<ResidentDashboardPage> createState() => _ResidentDashboardPageState();
}

class _ResidentDashboardPageState extends State<ResidentDashboardPage> {

  bool _isProfileOpen = false;


  Future<String> _fetchResidentName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) return "Resident";

    final doc = await FirebaseFirestore.instance
        .collection("users") // change to "residents" if needed
        .doc(uid)
        .get();

    if (doc.exists && doc.data()!.containsKey("username")) {
      return doc["username"]; // must match your Firestore field
    }

    return "Resident";
  }


  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    final cardSize = (width - 28 * 2 - 80) / 2;

    return ApprovalGate(
      collection: "users",
      child: Scaffold(

        extendBodyBehindAppBar: true,
        
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/bg1_img.png',
                fit: BoxFit.cover,
              ),
            ),

            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const SizedBox(height: 6),

                    Row(
                      children: [
                        Image.asset('assets/logo.png', height: 50),

                        Expanded(
                          child: Center(
                            child: Text(
                              "SafeNet AI",
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: Colors.blueGrey,
                                shadows: [
                                  Shadow(
                                    color: Colors.white70,
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),

                        Row(
                          children: [
                            NotificationDropdown(role: "user"),

                            const SizedBox(width: 15),

                            GestureDetector(
                              onTap: () {
                                setState(() => _isProfileOpen = true);
                              },
                              child: _circleIcon(Icons.person),
                            ),
                          ],
                        ),

                      ],
                    ),

                    const SizedBox(height: 50),

                    FutureBuilder<String>(
                      future: _fetchResidentName(),
                      builder: (context, snapshot) {
                        final name = snapshot.data ?? "Resident";
                        return Column(
                          children: [
                            Text(
                              "Welcome,",
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: Colors.blueGrey.withOpacity(0.95),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.blueGrey.withOpacity(0.98),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text("👋", style: TextStyle(fontSize: 28)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Your Smart Residence Assistant",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.blueGrey.withOpacity(0.98),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 32),

                    // ---------------- GRID 2×2 ----------------
                    Wrap(
                      spacing: 22,
                      runSpacing: 22,
                      children: [
                        InkWell(
                          onTap: () {
                            // TODO: Navigate to My Complaints page
                            Navigator.push(context, MaterialPageRoute(builder: (_) => MyComplaintsPage()));
                          },
                          child: _dashboardCard(
                            size: cardSize,
                            icon: Icons.description_outlined,
                            label: "My\nComplaints",
                            color: const Color(0xFFDCEBFF),
                          ),
                        ),

                        InkWell(
                          onTap: () {
                            // TODO: Navigate to Service Requests page
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceRequestpage()));
                          },
                          child: _dashboardCard(
                            size: cardSize,
                            icon: Icons.build_outlined,
                            label: "Service\nRequests",
                            color: const Color(0xFFF7DDE2),
                          ),
                        ),

                        InkWell(
                          onTap: () {
                            // TODO: Navigate to Waste Pickup page
                            Navigator.push(context, MaterialPageRoute(builder: (_) => WastePickupPage()));
                          },
                          child: _dashboardCard(
                            size: cardSize,
                            icon: Icons.delete_outline,
                            label: "Waste\nPickup",
                            color: const Color(0xFFD7F5E8),
                          ),
                        ),

                        InkWell(
                          onTap: () {
                            // TODO: Navigate to AI Alerts page
                          },
                          child: _dashboardCard(
                            size: cardSize,
                            icon: Icons.shield_moon_outlined,
                            label: "AI\nAlerts",
                            color: const Color(0xFFD9F4F6),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 26),

                    InkWell(
                      onTap: () {
                        // TODO: Navigate to Chat / Notice Board page
                        Navigator.push(context, MaterialPageRoute(builder: (_) => SupportChatPage()));
                      },
                      child: _fullCard(
                        icon: Icons.chat_bubble_outline,
                        label: "Chat / Notice\nBoard",
                        color: const Color(0xFFEFE4F9),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            if (_isProfileOpen) ...[
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _isProfileOpen = false),
                  child: Container(color: Colors.black.withOpacity(0.35)),
                ),
              ),

              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                top: 0,
                bottom: 0,
                right: 0,
                width: MediaQuery.of(context).size.width * 0.33,
                child: ProfileSidebar(
                  userCollection: "users",
                  onClose: () => setState(() => _isProfileOpen = false),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dashboardCard({
    required double size,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            offset: const Offset(6, 6),
            blurRadius: 14,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.05),
            offset: const Offset(-6, -6),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 42, color: Colors.black54),
          const SizedBox(height: 14),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fullCard({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final width = MediaQuery.of(context).size.width;
    return Container(
      width: width - 109,
      height: 100,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            offset: const Offset(6, 6),
            blurRadius: 14,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.12),
            offset: const Offset(-6, -6),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 42, color: Colors.black54),
            const SizedBox(width: 16),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
Widget _circleIcon(IconData icon) {
  return Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.white70, // ✅ PURE WHITE BACKGROUND
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: Colors.black12, // ✅ soft shadow
          blurRadius: 8,
          offset: const Offset(2, 2),
        ),
      ],
    ),
    child: Icon(icon, color: Colors.black87, size: 22),
  );
}
