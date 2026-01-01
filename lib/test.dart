import 'package:flutter/material.dart';

class WorkerDashboardPage extends StatelessWidget {
  final String workerName;

  const WorkerDashboardPage({super.key, this.workerName = "Worker"});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ------------------ CUSTOM APP BAR ------------------
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(75),
        child: AppBar(
          backgroundColor: const Color(0xFFEAF2F8),
          elevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 0,

          title: Row(
            children: [
              const SizedBox(width: 12),

              // 🔹 Logo
              Image.asset(
                "assets/logo.png",
                height: 32,
              ),

              const SizedBox(width: 12),

              // 🔹 SafeNet AI text
              const Text(
                "SafeNet AI",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2F3C4E),
                ),
              ),
            ],
          ),

          // 🔹 Notification + Profile buttons
          actions: [
            _roundIcon(Icons.notifications_none),
            const SizedBox(width: 12),
            _roundIcon(Icons.person_outline),
            const SizedBox(width: 16),
          ],
        ),
      ),

      // ------------------ BODY ------------------
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFEAF2F8),
              Color(0xFFF3F5F9),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),

        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ------------------ GREETING ------------------
                Text(
                  "Hello, $workerName 👋",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2C3A4B),
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  "Worker Dashboard",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3E4A59),
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  "Here’s your daily overview",
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade700,
                  ),
                ),

                const SizedBox(height: 28),

                // ------------------ TILES ------------------
                Row(
                  children: const [
                    Expanded(
                      child: WorkerTile(
                        color: Color(0xFFCFF6F2),
                        icon: Icons.construction,
                        title: "My Jobs",
                        subtitle: "Manage your assigned tasks.",
                      ),
                    ),
                    SizedBox(width: 18),
                    Expanded(
                      child: WorkerTile(
                        color: Color(0xFFE7DFFC),
                        icon: Icons.notifications_active_outlined,
                        title: "New Requests",
                        subtitle: "Incoming requests to approve.",
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Row(
                  children: const [
                    Expanded(
                      child: WorkerTile(
                        color: Color(0xFFFCE3F1),
                        icon: Icons.chat_bubble_outline,
                        title: "Chat",
                        subtitle: "Talk with authority instantly.",
                      ),
                    ),
                    SizedBox(width: 18),
                    Expanded(
                      child: WorkerTile(
                        color: Color(0xFFDAF5E8),
                        icon: Icons.history,
                        title: "Work History",
                        subtitle: "Track completed tasks.",
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
    );
  }

  // ------------------ ROUND ICON ------------------
  Widget _roundIcon(IconData icon) {
    return Container(
      height: 42,
      width: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.9),
            offset: const Offset(-3, -3),
            blurRadius: 8,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            offset: const Offset(4, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Icon(icon, color: Colors.black54, size: 22),
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
