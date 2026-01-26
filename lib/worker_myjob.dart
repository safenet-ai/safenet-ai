import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'widget/notification_dropdown.dart';
import 'widget/profile_sidebar.dart';

class WorkerMyJobsPage extends StatefulWidget {
  const WorkerMyJobsPage({super.key});

  @override
  State<WorkerMyJobsPage> createState() => _WorkerMyJobsPageState();

}

class _WorkerMyJobsPageState extends State<WorkerMyJobsPage> {
  bool _isProfileOpen = false;
  
  final TextEditingController workDescController = TextEditingController();
  List<PlatformFile> selectedFiles = []; // placeholder for now

  // PICK FILES (max 4)
  Future<void> pickFile(void Function(VoidCallback fn) dialogSetState) async {
    if (selectedFiles.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You can only attach up to 4 files."),
        ),
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

  /*
  Future<List<String>> uploadWorkFiles() async {
    List<String> urls = [];

    for (var file in selectedFiles) {
      final ref = FirebaseStorage.instance
          .ref()
          .child("work_uploads")
          .child("${DateTime.now().millisecondsSinceEpoch}_${file.name}");

      UploadTask task = ref.putData(file.bytes);
      TaskSnapshot snap = await task;
      urls.add(await snap.ref.getDownloadURL());
    }

    return urls;
  }
  */



  void _showJobDetailsPopup(
    BuildContext context, {
    required Map<String, dynamic> job,
    required String jobId,
  }) {
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
                      Text(
                        job["title"] ?? "",
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),

                      const SizedBox(height: 6),
                      Text(
                        "Service ID: ${job["service_id"]}",
                        style: const TextStyle(color: Colors.black54),
                      ),

                      const SizedBox(height: 14),

                      // -------- USER INFO --------
                      Text(
                        "Resident",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.blueGrey.shade700,
                        ),
                      ),
                      Text(job["username"] ?? ""),
                      const SizedBox(height: 10),

                      // -------- DESCRIPTION --------
                      const Text(
                        "Description",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(job["description"] ?? ""),

                      const SizedBox(height: 16),

                      // -------- FILES (IMAGES / VIDEOS) --------
                      if (job["files"] != null && job["files"].isNotEmpty) ...[
                        const Text(
                          "Attachments",
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: List.generate(
                            job["files"].length,
                            (index) {
                              final url = job["files"][index];
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  url,
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                ),
                              );
                            },
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // -------- ACTION BUTTONS --------
                      _jobActionButtons(jobId, job, dialogSetState),

                      const SizedBox(height: 10),

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
    );
  }

  Future<void> _sendStartNotification(Map<String, dynamic> job) async {
    final now = Timestamp.now();

    // TO RESIDENT
    await FirebaseFirestore.instance.collection("notifications").add({
      "title": "Service Started",
      "message":
          "Your service request '${job["title"]}' has been started.",
      "toUid": job["userId"],
      "target": "user",
      "isRead": false,
      "timestamp": now,
    });

    // TO AUTHORITY
    await FirebaseFirestore.instance.collection("notifications").add({
      "title": "Service Started",
      "message": "Worker has started service '${job["title"]}'.",
      //"target": "authority",
      "torole": "authority", // 👈 REQUIRED
      "isRead": false,
      "timestamp": now,
    });
  }


  String? workerId;

  Future<void> _loadWorkerId() async {
    workerId = FirebaseAuth.instance.currentUser?.uid;
    setState(() {});
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                      : StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                          .collection("service_requests")
                          .where("assignedWorker.id", isEqualTo: workerId)
                          .where("status", whereIn: ["Pending", "Assigned", "Started"])
                          .orderBy("timestamp", descending: true)
                          .snapshots(),

                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data!.docs;

                      if (docs.isEmpty) {
                        return const Center(child: Text("No jobs assigned"));
                      }

                      return ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: docs.length + 1,
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
                                    color: Color.fromARGB(255, 83, 83, 83),
                                  ),
                                ),
                              ),
                            );
                          }

                          final job =
                              docs[index - 1].data() as Map<String, dynamic>;
                          final docId = docs[index - 1].id;

                          return GestureDetector(
                            onTap: () {
                              _showJobDetailsPopup(
                                context,
                                job: job,
                                jobId: docId,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
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
                const SizedBox(height: 8),
                Text(
                  (job["timestamp"] as Timestamp)
                      .toDate()
                      .toString()
                      .substring(0, 16),
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("ID: ${job["service_id"]}"),
              const SizedBox(height: 10),
              _statusBadge(job["status"]),

              const SizedBox(height: 10),

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
    );
  }

  // ================= STATUS BADGE =================
  Widget _statusBadge(String status) {
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

  Widget _jobActionButtons(String jobId, Map<String, dynamic> job, 
  void Function(VoidCallback fn) dialogSetState,) {
    final status = job["status"];

    // START JOB
    if (status == "Assigned" && job["isStarted"] != true) {
      return SizedBox(
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
      );
    }

    // AFTER STARTED
    if (status == "Assigned" && job["isStarted"] == true) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: "Work description / notes",
                border: InputBorder.none,
              ),
            ),
          ),

          // ATTACH FILE BUTTON (COMMENTED FUNCTIONALITY)
          GestureDetector(
            onTap: () {
               pickFile(dialogSetState); // 🔒 ENABLE LATER
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 18),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  SizedBox(width: 8),
                  Text(
                    "Attach Work Files",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // FILE PREVIEW
          if (selectedFiles.isNotEmpty)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List.generate(selectedFiles.length, (index) {
                final file = selectedFiles[index];
                final isImage = ["png", "jpg", "jpeg"]
                    .contains(file.extension?.toLowerCase());

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
                                ? Image.memory(
                                    file.bytes!,
                                    fit: BoxFit.cover,
                                  )
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
                      await FirebaseFirestore.instance
                          .collection("service_requests")
                          .doc(jobId)
                          .update({
                        "status": "Completed",
                        "workDescription": workDescController.text.trim(),
                        // "workFiles": await uploadWorkFiles(), // 🔒 LATER
                      });
                      Navigator.pop(context);
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
}


