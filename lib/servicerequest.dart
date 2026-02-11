import 'package:flutter/material.dart';
//import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
//import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'features/shared/widgets/profile_sidebar.dart';
import 'features/shared/widgets/notification_dropdown.dart';
import 'services/notification_service.dart';

class NewServiceRequestpage extends StatefulWidget {
  const NewServiceRequestpage({super.key});

  @override
  State<NewServiceRequestpage> createState() => _NewServiceRequestpage();
}

class _NewServiceRequestpage extends State<NewServiceRequestpage> {
  bool _isProfileOpen = false;

  String? selectedCategory;

  final TextEditingController titleController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  final TextEditingController otherCategoryController = TextEditingController();

  List<PlatformFile> selectedFiles = [];

  // NEW: selected worker (null when none chosen)
  Map<String, dynamic>? selectedWorker;

  // --- COMPRESSION HELPER ---
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
      quality: 70, // 70 is the sweet spot for Blaze plan savings
    );
  }

  // PICK FILES (max 4)
  Future<void> pickFile() async {
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

    setState(() {
      selectedFiles.addAll(limitedFiles);
    });
  }

  // REMOVE A FILE
  void removeFile(int index) {
    setState(() {
      selectedFiles.removeAt(index);
    });
  }

  // ===========================================
  //  FUTURE STORAGE UPLOAD CODE (ACTIVATED NOW)
  // ===========================================

  Future<List<String>> uploadFiles() async {
    List<String> downloadUrls = [];

    for (var file in selectedFiles) {
      //compress file before upload
      Uint8List? compressedData = await _compressFile(file);
      if (compressedData == null) continue;

      final ref = FirebaseStorage.instance
          .ref()
          .child("servicerequest")
          .child(
            DateTime.now().millisecondsSinceEpoch.toString() + "_" + file.name,
          );

      // Upload compressed data

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

  // ===========================================

  // ✅ GENERATE SERVICE REQUEST ID (SRVC-1001)(SAME METHOD AS COMPLAINT)

  Future<String> _generateServiceId() async {
    final counterRef = FirebaseFirestore.instance
        .collection('counters')
        .doc('services');

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);

      int lastNumber = snapshot.exists
          ? (snapshot['lastNumber'] ?? 1000)
          : 1000;

      int newNumber = lastNumber + 1;

      transaction.update(counterRef, {'lastNumber': newNumber});

      return "SRVC-$newNumber"; // ✅ SRVC-1001, SRVC-1002, etc.
    });
  }

  // SUBMIT service request (WITHOUT STORAGE FOR NOW)

  Future<void> submitRequest() async {
    if (titleController.text.trim().isEmpty ||
        descController.text.trim().isEmpty ||
        selectedCategory == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("All fields are required")));
      return;
    }

    //Show loading Spinner
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xff6ea7a0)),
      ),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("User not logged in.")));
        return;
      }

      // ✅ 1️⃣ Generate Service ID
      String serviceId = await _generateServiceId();

      // ✅ 2️⃣ Get USERNAME from users collection
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      String username = userDoc.data()?['username'] ?? "Resident";

      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null && data['username'] != null) {
          username = data['username'];
        }
      }

      // When Storage is ready → replace this line:
      List<String> files = await uploadFiles();
      //List<String> files = [];

      // ✅ 3️⃣ Save Service Request with ID + Username
      await FirebaseFirestore.instance.collection("service_requests").add({
        "service_id": serviceId, // ✅ NEW
        "title": titleController.text.trim(),
        "description": descController.text.trim(),
        "category": selectedCategory == "Other"
            ? otherCategoryController.text.trim()
            : selectedCategory,
        "files": files,
        "userId": user.uid,
        "username": username, // ✅ NEW
        "status": "Pending",
        "isStarted": false,
        "timestamp": Timestamp.now(),

        // ✅ Worker info (unchanged)
        "assignedWorker": selectedWorker != null
            ? {
                "id": selectedWorker!['id'],
                "name": selectedWorker!['name'],
                "rating": selectedWorker!['rating'],
                "completed": selectedWorker!['completed'],
                "role": selectedWorker!['role'],
                "avatarColor": (selectedWorker!['avatarColor'] as Color).value,
              }
            : null,
      });

      // Notify authority about new service request
      try {
        final authorities = await FirebaseFirestore.instance
            .collection('authorities')
            .limit(1)
            .get();
        
        if (authorities.docs.isNotEmpty) {
          await NotificationService.sendNotification(
            userId: authorities.docs.first.id,
            userRole: 'authority',
            title: 'New Service Request',
            body: '$username submitted a new service request: ${titleController.text.trim()}',
            type: 'new_service_request',
            additionalData: {'requestId': serviceId},
          );
        }
      } catch (e) {
        print('Error sending notification: $e');
      }

      if (mounted) Navigator.pop(context); // close loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Service Request submitted as $serviceId"),
          duration: const Duration(seconds: 2),
        ),
      );

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // ---------------- Worker Data (placeholders: Option C) ----------------
  Stream<QuerySnapshot> _workersStream() {
    Query query = FirebaseFirestore.instance
        .collection("workers")
        .where("isActive", isEqualTo: true);

    if (selectedCategory != null && selectedCategory != "Other") {
      query = query.where("profession", isEqualTo: selectedCategory);
    }

    return query.snapshots();
  }

  // open bottom sheet to pick worker
  Future<void> _openWorkerPicker() async {
    final chosen = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.35,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Select Worker",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _workersStream(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final docs = snapshot.data!.docs;

                        if (docs.isEmpty) {
                          return const Center(
                            child: Text("No workers available"),
                          );
                        }

                        // SORT: On Duty first
                        docs.sort((a, b) {
                          final aData = a.data() as Map<String, dynamic>;
                          final bData = b.data() as Map<String, dynamic>;
                          final aAvail = aData['isAvailable'] ?? false;
                          final bAvail = bData['isAvailable'] ?? false;
                          if (aAvail == bAvail) return 0;
                          return aAvail ? -1 : 1;
                        });

                        return ListView.separated(
                          controller: controller,
                          itemCount: docs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final data =
                                docs[index].data() as Map<String, dynamic>;

                            return _workerListTile(
                              {
                                "id": docs[index].id,
                                "name": data["username"] ?? "Worker",
                                "role": data["profession"] ?? "Unknown",
                                "rating": (data["rating"] ?? 0).toDouble(),
                                "completed": data["completedWorks"] ?? 0,
                                "avatarColor": Colors.blueGrey,
                                "isAvailable": data['isAvailable'] ?? false, // ✅ Added status
                              },
                              () {
                                Navigator.pop(context, {
                                  "id": docs[index].id,
                                  "name": data["username"],
                                  "role": data["profession"],
                                  "rating": (data["rating"] ?? 0).toDouble(),
                                  "completed": data["completedWorks"] ?? 0,
                                  "avatarColor": Colors.blueGrey,
                                });
                              },
                            );
                          },

                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (chosen != null && mounted) {
      setState(() => selectedWorker = chosen);
    }
  }

  // single worker tile used in bottom sheet
  Widget _workerListTile(Map<String, dynamic> w, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.98),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(4, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // avatar circle
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: (w['avatarColor'] as Color).withOpacity(0.95),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  (w['name'] as String)
                      .split(' ')
                      .map((s) => s.isNotEmpty ? s[0] : '')
                      .take(2)
                      .join(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // name + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    w['name'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        w['role'], // 👈 profession
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          // Status Indicator
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (w['isAvailable'] ?? false) ? Colors.green : Colors.grey,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              (w['isAvailable'] ?? false) ? "On Duty" : "Off Duty",
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.star,
                            size: 14,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 6),
                          Text("${w['rating']}"),
                          const SizedBox(width: 12),
                          Text(
                            "${w['completed']} work completed",
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Icon(Icons.chevron_right, color: Colors.black26),
          ],
        ),
      ),
    );
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TOP BAR
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _circleButton(
                        Icons.arrow_back,
                        onTap: () => Navigator.pop(context),
                      ),

                      const Text(
                        "SafeNet AI",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      Row(
                        children: [
                          NotificationDropdown(role: "user"),

                          const SizedBox(width: 12),

                          GestureDetector(
                            onTap: () {
                              setState(() => _isProfileOpen = true);
                            },
                            child: _circleButton(Icons.person_outline_rounded),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 50),

                  const Text(
                    "New Request",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 25),

                  // TITLE INPUT
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    decoration: _fieldDecoration(),
                    child: TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        hintText: "Request Title",
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // DESCRIPTION INPUT
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: _fieldDecoration(),
                    child: TextField(
                      controller: descController,
                      minLines: 5,
                      maxLines: null,
                      decoration: const InputDecoration(
                        hintText: "Description",
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // CATEGORY
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: _fieldDecoration(),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedCategory,
                        isExpanded: true,
                        hint: const Text("Category"),
                        items: const [
                          DropdownMenuItem(
                            value: "Electrician",
                            child: Text("Electrical"),
                          ),
                          DropdownMenuItem(
                            value: "Plumber",
                            child: Text("Plumbing"),
                          ),
                          DropdownMenuItem(
                            value: "Carpenter",
                            child: Text("Furnishing"),
                          ),
                          DropdownMenuItem(
                            value: "Security",
                            child: Text("Security"),
                          ),
                          DropdownMenuItem(
                            value: "Cleaner",
                            child: Text("Cleaning"),
                          ),

                          DropdownMenuItem(
                            value: "Other",
                            child: Text("Other"),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedCategory = value;
                            selectedWorker = null; //  reset worker
                          });
                        },
                      ),
                    ),
                  ),
                  if (selectedCategory == "Other") ...[
                    const SizedBox(height: 14),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      decoration: _fieldDecoration(),
                      child: TextField(
                        controller: otherCategoryController,
                        decoration: const InputDecoration(
                          hintText: "Enter custom category",
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // ------------------ WORKER FIELD (ADDED) ------------------
                  GestureDetector(
                    onTap: _openWorkerPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: _fieldDecoration(),
                      child: Row(
                        children: [
                          // left: avatar or placeholder
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: selectedWorker != null
                                  ? (selectedWorker!['avatarColor'] as Color)
                                        .withOpacity(0.95)
                                  : Colors.grey.shade300,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                selectedWorker != null
                                    ? (selectedWorker!['name'] as String)
                                          .split(' ')
                                          .map((s) => s.isNotEmpty ? s[0] : '')
                                          .take(2)
                                          .join()
                                    : "W",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // middle: name + subtitle
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedWorker != null
                                      ? selectedWorker!['name']
                                      : "Select Worker",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: selectedWorker != null
                                        ? Colors.black87
                                        : Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  selectedWorker != null
                                      ? "${selectedWorker!['role']} • ${selectedWorker!['completed']} Completed"
                                      : "Choose a worker for this request",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.black.withOpacity(0.55),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // right: rating + chevron
                          if (selectedWorker != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    size: 16,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "${selectedWorker!['rating']}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ),
                            ),

                          const Icon(
                            Icons.chevron_right,
                            color: Colors.black26,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ATTACH FILE BUTTON (small pill button – design matched)
                  GestureDetector(
                    onTap: pickFile,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12.withOpacity(0.10),
                            blurRadius: 10,
                            offset: const Offset(2, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize:
                            MainAxisSize.min, // <<< THIS makes it compact
                        children: const [
                          Icon(
                            Icons.attach_file,
                            size: 18,
                            color: Colors.black87,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Attach Image",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
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
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 5,
                                      ),
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
                                            child: Icon(
                                              Icons.description,
                                              size: 40,
                                            ),
                                          ),
                                  ),
                                ),

                                // ✅ FIXED REMOVE BUTTON
                                Positioned(
                                  right: 4,
                                  top: 4,
                                  child: GestureDetector(
                                    onTap: () => removeFile(index),
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

                  // SUBMIT BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: submitRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff6ea7a0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        "Submit Request",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Center(
                    child: Text(
                      "Your request will be sent to\nauthority for review.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
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

            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
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
    );
  }

  // CIRCLE BUTTON UI
  Widget _circleButton(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white70,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, size: 22),
      ),
    );
  }

  // FIELD DECORATION
  BoxDecoration _fieldDecoration() {
    return BoxDecoration(
      color: Colors.white.withOpacity(0.9),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.10),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }
}
