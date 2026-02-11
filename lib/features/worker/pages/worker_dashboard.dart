import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../shared/widgets/profile_sidebar.dart';
import '../../shared/widgets/notification_dropdown.dart';
import '../../../approval_guard.dart';
import './worker_myjob.dart';
import './worker_work_history.dart';
import './worker_chat.dart';
import '../../../notice_board.dart';

class WorkerDashboardPage extends StatefulWidget {
  const WorkerDashboardPage({super.key});

  @override
  State<WorkerDashboardPage> createState() => _WorkerDashboardPageState();
}

class _WorkerDashboardPageState extends State<WorkerDashboardPage> {
  bool _isProfileOpen = false;
  bool _isAvailable = false;
  bool _isLoadingStatus = true;

  @override
  void initState() {
    super.initState();
    _fetchWorkerStatus();
  }

  Future<String> _fetchWorkerName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return "Worker";

    final doc = await FirebaseFirestore.instance
        .collection("workers") // or "users" if workers are inside users
        .doc(uid)
        .get();

    if (doc.exists && doc.data()!.containsKey("username")) {
      return doc["username"];
    }

    return "Worker";
  }

  Future<void> _fetchWorkerStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance.collection("workers").doc(uid).get();
    if (doc.exists && mounted) {
      setState(() {
        _isAvailable = doc.data()?['isAvailable'] ?? false;
        _isLoadingStatus = false;
      });
    }
  }

  Future<void> _toggleStatus(bool value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isAvailable = value);

    try {
      await FirebaseFirestore.instance.collection("workers").doc(uid).update({
        'isAvailable': value,
      });
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? "You are now On Duty" : "You are now Off Duty"),
            backgroundColor: value ? Colors.teal : Colors.grey,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAvailable = !value); // Revert on error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update status: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ApprovalGate(
      collection: "workers",
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,

        // ------------------ BODY ------------------
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset('assets/bg1_img.png', fit: BoxFit.cover),
            ),

            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Container(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 18,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ----------------- TOP APP BAR -----------------
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
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          Row(
                            children: [
                              NotificationDropdown(role: "worker"),
                              const SizedBox(width: 15),
                              GestureDetector(
                                onTap: () {
                                  setState(() => _isProfileOpen = true);
                                },
                                child: _roundIcon(Icons.person),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 50),

                      // ------------------ GREETING ------------------
                      FutureBuilder<String>(
                        future: _fetchWorkerName(),
                        builder: (context, snapshot) {
                          final name = snapshot.data ?? "Worker";

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
                                  const Text(
                                    "👋",
                                    style: TextStyle(fontSize: 26),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Your Smart Worker Assistant",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.blueGrey.withOpacity(0.9),
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 30),

                      // ------------------ STATUS TOGGLE ------------------
                      if (!_isLoadingStatus)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Current Status",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _isAvailable ? "ON DUTY" : "OFF DUTY",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _isAvailable ? Colors.teal : Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              Transform.scale(
                                scale: 1.2,
                                child: Switch(
                                  value: _isAvailable,
                                  onChanged: _toggleStatus,
                                  activeColor: Colors.teal,
                                  activeTrackColor: Colors.teal.shade100,
                                  inactiveThumbColor: Colors.grey.shade400,
                                  inactiveTrackColor: Colors.grey.shade200,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 25),

                      Text(
                        "Here’s your daily overview",
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.grey.shade700,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ------------------ TILES ------------------
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => WorkerMyJobsPage(),
                                  ),
                                );
                              },
                              child: WorkerTile(
                                color: const Color(0xFFCFF6F2),
                                icon: Icons.construction,
                                title: "My Jobs",
                                subtitle: "Manage your assigned tasks.",
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => WorkerHistoryPage(),
                                  ),
                                );
                              },
                              child: WorkerTile(
                                color: const Color(0xFFE7DFFC),
                                icon: Icons.history,
                                title: "Work History",
                                subtitle: "Track completed tasks.",
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => WorkerChatPage(),
                                  ),
                                );
                              },
                              child: WorkerTile(
                                color: const Color(0xFFFCE3F1),
                                icon: Icons.chat_bubble_outline,
                                title: "Chat",
                                subtitle: "Talk with authority instantly.",
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => NoticeBoardPage(
                                      role: "workers",
                                      displayRole: "Worker",
                                      userCollection: "workers",
                                    ),
                                  ),
                                );
                              },
                              child: WorkerTile(
                                color: const Color(0xFFDAF5E8),
                                icon: Icons.campaign_outlined,
                                title: "Notice Board",
                                subtitle: "View announcements.",
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),

            if (_isProfileOpen) ...[
              // Dark blur background
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _isProfileOpen = false),
                  child: Container(color: Colors.black.withOpacity(0.35)),
                ),
              ),

              // Sliding profile panel
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                width: 280,
                child: ProfileSidebar(
                  onClose: () => setState(() => _isProfileOpen = false),
                  userCollection: "workers",
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ------------------ ROUND ICON ------------------
  Widget _roundIcon(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white70,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, size: 22, color: Colors.black87),
      ),
    );
  }
}

// ------------------ TILE WIDGET ------------------
class WorkerTile extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;

  const WorkerTile({
    super.key,
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.95),
            offset: const Offset(-4, -4),
            blurRadius: 10,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            offset: const Offset(5, 5),
            blurRadius: 12,
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon bubble
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.9),
                  offset: const Offset(-3, -3),
                  blurRadius: 7,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  offset: const Offset(3, 3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.teal, size: 24),
          ),

          const SizedBox(height: 14),

          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3A4B),
            ),
          ),

          const SizedBox(height: 6),

          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              height: 1.2,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
