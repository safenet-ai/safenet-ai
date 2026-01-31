import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../approval_guard.dart';
import '../../../notice_board.dart';

class SecurityDashboardPage extends StatelessWidget {
  const SecurityDashboardPage({super.key});

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
                        _RoundGlassButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: () {
                            Navigator.maybePop(context);
                          },
                        ),
                        const SizedBox(width: 12),

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

                        _RoundGlassButton(
                          icon: Icons.person_rounded,
                          onTap: () {},
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
                              child: _GlassCard(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFE0F2FF),
                                    Color(0xFFD7E6FF),
                                  ],
                                ),
                                title: 'AI Alerts',
                                mainValue: '04',
                                subtitleLines: const [
                                  'Motion',
                                  'Intrusion',
                                  'Unusual Activity',
                                ],
                                valueLabel: 'Active Alerts',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _GlassCard(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFE7F4FF),
                                    Color(0xFFE5F0FF),
                                  ],
                                ),
                                title: 'Visitor\nManagement',
                                mainValue: '02',
                                subtitleLines: const [
                                  'Pending Visitors',
                                  'Approved Today: 21',
                                ],
                                valueLabel: 'Pending',
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: _GlassCard(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFEAF5FF),
                                    Color(0xFFE3F1FF),
                                  ],
                                ),
                                title: 'Resident\nRequests\nto Security',
                                mainValue: '',
                                subtitleLines: const [
                                  'Suspicious sound\nnear Block C',
                                  'Parking issue\nreported',
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _GlassCard(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFEAF3FF),
                                    Color(0xFFE5F5FF),
                                  ],
                                ),
                                title: 'Patrolling\nUpdates',
                                mainValue: '',
                                subtitleLines: const [
                                  'Last Patrol: 11:30 PM',
                                  'Next: 2:00 AM',
                                ],
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
                                  // TODO: Chat functionality
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
                                        userCollection: "security",
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
                                leadingIcon: Icons.report_gmailerrorred_rounded,
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
