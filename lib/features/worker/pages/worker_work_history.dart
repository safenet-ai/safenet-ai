import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../shared/widgets/notification_dropdown.dart';
import '../../shared/widgets/profile_sidebar.dart';

class WorkerHistoryPage extends StatefulWidget {
  const WorkerHistoryPage({super.key});

  @override
  State<WorkerHistoryPage> createState() => _WorkerHistoryPageState();
}

class _WorkerHistoryPageState extends State<WorkerHistoryPage> {
  bool _isProfileOpen = false;
  String? workerId;

  @override
  void initState() {
    super.initState();
    _loadWorkerId();
  }

  Future<void> _loadWorkerId() async {
    workerId = FirebaseAuth.instance.currentUser?.uid;
    setState(() {});
  }

  // Combine completed service requests and waste pickups
  Stream<List<Map<String, dynamic>>> _getCompletedJobsStream(String workerId) {
    final controller = StreamController<List<Map<String, dynamic>>>();

    List<Map<String, dynamic>> serviceJobs = [];
    List<Map<String, dynamic>> wasteJobs = [];
    List<Map<String, dynamic>> waterJobs = [];

    // Listen to completed service requests
    final serviceSub = FirebaseFirestore.instance
        .collection("service_requests")
        .where("assignedWorker.id", isEqualTo: workerId)
        .where("status", isEqualTo: "Completed")
        .snapshots()
        .listen((snapshot) {
          serviceJobs = snapshot.docs.map((doc) {
            var data = doc.data();
            data["_docId"] = doc.id;
            data["_jobType"] = "service";
            return data;
          }).toList();

          _emitCompletedJobs(controller, serviceJobs, wasteJobs, waterJobs);
        });

    // Listen to completed waste pickups
    final wasteSub = FirebaseFirestore.instance
        .collection("waste_pickups")
        .where("assignedWorkerId", isEqualTo: workerId)
        .where("status", isEqualTo: "Completed")
        .snapshots()
        .listen((snapshot) {
          wasteJobs = snapshot.docs.map((doc) {
            var data = doc.data();
            data["_docId"] = doc.id;
            data["_jobType"] = "waste";
            return data;
          }).toList();

          _emitCompletedJobs(controller, serviceJobs, wasteJobs, waterJobs);
        });

    // Listen to completed water orders
    final waterSub = FirebaseFirestore.instance
        .collection("water_orders")
        .where("assignedWorker.id", isEqualTo: workerId)
        .where("status", isEqualTo: "Delivered")
        .snapshots()
        .listen((snapshot) {
          waterJobs = snapshot.docs.map((doc) {
            var data = doc.data();
            data["_docId"] = doc.id;
            data["_jobType"] = "water";
            return data;
          }).toList();

          _emitCompletedJobs(controller, serviceJobs, wasteJobs, waterJobs);
        });

    controller.onCancel = () {
      serviceSub.cancel();
      wasteSub.cancel();
      waterSub.cancel();
    };

    return controller.stream;
  }

  void _emitCompletedJobs(
    StreamController<List<Map<String, dynamic>>> controller,
    List<Map<String, dynamic>> serviceJobs,
    List<Map<String, dynamic>> wasteJobs,
    List<Map<String, dynamic>> waterJobs,
  ) {
    List<Map<String, dynamic>> allJobs = [...serviceJobs, ...wasteJobs, ...waterJobs];

    // Sort by timestamp (most recent first)
    allJobs.sort((a, b) {
      final aTime = (a["timestamp"] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      final bTime = (b["timestamp"] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime);
    });

    if (!controller.isClosed) {
      controller.add(allJobs);
    }
  }

  // ================= HELPER: SHOW FULL SCREEN IMAGE =================
  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: InteractiveViewer(
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= HISTORY DETAILS POPUP =================
  void _showHistoryPopup(BuildContext context, Map<String, dynamic> job) {
    final isWastePickup = job["_jobType"] == "waste";
    final isWaterOrder = job["_jobType"] == "water";

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Dialog(
            backgroundColor: Colors.white.withOpacity(0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // -------- HEADER --------
                  Center(
                    child: Text(
                      "Job Summary",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      isWastePickup
                          ? "Waste Pickup"
                          : isWaterOrder
                              ? "Water Supply"
                              : (job["title"] ?? "No Title"),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const Divider(height: 40, thickness: 1),

                  // -------- REQUEST DETAILS --------
                  const Text(
                    "Request Details",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 15),

                  if (isWastePickup) ...[
                    _popupInfoRow("Pickup ID", job["pickup_id"] ?? ""),
                    const SizedBox(height: 8),
                    _popupInfoRow("Resident", job["username"] ?? ""),
                    const SizedBox(height: 8),
                    _popupInfoRow("Waste Type", job["wasteType"] ?? ""),
                    const SizedBox(height: 8),
                    _popupInfoRow("Pickup Date", job["date"] ?? ""),
                    const SizedBox(height: 8),
                    _popupInfoRow("Pickup Time", job["time"] ?? ""),
                    const SizedBox(height: 15),

                    if (job["note"] != null && job["note"].isNotEmpty) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(
                            width: 110,
                            child: Text(
                              "Note:",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              job["note"],
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.black87,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ] else if (isWaterOrder) ...[
                    _popupInfoRow("Order ID", job["orderId"] ?? "N/A"),
                    const SizedBox(height: 8),
                    _popupInfoRow("Water Type", job["type"] ?? "N/A"),
                    const SizedBox(height: 8),
                    _popupInfoRow("Quantity", "${job["quantity"] ?? 0}"),
                    const SizedBox(height: 8),
                    _popupInfoRow(
                      "Date",
                      (job["timestamp"] as Timestamp?)
                              ?.toDate()
                              .toString()
                              .substring(0, 10) ??
                          "",
                    ),
                    const SizedBox(height: 15),
                    
                    // Delivered At
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          width: 110,
                          child: Text(
                            "Delivered At:",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _formatCompletedDate(job),
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    _popupInfoRow("Service ID", job["service_id"] ?? ""),
                    const SizedBox(height: 8),
                    _popupInfoRow("Resident", job["username"] ?? ""),
                    const SizedBox(height: 8),
                    _popupInfoRow(
                      "Date",
                      (job["timestamp"] as Timestamp?)
                              ?.toDate()
                              .toString()
                              .substring(0, 10) ??
                          "",
                    ),
                    const SizedBox(height: 15),

                    // Description
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          width: 110,
                          child: Text(
                            "Description:",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            job["description"] ?? "No description.",
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Resident Attachments
                    if (job["files"] != null &&
                        (job["files"] as List).isNotEmpty) ...[
                      const SizedBox(height: 15),
                      const Text(
                        "Resident Attachments:",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildImageGrid(job["files"]),
                    ],
                  ],

                  const Divider(height: 40, thickness: 1),

                  // -------- WORKER COMPLETION DETAILS (Only for service requests) --------
                  if (!isWastePickup && !isWaterOrder) ...[
                    const Text(
                      "Work Completion Report",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Completion Date
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          width: 110,
                          child: Text(
                            "Completed At:",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _formatCompletedDate(job),
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // Completion Notes
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          width: 110,
                          child: Text(
                            "Work Notes:",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            job["workDescription"] ?? "No notes added.",
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                              fontStyle: FontStyle.italic,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Completion Proof Images - check both new and old field names
                    ...(() {
                      final proofImages =
                          job["completionFiles"] ?? job["workFiles"];
                      if (proofImages != null &&
                          (proofImages as List).isNotEmpty) {
                        return [
                          const SizedBox(height: 20),
                          const Text(
                            "Proof of Work:",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildImageGrid(proofImages),
                        ];
                      } else {
                        return [
                          const SizedBox(height: 20),
                          const Text(
                            "No proof images attached.",
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ];
                      }
                    })(),
                  ],

                  const SizedBox(height: 30),

                  // Close Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Close History",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

  // Helper to build image grids
  Widget _buildImageGrid(List<dynamic> urls) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(urls.length, (index) {
        final url = urls[index];
        return GestureDetector(
          onTap: () => _showFullScreenImage(context, url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: Colors.grey[200],
              child: Image.network(
                url,
                width: 70,
                height: 70,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.broken_image,
                  size: 40,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _popupInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            "$label:",
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 15,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  // ================= MAIN BUILD =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // BACKGROUND IMAGE
          Positioned.fill(
            child: Image.asset('assets/bg1_img.png', fit: BoxFit.cover),
          ),

          SafeArea(
            child: Column(
              children: [
                // ================= TOP BAR =================
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
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
                          color: Colors.black87,
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
                            child: _circleButton(Icons.person_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // ================= TITLE =================
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      "Work History",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Color.fromARGB(255, 83, 83, 83),
                      ),
                    ),
                  ),
                ),

                // ================= LIST OF COMPLETED JOBS =================
                Expanded(
                  child: workerId == null
                      ? const Center(child: CircularProgressIndicator())
                      : StreamBuilder<List<Map<String, dynamic>>>(
                          stream: _getCompletedJobsStream(workerId!),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final jobs = snapshot.data!;

                            if (jobs.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.history,
                                      size: 80,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      "No completed jobs yet.",
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              itemCount: jobs.length,
                              itemBuilder: (context, index) {
                                final job = jobs[index];

                                return GestureDetector(
                                  onTap: () => _showHistoryPopup(context, job),
                                  child: _historyCard(job),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          // ================= PROFILE SIDEBAR =================
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
                userCollection: "workers",
                onClose: () => setState(() => _isProfileOpen = false),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ================= CARD WIDGET =================
  Widget _historyCard(Map<String, dynamic> job) {
    final isWastePickup = job["_jobType"] == "waste";
    final isWaterOrder = job["_jobType"] == "water";

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Box
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFBBF3C1).withOpacity(0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isWastePickup ? Icons.delete : isWaterOrder ? Icons.water_drop : Icons.check_circle,
              color: isWaterOrder ? Colors.blue : Colors.green,
            ),
          ),
          const SizedBox(width: 15),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isWastePickup
                      ? "Waste Pickup - ${job["wasteType"] ?? "N/A"}"
                      : isWaterOrder
                          ? "Water Supply - ${job["type"] ?? "N/A"}"
                          : (job["title"] ?? "Service"),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isWaterOrder 
                    ? "ID: ${job["orderId"] ?? "—"}"
                    : isWastePickup
                        ? "ID: ${job["pickup_id"] ?? "—"}"
                        : "ID: ${job["service_id"] ?? "—"}",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Completed: ${_formatCompletedDate(job)}",
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),

          // Arrow
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, {VoidCallback? onTap}) {
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

  String _formatCompletedDate(Map<String, dynamic> job) {
    // Try completedAt first (for new completions), fallback to timestamp (for old completions) or deliveredAt
    final dateField = job["completedAt"] ?? job["deliveredAt"] ?? job["timestamp"];
    if (dateField == null) return "Date unknown";

    try {
      final date = (dateField as Timestamp).toDate();
      final months = [
        "Jan",
        "Feb",
        "Mar",
        "Apr",
        "May",
        "Jun",
        "Jul",
        "Aug",
        "Sep",
        "Oct",
        "Nov",
        "Dec",
      ];
      return "${date.day} ${months[date.month - 1]} ${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return "Date unknown";
    }
  }
}
