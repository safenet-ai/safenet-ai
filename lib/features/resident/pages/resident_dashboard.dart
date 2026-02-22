import 'package:flutter/material.dart';
import './resident_complaint.dart';
import './resident_service.dart';
import './resident_waste.dart';
import './water_supply.dart';
import './resident_ai_alerts.dart';
import './resident_chat.dart';
import './resident_security_requests_list.dart';
import '../../../notice_board.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../shared/widgets/profile_sidebar.dart';
import '../../../approval_guard.dart';
import '../../shared/widgets/notification_dropdown.dart';

import 'package:flutter/services.dart'; // Added For HapticFeedback
import '../../../services/notification_service.dart'; // Added Import
import '../../../core/channels/panic_channel.dart';
import '../../../utils/oem_autostart_utils.dart'; // OEM Background Fix

class ResidentDashboardPage extends StatefulWidget {
  const ResidentDashboardPage({super.key});

  @override
  State<ResidentDashboardPage> createState() => _ResidentDashboardPageState();
}

class _ResidentDashboardPageState extends State<ResidentDashboardPage> {
  bool _isProfileOpen = false;
  bool _isPanicLoading = false;

  @override
  void initState() {
    super.initState();
    // 🔔 Force token refresh and listener start
    _refreshNotifications();
  }

  Future<void> _refreshNotifications() async {
    // Check and prompt for OEM Background Execution permissions
    if (mounted) {
      await OemAutostartUtils.showAutostartDialogIfNeeded(context);
    }

    await NotificationService.saveFCMToken();
    NotificationService.startFirestoreListener();

    // 1. Attach the Dart listener so it catches the Native broadcast
    PanicChannel.init(_triggerPanic);

    // 2. Start/prompt the native Android background panic service
    try {
      await PanicChannel.startPanicService();
      print("Panic Alert Service Started Successfully");
    } catch (e) {
      print("Failed to start Panic Alert Service: $e");
    }

    // --- NEW: Sync Context to Native Android ---
    await _syncContextToNative();
  }

  Future<void> _syncContextToNative() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        String flatNum = "Unknown";
        String buildingNum = "Unknown";
        String blockName = "Unknown"; // ADDED BLOCK NAME
        String residentName = "Unknown";
        String phone = "Unknown";
        final doc = await FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;

          if (data.containsKey("flatNumber")) {
            flatNum = data["flatNumber"]?.toString() ?? "Unknown";
          } else if (data.containsKey("flatNo")) {
            flatNum = data["flatNo"]?.toString() ?? "Unknown";
          }
          if (data.containsKey("buildingNumber")) {
            buildingNum = data["buildingNumber"]?.toString() ?? "Unknown";
          } else if (data.containsKey("buildingNo")) {
            buildingNum = data["buildingNo"]?.toString() ?? "Unknown";
          }

          if (data.containsKey("block")) {
            blockName = data["block"]?.toString() ?? "Unknown";
          }
          if (data.containsKey("username"))
            residentName = data["username"]?.toString() ?? "Unknown";
          if (data.containsKey("phone"))
            phone = data["phone"]?.toString() ?? "Unknown";
        }
        await PanicChannel.setPanicContext(
          uid,
          flatNum,
          buildingNum,
          blockName, // ADDED BLOCK NAME
          residentName,
          phone,
        );
        print(
          "Synced UID, Flat, Building, Block, Name, Phone to Native Android.",
        );
      }
    } catch (e) {
      print("Error syncing context to native: $e");
    }
  }

  void _triggerManualPanic() {
    _showPanicCountdown();
  }

  void _triggerPanic() {
    print("🚨 FLUTTER RECEIVED PANIC INTENT FROM NATIVE 🚨");
    _showPanicCountdown();
  }

  void _showPanicCountdown() {
    if (!mounted || _isPanicLoading) return;

    // Set flag so we don't open multiple countdowns
    setState(() => _isPanicLoading = true);
    HapticFeedback.vibrate();

    int secondsLeft = 10;
    Timer? countdownTimer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Initialize timer only once
            countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (
              timer,
            ) {
              if (secondsLeft > 1) {
                setDialogState(() => secondsLeft--);
              } else {
                // Time's up! Send the alert.
                timer.cancel();
                Navigator.of(dialogContext).pop(true);
              }
            });

            return WillPopScope(
              onWillPop: () async => false, // Prevent back button
              child: AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Column(
                  children: const [
                    Icon(Icons.warning_rounded, color: Colors.red, size: 64),
                    SizedBox(height: 16),
                    Text(
                      "EMERGENCY",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Panic Alert will be sent in:",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "$secondsLeft",
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "seconds",
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  ],
                ),
                actions: [
                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: () {
                        countdownTimer?.cancel();
                        Navigator.of(dialogContext).pop(false);
                      },
                      child: const Text(
                        "Cancel Alert",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    ).then((executeAlert) async {
      countdownTimer?.cancel();
      if (executeAlert == true) {
        await _executePanicAlert();
      } else {
        if (mounted) setState(() => _isPanicLoading = false);
      }
    });
  }

  Future<void> _executePanicAlert() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          "🚨 Requesting Help...",
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Row(
          children: const [
            CircularProgressIndicator(color: Colors.red),
            SizedBox(width: 20),
            Expanded(child: Text("Contacting security team.")),
          ],
        ),
      ),
    );

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      String flatNum = "Unknown";
      String buildingNum = "Unknown";
      String blockName = "Unknown";
      String residentName = "Unknown";
      String phone = "Unknown";
      if (uid != null) {
        final doc = await FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          if (data.containsKey("flatNumber")) {
            flatNum = data["flatNumber"]?.toString() ?? "Unknown";
          } else if (data.containsKey("flatNo")) {
            flatNum = data["flatNo"]?.toString() ?? "Unknown";
          }
          if (data.containsKey("buildingNumber")) {
            buildingNum = data["buildingNumber"]?.toString() ?? "Unknown";
          } else if (data.containsKey("buildingNo")) {
            buildingNum = data["buildingNo"]?.toString() ?? "Unknown";
          }
          if (data.containsKey("block")) {
            blockName = data["block"]?.toString() ?? "Unknown";
          }
          if (data.containsKey("username")) {
            residentName = data["username"]?.toString() ?? "Unknown";
          }
          if (data.containsKey("phone")) {
            phone = data["phone"]?.toString() ?? "Unknown";
          }
        }
      }

      await FirebaseFirestore.instance.collection("security_requests").add({
        "requestType": "panic_alert",
        "residentId": uid,
        "flatNumber": flatNum,
        "flatNo": flatNum,
        "buildingNumber": buildingNum,
        "block": blockName,
        "residentName": residentName,
        "phone": phone,
        "status": "pending",
        "priority": "urgent",
        "timestamp": FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        HapticFeedback.heavyImpact(); // Double vibration for success
        HapticFeedback.heavyImpact();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.red.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Column(
              children: [
                Icon(Icons.check_circle, color: Colors.red, size: 60),
                SizedBox(height: 10),
                Text(
                  "Alert Sent!",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: const Text(
              "Security has been notified. Please stay safe, help is on the way.",
              textAlign: TextAlign.center,
            ),
            actions: [
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "OK",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "❌ Failed. Try Again: $e",
              style: const TextStyle(fontSize: 16),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPanicLoading = false);
    }
  }

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
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 20.0, right: 10.0),
          child: SizedBox(
            height: 75,
            width: 75,
            child: FloatingActionButton(
              onPressed: _isPanicLoading ? null : _triggerManualPanic,
              backgroundColor: Colors.redAccent,
              elevation: 10,
              shape: const CircleBorder(),
              child: _isPanicLoading
                  ? const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                        SizedBox(height: 2),
                        Text(
                          "SOS",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
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
                                    ),
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
                                child: Container(
                                  height: 40,
                                  width: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                  child: const Icon(Icons.person, size: 20),
                                ),
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
                                  const Text(
                                    "👋",
                                    style: TextStyle(fontSize: 28),
                                  ),
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

                      // ---------------- GRID 3×2 ----------------
                      Wrap(
                        spacing: 22,
                        runSpacing: 22,
                        children: [
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MyComplaintsPage(),
                                ),
                              );
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
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ServiceRequestpage(),
                                ),
                              );
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
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => WastePickupPage(),
                                ),
                              );
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
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const WaterSupplyPage(),
                                ),
                              );
                            },
                            child: _dashboardCard(
                              size: cardSize,
                              icon: Icons.water_drop_outlined,
                              label: "Water\nSupply",
                              color: const Color(0xFFB9EFE0),
                            ),
                          ),

                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const ResidentSecurityRequestsListPage(),
                                ),
                              );
                            },
                            child: _dashboardCard(
                              size: cardSize,
                              icon: Icons.security_outlined,
                              label: "Security\nRequests",
                              color: const Color(0xFFFFE6E6),
                            ),
                          ),

                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SupportChatPage(),
                                ),
                              );
                            },
                            child: _dashboardCard(
                              size: cardSize,
                              icon: Icons.chat_bubble_outline,
                              label: "Chat\nSupport",
                              color: const Color(0xFFEFE4F9),
                            ),
                          ),

                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => NoticeBoardPage(
                                    role: "users",
                                    displayRole: "Resident",
                                    userCollection: "users",
                                  ),
                                ),
                              );
                            },
                            child: _dashboardCard(
                              size: cardSize,
                              icon: Icons.campaign_outlined,
                              label: "Notice\nBoard",
                              color: const Color(0xFFFFE5B4),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 26),

                      // AI Alerts (kept separate as it may need special styling)
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ResidentAIAlertsPage(),
                            ),
                          );
                        },
                        child: Container(
                          height: cardSize * 0.85,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD9F4F6),
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.shield_moon_outlined,
                                size: 42,
                                color: Colors.black54,
                              ),
                              const SizedBox(width: 14),
                              Text(
                                "AI Security Alerts",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
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

              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                width: 280,
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
