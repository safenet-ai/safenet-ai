import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../approval_guard.dart';
import '../../../notice_board.dart';
import '../../shared/widgets/profile_sidebar.dart';
import '../../shared/widgets/notification_dropdown.dart';
import 'visitor_management.dart';
import 'security_requests.dart';
import 'ai_alerts.dart';
import 'incident_report.dart';
import 'security_chat.dart';

class SecurityDashboardPage extends StatefulWidget {
  const SecurityDashboardPage({super.key});

  @override
  State<SecurityDashboardPage> createState() => _SecurityDashboardPageState();
}

class _SecurityDashboardPageState extends State<SecurityDashboardPage> {
  bool _isProfileOpen = false;

  @override
  Widget build(BuildContext context) {
    return ApprovalGate(
      collection: "workers",
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Background image
            Positioned.fill(
              child: Image.asset('assets/bg1_img.png', fit: BoxFit.cover),
            ),

            // WHOLE PAGE SCROLLS
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top bar
                    Row(
                      children: [
                        // Logo + text
                        Row(
                          children: [
                            Container(
                              height: 28,
                              width: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF24C6DC),
                                    Color(0xFF514A9D),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.shield_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'SafeNet',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.black.withOpacity(0.9),
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),

                        const Spacer(),

                        NotificationDropdown(role: "security"),
                        const SizedBox(width: 12),
                        _RoundGlassButton(
                          icon: Icons.person_rounded,
                          onTap: () {
                            setState(() => _isProfileOpen = true);
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    Text(
                      'Security Dashboard',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                        color: Colors.black.withOpacity(0.9),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // --------------------------
                    // THE ENTIRE CARDS LIST
                    // (No Expanded, now scrolls properly)
                    // --------------------------
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection("ai_alerts")
                                    .where("status", isEqualTo: "active")
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  final count = snapshot.hasData
                                      ? snapshot.data!.docs.length
                                      : 0;
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const AIAlertsPage(),
                                        ),
                                      );
                                    },
                                    child: _GlassCard(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFE0F2FF),
                                          Color(0xFFD7E6FF),
                                        ],
                                      ),
                                      title: 'AI Alerts',
                                      mainValue: count.toString().padLeft(
                                        2,
                                        '0',
                                      ),
                                      subtitleLines: const [
                                        'Motion',
                                        'Intrusion',
                                        'Unusual Activity',
                                      ],
                                      valueLabel: 'Active Alerts',
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection("visitors")
                                    .where("status", isEqualTo: "pending")
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  final pendingCount = snapshot.hasData
                                      ? snapshot.data!.docs.length
                                      : 0;
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const VisitorManagementPage(),
                                        ),
                                      );
                                    },
                                    child: _GlassCard(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFE7F4FF),
                                          Color(0xFFE5F0FF),
                                        ],
                                      ),
                                      title: 'Visitor\nManagement',
                                      mainValue: pendingCount
                                          .toString()
                                          .padLeft(2, '0'),
                                      subtitleLines: const [
                                        'Pending Visitors',
                                        'Check-in & Approval',
                                      ],
                                      valueLabel: 'Pending',
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection("security_requests")
                                    .where("status", isEqualTo: "pending")
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  final pendingCount = snapshot.hasData
                                      ? snapshot.data!.docs.length
                                      : 0;

                                  // Get latest 2 requests for preview
                                  List<String> previewLines = [];
                                  if (snapshot.hasData &&
                                      snapshot.data!.docs.isNotEmpty) {
                                    final docs = snapshot.data!.docs.take(2);
                                    for (var doc in docs) {
                                      final data =
                                          doc.data() as Map<String, dynamic>;
                                      final type =
                                          data["requestType"] ?? "Request";
                                      final location = data["location"] ?? "";
                                      previewLines.add(
                                        "${type.replaceAll('_', ' ')}\n$location",
                                      );
                                    }
                                  }

                                  if (previewLines.isEmpty) {
                                    previewLines = ['No pending\nrequests'];
                                  }

                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const SecurityRequestsPage(),
                                        ),
                                      );
                                    },
                                    child: _GlassCard(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFEAF5FF),
                                          Color(0xFFE3F1FF),
                                        ],
                                      ),
                                      title: 'Resident\nRequests\nto Security',
                                      mainValue: pendingCount > 0
                                          ? pendingCount.toString().padLeft(
                                              2,
                                              '0',
                                            )
                                          : '',
                                      subtitleLines: previewLines,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const SecurityChatPage(),
                                    ),
                                  );
                                },
                                child: _GlassCard(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFE6F2FF),
                                      Color(0xFFEAF1FF),
                                    ],
                                  ),
                                  title: 'Chat with\nAuthority',
                                  mainValue: '',
                                  subtitleLines: const [
                                    'Communicate with\nAuthority Team',
                                  ],
                                  leadingIcon: Icons.chat_bubble_rounded,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => NoticeBoardPage(
                                        role: "security",
                                        displayRole: "Security",
                                        userCollection:
                                            "workers", // ✅ Correct collection
                                      ),
                                    ),
                                  );
                                },
                                child: _GlassCard(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFFE5B4),
                                      Color(0xFFFFEAC2),
                                    ],
                                  ),
                                  title: 'Notice\nBoard',
                                  mainValue: '',
                                  subtitleLines: const [
                                    'View announcements\nfrom Authority',
                                  ],
                                  leadingIcon: Icons.campaign_outlined,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const IncidentReportPage(),
                                    ),
                                  );
                                },
                                child: _GlassCard(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFDE7F2),
                                      Color(0xFFF9E9FF),
                                    ],
                                  ),
                                  title: 'Report\nIncident',
                                  mainValue: '',
                                  subtitleLines: const [
                                    'Report incidents to\nAuthority Team',
                                  ],
                                  leadingIcon:
                                      Icons.report_gmailerrorred_rounded,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(), // Empty placeholder
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        Text(
                          'SafeNet AI — Smart Safety for Smart Living',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black.withOpacity(0.55),
                          ),
                        ),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Profile sidebar
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
                width: 280,
                child: ProfileSidebar(
                  userCollection: "workers", // ✅ Correct collection
                  onClose: () => setState(() => _isProfileOpen = false),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// Rounded Glass Button
// ------------------------------------------------------------
class _RoundGlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundGlassButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.55),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withOpacity(0.8),
                width: 1.2,
              ),
            ),
            child: Icon(icon, size: 18, color: Colors.black.withOpacity(0.75)),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// Glass Card Widget
// ------------------------------------------------------------
class _GlassCard extends StatelessWidget {
  final LinearGradient gradient;
  final String title;
  final String mainValue;
  final String? valueLabel;
  final List<String> subtitleLines;
  final IconData? leadingIcon;

  const _GlassCard({
    required this.gradient,
    required this.title,
    required this.mainValue,
    required this.subtitleLines,
    this.valueLabel,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withOpacity(0.7), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leadingIcon != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    leadingIcon,
                    size: 18,
                    color: Colors.black.withOpacity(0.75),
                  ),
                ),
              if (leadingIcon != null) const SizedBox(height: 8),

              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  color: Colors.black.withOpacity(0.9),
                ),
              ),

              const SizedBox(height: 8),

              if (mainValue.isNotEmpty)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      mainValue,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.black.withOpacity(0.95),
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (valueLabel != null)
                      Text(
                        valueLabel!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black.withOpacity(0.6),
                        ),
                      ),
                  ],
                ),

              const SizedBox(height: 10),

              ...subtitleLines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    line,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.25,
                      color: Colors.black.withOpacity(0.7),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
