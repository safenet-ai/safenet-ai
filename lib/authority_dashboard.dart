import 'package:flutter/material.dart';
import 'authority_chatwaiting.dart';
import 'authority_complaint.dart';
import 'authority_approval.dart';
import 'authority_servicereq.dart';
import 'authority_announcement.dart';
import 'authority_view_announcements.dart';
import 'widget/notification_dropdown.dart';

class AuthorityDashboardPage extends StatelessWidget {
  const AuthorityDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/bg1_img.png', // your background image
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Container(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ----------------- TOP APP BAR -----------------
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              size: 22,
                              color: Colors.black87,
                            ),
                          ),

                          Row(
                            children: const [
                              Icon(
                                Icons.shield_outlined,
                                size: 22,
                                color: Color(0xFF274267),
                              ),
                              SizedBox(width: 6),
                              Text(
                                "SafeNet AI",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF274267),
                                ),
                              ),
                            ],
                          ),

                          NotificationDropdown(role: "authority"),
                        ],
                      ),

                      const SizedBox(height: 50),

                      // ----------------- PAGE TITLE -----------------
                      const Text(
                        "Authority",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const Text(
                        "Dashboard",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),

                      const SizedBox(height: 35),

                      // ----------------- TILES GRID -----------------
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width:
                                MediaQuery.of(context).size.width *
                                0.40, // responsive smaller card
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PendingApprovalPage(),
                                  ),
                                );
                              },
                              child: DashboardTile(
                                color: Color(0xFFDDF4F1),
                                icon: Icons.check_circle_outline,
                                title: "Pending\nApproval\nRequests",
                              ),
                            ),
                          ),

                          const SizedBox(width: 20), // GAP between cards

                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.40,
                            child: GestureDetector(
                              onTap: () {
                                // Navigator.push(context, MaterialPageRoute(builder: (context) => PendingApprovalPage()));
                              },
                              child: DashboardTile(
                                // color: Color(0xFFE9DCF8),
                                color: Color(0xFFCCF1E6),
                                icon: Icons.recycling_outlined,
                                title: "waste manage",
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width:
                                MediaQuery.of(context).size.width *
                                0.40, // responsive smaller card
                            child: GestureDetector(
                              onTap: () {
                                // Navigator.push(context, MaterialPageRoute(builder: (context) => PendingApprovalPage()));
                              },
                              child: DashboardTile(
                                color: Color(0xFFF7D6DE),
                                icon: Icons.report_problem_outlined,
                                title: "Security\nAlerts",
                              ),
                            ),
                          ),

                          const SizedBox(width: 20), // GAP between cards

                          SizedBox(
                            width:
                                MediaQuery.of(context).size.width *
                                0.40, // responsive smaller card
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        AuthorityWaitingListPage(),
                                  ),
                                );
                              },
                              child: DashboardTile(
                                color: Color(0xFFDDE9F8),
                                icon: Icons.chat_bubble_outline,
                                title: "Chat",
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width:
                                MediaQuery.of(context).size.width *
                                0.40, // responsive smaller card
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        AuthorityComplaintsPage(),
                                  ),
                                );
                              },
                              child: DashboardTile(
                                color: Color(0xFFE6EDF7),
                                icon: Icons.shield_outlined,
                                title: "Complaints\nReview",
                              ),
                            ),
                          ),

                          const SizedBox(width: 20), // GAP between cards

                          SizedBox(
                            width:
                                MediaQuery.of(context).size.width *
                                0.40, // responsive smaller card
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        AuthorityServiceManagementPage(),
                                  ),
                                );
                              },
                              child: DashboardTile(
                                color: Color(0xFFDFEFE6),
                                icon: Icons.handyman_outlined,
                                title: "Service\nOversight",
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ----------------- FULL WIDTH BUTTONS -----------------
                      Center(
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width * 0.85,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      AuthorityAnnouncementPage(),
                                ),
                              );
                            },
                            child: const FullWidthButtonTile(
                              //color: Color(0xFFCCF1E6),
                              //text: "Generate Report",
                              color: Color(0xFFE9DCF8),
                              icon: Icons.campaign_outlined,
                              title: "Create Announcement",
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // View Announcements Button
                      Center(
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width * 0.85,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      AuthorityViewAnnouncementsPage(),
                                ),
                              );
                            },
                            child: const FullWidthButtonTile(
                              color: Color(0xFFFFE5B4),
                              icon: Icons.list_alt_outlined,
                              title: "View Announcements",
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------ TILE WIDGETS (unchanged) ------------------

class DashboardTile extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;

  const DashboardTile({
    super.key,
    required this.color,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.9),
            offset: const Offset(-3, -3),
            blurRadius: 8,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            offset: const Offset(6, 6),
            blurRadius: 14,
          ),
        ],
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 30, color: Colors.black54),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    height: 1.2,
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

class FullWidthButtonTile extends StatelessWidget {
  final Color color;
  final IconData icon;
  //final String text;
  final String title;

  const FullWidthButtonTile({
    super.key,
    required this.color,
    //required this.text,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.9),
            offset: const Offset(-3, -3),
            blurRadius: 8,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            offset: const Offset(6, 6),
            blurRadius: 14,
          ),
        ],
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 30, color: Colors.black54),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
