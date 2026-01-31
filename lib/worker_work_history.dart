import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'widget/notification_dropdown.dart';
import 'widget/profile_sidebar.dart';

class WorkerWorkHistoryPage extends StatefulWidget {
  const WorkerWorkHistoryPage({super.key});

  @override
  State<WorkerWorkHistoryPage> createState() => _WorkerWorkHistoryPageState();
}

class _WorkerWorkHistoryPageState extends State<WorkerWorkHistoryPage> {
  bool _isProfileOpen = false;
  String? workerId;

  @override
  void initState() {
    super.initState();
    workerId = FirebaseAuth.instance.currentUser?.uid;
  }

  // ---------------- FULL IMAGE VIEW ----------------
  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          color: Colors.black,
          child: InteractiveViewer(
            child: Center(
              child: Image.network(url),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- DETAILS POPUP ----------------
  void _showJobDetailsPopup(BuildContext context, Map<String, dynamic> job) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
            backgroundColor: Colors.white.withOpacity(0.95),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      job["title"] ?? "",
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  _info("Service ID", job["service_id"]),
                  _info("Resident", job["username"]),
                  const SizedBox(height: 14),

                  const Text(
                    "Description",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(job["description"] ?? ""),

                  const SizedBox(height: 20),

                  if (job["files"] != null && job["files"].isNotEmpty) ...[
                    const Text(
                      "Attachments",
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: List.generate(job["files"].length, (i) {
                        final url = job["files"][i];
                        return GestureDetector(
                          onTap: () => _showFullImage(context, url),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              url,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      }),
                    ),
                  ],

                  const SizedBox(height: 24),

                  if (job["workDescription"] != null &&
                      job["workDescription"].toString().isNotEmpty) ...[
                    const Text(
                      "Worker Notes",
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(job["workDescription"]),
                  ],

                  const SizedBox(height: 24),

                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/bg1_img.png',
              fit: BoxFit.cover,
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // TOP BAR
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _circleButton(
                        Icons.arrow_back,
                        onTap: () => Navigator.pop(context),
                      ),
                      const Text(
                        "Safenet AI",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Row(
                        children: [
                          NotificationDropdown(role: "worker"),
                          const SizedBox(width: 15),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _isProfileOpen = true),
                            child: _circleButton(Icons.person_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection("service_requests")
                        .where("assignedWorker.id", isEqualTo: workerId)
                        .where("status", isEqualTo: "Completed")
                        .orderBy("timestamp", descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data!.docs;

                      if (docs.isEmpty) {
                        return const Center(
                          child: Text("No completed works yet"),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final job =
                              docs[index].data() as Map<String, dynamic>;

                          return GestureDetector(
                            onTap: () =>
                                _showJobDetailsPopup(context, job),
                            child: _jobCard(job),
                          );
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),

          if (_isProfileOpen) ...[
            Positioned.fill(
              child: GestureDetector(
                onTap: () =>
                    setState(() => _isProfileOpen = false),
                child: Container(color: Colors.black45),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              top: 0,
              bottom: 0,
              right: 0,
              width: MediaQuery.of(context).size.width * 0.33,
              child: ProfileSidebar(
                userCollection: "workers",
                onClose: () =>
                    setState(() => _isProfileOpen = false),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _jobCard(Map<String, dynamic> job) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            job["title"] ?? "",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text("ID: ${job["service_id"]}"),
          const SizedBox(height: 6),
          Text(
            (job["timestamp"] as Timestamp)
                .toDate()
                .toString()
                .substring(0, 16),
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: Colors.white70,
          shape: BoxShape.circle,
        ),
        child: Icon(icon),
      ),
    );
  }
}
