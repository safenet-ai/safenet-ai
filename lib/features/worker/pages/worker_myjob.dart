import 'dart:ui';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../shared/widgets/notification_dropdown.dart';
import '../../shared/widgets/profile_sidebar.dart';

class WorkerMyJobsPage extends StatefulWidget {
  const WorkerMyJobsPage({super.key});

  @override
  State<WorkerMyJobsPage> createState() => _WorkerMyJobsPageState();
}

class _WorkerMyJobsPageState extends State<WorkerMyJobsPage> {
  bool _isProfileOpen = false;

  final TextEditingController workDescController = TextEditingController();

  List<PlatformFile> selectedFiles = []; // placeholder for now

  Future<Uint8List?> _compressFile(PlatformFile file) async {
    final isImage = [
      "png",
      "jpg",
      "jpeg",
    ].contains(file.extension?.toLowerCase());

    if (!isImage || file.bytes == null) return file.bytes;

    return await FlutterImageCompress.compressWithList(
      file.bytes!,
      minHeight: 1024,
      minWidth: 1024,
      quality: 70, // 🔥 SAME AS SERVICE REQUEST
    );
  }

  // PICK FILES (max 4)
  Future<void> pickFile(void Function(VoidCallback fn) dialogSetState) async {
    if (selectedFiles.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You can only attach up to 4 files.")),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.any,
    );

    if (result == null) return;

    int availableSlots = 4 - selectedFiles.length;
    final limitedFiles = result.files.take(availableSlots).toList();

    dialogSetState(() {
      selectedFiles.addAll(limitedFiles);
    });
  }

  // REMOVE A FILE
  void removeFile(int index) {
    setState(() {
      selectedFiles.removeAt(index);
    });
  }

  Future<List<String>> uploadWorkFiles(String jobId) async {
    List<String> downloadUrls = [];

    for (var file in selectedFiles) {
      Uint8List? compressedData = await _compressFile(file);
      if (compressedData == null) continue;

      final ref = FirebaseStorage.instance
          .ref()
          .child("work_updates") // 👈 different folder from service request
          .child(
            "${jobId}_${DateTime.now().millisecondsSinceEpoch}_${file.name}",
          );

      UploadTask uploadTask = ref.putData(
        compressedData,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      TaskSnapshot snapshot = await uploadTask;
      String url = await snapshot.ref.getDownloadURL();

      downloadUrls.add(url);
    }

    return downloadUrls;
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Stack(
        children: [
          // The Image
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: InteractiveViewer(
                // Allows pinching to zoom
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
          ),
          // The Close Button
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

  void _showJobDetailsPopup(
    BuildContext context, {
    required Map<String, dynamic> job,
    required String jobId,
  }) {
    final isWastePickup = job["_jobType"] == "waste";

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Dialog(
                backgroundColor: Colors.white.withOpacity(0.90),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // -------- TITLE --------
                      Center(
                        child: Text(
                          isWastePickup
                              ? "Waste Pickup"
                              : job["_jobType"] == "water"
                                  ? "Water Supply"
                                  : (job["title"] ?? "No Title"),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      if (isWastePickup) ...[
                        _popupInfoRow("Pickup ID", job["pickup_id"] ?? ""),
                        const SizedBox(height: 12),
                        _popupInfoRow("Resident", job["username"] ?? ""),
                        const SizedBox(height: 12),
                        _popupInfoRow("Waste Type", job["wasteType"] ?? ""),
                        const SizedBox(height: 12),
                        _popupInfoRow("Pickup Date", job["date"] ?? ""),
                        const SizedBox(height: 12),
                        _popupInfoRow("Pickup Time", job["time"] ?? ""),
                        const SizedBox(height: 12),

                        // Note for waste pickup
                        if (job["note"] != null && job["note"].isNotEmpty) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(
                                width: 100,
                                child: Text(
                                  "Note :",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
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
                      ] else if (job["_jobType"] == "water") ...[
                        _popupInfoRow("Order ID", job["orderId"] ?? "N/A"),
                        const SizedBox(height: 12),
                        _popupInfoRow("Water Type", job["type"] ?? "N/A"),
                        const SizedBox(height: 12),
                        _popupInfoRow("Quantity", "${job["quantity"] ?? 0}"),
                        const SizedBox(height: 12),
                        _popupInfoRow(
                          "Date",
                          job["timestamp"] != null
                              ? (job["timestamp"] as Timestamp)
                                  .toDate()
                                  .toString()
                                  .substring(0, 10)
                              : "N/A",
                        ),
                      ] else ...[
                        _popupInfoRow("Service ID", job["service_id"] ?? ""),
                        const SizedBox(height: 12),
                        _popupInfoRow("Resident", job["username"] ?? ""),
                        const SizedBox(height: 12),

                        // -------- DESCRIPTION (FIXED OVERFLOW) --------
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(
                              width: 100,
                              child: Text(
                                "Description :",
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                job["description"] ??
                                    "No description provided.",
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

                      const SizedBox(height: 20),

                      // -------- ATTACHMENTS (FIXED IMAGE VISIBILITY) --------
                      if (job["files"] != null &&
                          (job["files"] as List).isNotEmpty) ...[
                        const Text(
                          "Attachments",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),

                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: List.generate(job["files"].length, (index) {
                            final url = job["files"][index];
                            return GestureDetector(
                              onTap: () => _showFullScreenImage(context, url),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  url,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                        if (loadingProgress == null)
                                          return child;
                                        return Container(
                                          width: 80,
                                          height: 80,
                                          color: Colors.grey[200],
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        );
                                      },
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        width: 80,
                                        height: 80,
                                        color: Colors.grey[300],
                                        child: const Icon(
                                          Icons.broken_image,
                                          color: Colors.grey,
                                        ),
                                      ),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 20),
                      ],

                      const SizedBox(height: 24),
                      _jobActionButtons(jobId, job, dialogSetState),
                      const SizedBox(height: 14),

                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "Close",
                            style: TextStyle(color: Colors.black54),
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
      },
    );
  }

  // Helper widget for clean popup rows
  Widget _popupInfoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            "$label   :",
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _sendStartNotification(Map<String, dynamic> job) async {
    final now = Timestamp.now();

    // TO RESIDENT
    await FirebaseFirestore.instance.collection("notifications").add({
      "title": "Service Started",
      "message": "Your service request '${job["title"]}' has been started.",
      "toUid": job["userId"],
      "isRead": false,
      "timestamp": now,
    });

    // TO AUTHORITY
    await FirebaseFirestore.instance.collection("notifications").add({
      "title": "Service Started",
      "message": "Worker has started service '${job["title"]}'.",
      "toRole": "authority",
      "isRead": false,
      "timestamp": now,
    });
  }

  Future<void> _rejectJob(
    BuildContext context,
    String jobId,
    Map<String, dynamic> job,
  ) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reject Job"),
        content: const Text(
          "Are you sure you want to reject this job? It will be returned to pending status.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Reject"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Get worker name
      final workerDoc = await FirebaseFirestore.instance
          .collection("workers")
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .get();
      final workerName = workerDoc.data()?["username"] ?? "Worker";

      // Extract service info before update
      final serviceTitle = job["title"] ?? job["category"] ?? "Unknown";
      final serviceId = job["service_id"] ?? "N/A";

      // Update service request to Pending and remove worker
      await FirebaseFirestore.instance
          .collection("service_requests")
          .doc(jobId)
          .update({
            "status": "Pending",
            "assignedWorker": null,
            "isStarted": false,
          });

      // Send notification to authority
      await FirebaseFirestore.instance.collection("notifications").add({
        "title": "Job Rejected",
        "message":
            "Worker $workerName rejected service request '$serviceTitle' (ID: $serviceId).",
        "toRole": "authority",
        "isRead": false,
        "timestamp": Timestamp.now(),
      });

      // Send notification to resident
      await FirebaseFirestore.instance.collection("notifications").add({
        "title": "Service Update",
        "message":
            "Worker $workerName rejected your service request '$serviceTitle' (ID: $serviceId). A new worker will be assigned soon.",
        "toUid": job["userId"],
        "isRead": false,
        "timestamp": Timestamp.now(),
      });

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Job rejected successfully")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error rejecting job: $e")));
      }
    }
  }

  String? workerId;

  Future<void> _loadWorkerId() async {
    workerId = FirebaseAuth.instance.currentUser?.uid;
    setState(() {});
  }

  // Combine service requests and waste pickups into one stream
  Stream<List<Map<String, dynamic>>> _getCombinedJobsStream(String workerId) {
    final controller = StreamController<List<Map<String, dynamic>>>();

    List<Map<String, dynamic>> serviceJobs = [];
    List<Map<String, dynamic>> wasteJobs = [];
    List<Map<String, dynamic>> waterJobs = [];

    // Listen to service requests
    final serviceSub = FirebaseFirestore.instance
        .collection("service_requests")
        .where("assignedWorker.id", isEqualTo: workerId)
        .where("status", whereIn: ["Pending", "Assigned", "Started"])
        .snapshots()
        .listen((snapshot) {
          serviceJobs = snapshot.docs.map((doc) {
            var data = doc.data();
            data["_docId"] = doc.id;
            data["_jobType"] = "service";
            return data;
          }).toList();

          _emitCombinedJobs(controller, serviceJobs, wasteJobs, waterJobs);
        });

    // Listen to waste pickups
    final wasteSub = FirebaseFirestore.instance
        .collection("waste_pickups")
        .where("assignedWorkerId", isEqualTo: workerId)
        .where("status", isEqualTo: "Pending")
        .snapshots()
        .listen((snapshot) {
          wasteJobs = snapshot.docs.map((doc) {
            var data = doc.data();
            data["_docId"] = doc.id;
            data["_jobType"] = "waste";
            return data;
          }).toList();

          _emitCombinedJobs(controller, serviceJobs, wasteJobs, waterJobs);
        });

    // Listen to water orders
    final waterSub = FirebaseFirestore.instance
        .collection("water_orders")
        .where("assignedWorker.id", isEqualTo: workerId)
        .where("status", whereIn: ["Pending", "Out for Delivery"]) // Removed "Delivered" 
        .snapshots()
        .listen((snapshot) {
          waterJobs = snapshot.docs.map((doc) {
            var data = doc.data();
            data["_docId"] = doc.id;
            data["_jobType"] = "water";
            return data;
          }).toList();

          _emitCombinedJobs(controller, serviceJobs, wasteJobs, waterJobs);
        });

    controller.onCancel = () {
      serviceSub.cancel();
      wasteSub.cancel();
      waterSub.cancel();
    };

    return controller.stream;
  }

  void _emitCombinedJobs(
    StreamController<List<Map<String, dynamic>>> controller,
    List<Map<String, dynamic>> serviceJobs,
    List<Map<String, dynamic>> wasteJobs,
    List<Map<String, dynamic>> waterJobs,
  ) {
    List<Map<String, dynamic>> allJobs = [...serviceJobs, ...wasteJobs, ...waterJobs];

    // Sort by timestamp
    allJobs.sort((a, b) {
      final aTime = (a["timestamp"] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      final bTime = (b["timestamp"] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime);
    });

    if (!controller.isClosed) {
      controller.add(allJobs);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadWorkerId();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/bg1_img.png', // your background image
              fit: BoxFit.cover,
            ),
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

                const SizedBox(height: 20),

                // ================= JOB LIST =================
                Expanded(
                  child: workerId == null
                      ? const Center(child: CircularProgressIndicator())
                      : StreamBuilder<List<Map<String, dynamic>>>(
                          stream: _getCombinedJobsStream(workerId!),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final jobs = snapshot.data!;

                            if (jobs.isEmpty) {
                              return const Center(
                                child: Text("No jobs assigned"),
                              );
                            }

                            return ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              itemCount: jobs.length + 1,
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 40),
                                    child: Center(
                                      child: Text(
                                        "My Jobs",
                                        style: TextStyle(
                                          fontSize: 40,
                                          fontWeight: FontWeight.w900,
                                          color: Color.fromARGB(
                                            255,
                                            83,
                                            83,
                                            83,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                final job = jobs[index - 1];

                                return GestureDetector(
                                  onTap: () {
                                    _showJobDetailsPopup(
                                      context,
                                      job: job,
                                      jobId: job["_docId"] ?? "",
                                    );
                                  },
                                  child: _jobCardFromFirestore(job),
                                );
                              },
                            );
                          },
                        ),
                ),

                const SizedBox(height: 10),
                const Text(
                  "SafeNet AI",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 20),
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

  // ================= JOB CARD =================
  Widget _jobCardFromFirestore(Map<String, dynamic> job) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT DETAILS
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isWastePickup) ...[
                      _infoRow("Pickup ID", job["pickup_id"]),
                      _infoRow("Resident", job["username"]),
                      _infoRow("Waste Type", job["wasteType"]),
                      _infoRow("Worker", job["assignedWorker"] ?? "—"),
                      _infoRow("Pickup Date", job["date"] ?? "N/A"),
                      _infoRow("Pickup Time", job["time"] ?? "N/A"),
                    ] else if (isWaterOrder) ...[
                      _infoRow("Order ID", job["orderId"] ?? "N/A"),
                      _infoRow("Type", job["type"] ?? "N/A"),
                      _infoRow("Quantity", "${job["quantity"] ?? 0}"),
                      _infoRow(
                        "Date",
                        job["timestamp"] != null
                            ? (job["timestamp"] as Timestamp)
                                .toDate()
                                .toString()
                                .substring(0, 10)
                            : "N/A",
                      ),
                    ] else ...[
                      _infoRow("Req ID", job["service_id"]),
                      _infoRow("Resident", job["username"]),
                      _infoRow("Service Type", job["title"]),
                      _infoRow("Worker", job["assignedWorker"]?["name"] ?? "—"),
                      _infoRow(
                        "Date",
                        job["timestamp"] != null
                            ? (job["timestamp"] as Timestamp)
                                  .toDate()
                                  .toString()
                                  .substring(0, 10)
                            : "N/A",
                      ),
                    ],
                  ],
                ),
              ),

              // STATUS BADGE
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SizedBox(height: 10),
                  _statusPill(job["status"]),

                  const SizedBox(height: 50),

                  // IN PROGRESS TEXT
                  if (job["isStarted"] == true)
                    Text(
                      "Work in progress",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 0),
        ],
      ),
    );
  }

  // ================= STATUS BADGE =================
  Widget _statusPill(String status) {
    Color color;
    switch (status) {
      case "Assigned":
        color = Color(0xFFBEE7E8);
        break;
      case "Completed":
        color = Color(0xFFBBF3C1);
        break;
      default:
        color = Color(0xFFFFE680);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ================= CIRCLE BUTTON =================
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

  Widget _jobActionButtons(
    String jobId,
    Map<String, dynamic> job,
    void Function(VoidCallback fn) dialogSetState,
  ) {
    final status = job["status"];
    final isWastePickup = job["_jobType"] == "waste";

    // FOR WASTE PICKUPS - Only show complete button
    if (isWastePickup && status == "Pending") {
      return SizedBox(
        width: double.infinity,
        height: 45,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFBBF3C1),
            foregroundColor: Colors.black87,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          onPressed: () async {
            await FirebaseFirestore.instance
                .collection("waste_pickups")
                .doc(jobId)
                .update({
                  "status": "Completed",
                  "completedAt": FieldValue.serverTimestamp(),
                });

            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Waste pickup marked as completed"),
                ),
              );
            }
          },
          child: const Text(
            "Mark as Completed",
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    // FOR WATER ORDERS - Mark as Delivered
    if (job["_jobType"] == "water" && (status == "Pending" || status == "Out for Delivery")) {
      return SizedBox(
        width: double.infinity,
        height: 45,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFBBF3C1),
            foregroundColor: Colors.black87,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          onPressed: () async {
            await FirebaseFirestore.instance
                .collection("water_orders")
                .doc(jobId)
                .update({
                  "status": "Delivered",
                  "deliveredAt": FieldValue.serverTimestamp(),
                });

            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Water order marked as delivered"),
                ),
              );
            }
          },
          child: const Text(
            "Mark as Delivered",
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    // FOR SERVICE REQUESTS - Existing logic
    // START JOB OR REJECT
    if (status == "Assigned" && job["isStarted"] != true) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBEE7E8),
                foregroundColor: Colors.black87,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection("service_requests")
                    .doc(jobId)
                    .update({"isStarted": true});

                await _sendStartNotification(job);
                Navigator.pop(context);
              },
              child: const Text(
                "Start Job",
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 45,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: () async {
                await _rejectJob(context, jobId, job);
              },
              child: const Text(
                "Reject Job",
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      );
    }

    // AFTER STARTED
    if (status == "Assigned" && job["isStarted"] == true) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              "WORK UPDATES",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                //decoration: TextDecoration.underline,
                fontSize: 26,
                color: Colors.black,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // WORK DESCRIPTION
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 6),
              ],
            ),
            child: TextField(
              controller: workDescController,
              minLines: 4,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: "Work description / notes",
                border: InputBorder.none,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ATTACH FILE BUTTON (COMMENTED FUNCTIONALITY)
          GestureDetector(
            onTap: () {
              pickFile(dialogSetState); // 🔒 ENABLE LATER
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 18),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.attach_file, size: 18),
                  SizedBox(width: 10),
                  Text(
                    "Attach Work Files",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 0),

          // FILE PREVIEW
          if (selectedFiles.isNotEmpty)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List.generate(selectedFiles.length, (index) {
                final file = selectedFiles[index];
                final isImage = [
                  "png",
                  "jpg",
                  "jpeg",
                ].contains(file.extension?.toLowerCase());

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 5),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: isImage
                                ? Image.memory(file.bytes!, fit: BoxFit.cover)
                                : const Center(
                                    child: Icon(Icons.description, size: 40),
                                  ),
                          ),
                        ),

                        // ✅ FIXED REMOVE BUTTON
                        Positioned(
                          right: 3,
                          top: 3,
                          child: GestureDetector(
                            onTap: () {
                              dialogSetState(() {
                                selectedFiles.removeAt(index);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // ✅ FILE NAME
                    SizedBox(
                      width: 90,
                      child: Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),

          const SizedBox(height: 30),

          // ACTION BUTTONS
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 45,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBBF3C1),
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: () async {
                      // 🔥 Upload compressed work files
                      List<String> workFiles = await uploadWorkFiles(jobId);

                      await FirebaseFirestore.instance
                          .collection("service_requests")
                          .doc(jobId)
                          .update({
                            "status": "Completed",
                            "workDescription": workDescController.text.trim(),
                            "completionFiles": workFiles,
                            "completedAt": FieldValue.serverTimestamp(),
                          });
                      Navigator.pop(context);

                      selectedFiles.clear();
                      workDescController.clear();
                    },
                    child: const Text("Completed"),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: SizedBox(
                  height: 45,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD6D6),
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection("service_requests")
                          .doc(jobId)
                          .update({
                            "isStarted": false,
                            "workDescription": workDescController.text.trim(),
                            // "workFiles": await uploadWorkFiles(), // 🔒 LATER
                          });
                      Navigator.pop(context);
                    },
                    child: const Text("Uncompleted"),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              "$label:",
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
