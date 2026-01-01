import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
// Uncomment these when Firebase Storage is enabled
// import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'widget/profile_sidebar.dart';

class NewComplaintPage extends StatefulWidget {
  const NewComplaintPage({super.key});

  @override
  State<NewComplaintPage> createState() => _NewComplaintPageState();
}

class _NewComplaintPageState extends State<NewComplaintPage> {

  bool _isProfileOpen = false;

  final TextEditingController titleController = TextEditingController();
  final TextEditingController descController = TextEditingController();

  List<PlatformFile> selectedFiles = [];

  // PICK FILES (max 4)
  Future<void> pickFile() async {
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
  //  FUTURE STORAGE UPLOAD CODE (DISABLED NOW)
  // ===========================================
  /*
  Future<List<String>> uploadFiles() async {
    List<String> downloadUrls = [];

    for (var file in selectedFiles) {
      final ref = FirebaseStorage.instance
          .ref()
          .child("servicerequest")
          .child(DateTime.now().millisecondsSinceEpoch.toString() + "_" + file.name);

      UploadTask uploadTask = ref.putData(file.bytes!);
      TaskSnapshot snapshot = await uploadTask;

      String url = await snapshot.ref.getDownloadURL();
      downloadUrls.add(url);
    }
    return downloadUrls;
  }
  */
  // ===========================================

  // GENERATE COMPLAINT ID
  Future<String> _generateComplaintId() async {
    final counterRef =
        FirebaseFirestore.instance.collection('counters').doc('complaints');

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);

      int lastNumber = snapshot.exists
          ? (snapshot['lastNumber'] ?? 1000)
          : 1000;

      int newNumber = lastNumber + 1;

      transaction.update(counterRef, {'lastNumber': newNumber});

      return "CMP-$newNumber"; //  CMP-1001, CMP-1002, etc.
    });
  }

  //SUBMIT COMPLAINT

  Future<void> submitComplaint() async {
    if (titleController.text.trim().isEmpty ||
        descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All fields are required")),
      );
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User not logged in. Please login again.")),
        );
        return;
      }

      // ✅ 1️⃣ Generate Complaint ID
      String complaintId = await _generateComplaintId();

      // ✅ 2️⃣ Get USERNAME from users collection
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      String username = "Resident";
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null && data['username'] != null) {
          username = data['username'];
        }
      }
      // When Storage is ready → replace this line:
      // List<String> files = await uploadFiles();
      List<String> files = [];

      // ✅ 3️⃣ Save complaint WITH complaint_id + username
      await FirebaseFirestore.instance.collection("complaints").add({
        "complaint_id": complaintId,
        "title": titleController.text.trim(),
        "description": descController.text.trim(),
        "files": files,
        "userId": user.uid,
        "username": username,      // ✅🔥 REAL USERNAME SAVED HERE
        "status": "Pending",
        "timestamp": Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Complaint submitted successfully as $complaintId"),
          duration: const Duration(seconds: 2),
        ),
      );

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // BACKGROUND
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/bg1_img.png"),
                fit: BoxFit.cover,
              ),
            ),
          ),

          Container(color: Colors.white.withOpacity(0.15)),

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
                      _circleButton(Icons.arrow_back,
                          onTap: () => Navigator.pop(context)),
                      const Text(
                        "SafeNet AI",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                      Row(
                        children: [
                          _circleButton(Icons.notifications_none_rounded),
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
                    "New Complaint",
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),

                  const SizedBox(height: 25),

                  // TITLE
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: _fieldDecoration(),
                    child: TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        hintText: "Complaint Title",
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // DESCRIPTION
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
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

                  //  COMPACT ATTACH IMAGE BUTTON (MATCHED WITH SERVICE PAGE)
                  GestureDetector(
                    onTap: pickFile,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
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
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.attach_file, size: 18),
                          SizedBox(width: 8),
                          Text(
                            "Attach Image",
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
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

                        return Stack(
                          children: [
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Colors.black12, blurRadius: 5),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: isImage
                                    ? Image.memory(file.bytes!,
                                        fit: BoxFit.cover)
                                    : const Center(
                                        child:
                                            Icon(Icons.description, size: 40)),
                              ),
                            ),
                            Positioned(
                              right: -8,
                              top: -8,
                              child: GestureDetector(
                                onTap: () => removeFile(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.close,
                                      size: 16, color: Colors.white),
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
                      onPressed: submitComplaint,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff6ea7a0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        "Submit Complaint",
                        style:
                            TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Center(
                    child: Text(
                      "Your complaint will be sent to\nauthority for review.",
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 14, color: Colors.black54),
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
              width: MediaQuery.of(context).size.width * 0.33,
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

  // CIRCLE BUTTON
  Widget _circleButton(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white70,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 8),
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
      boxShadow: const [
        BoxShadow(color: Colors.black26, blurRadius: 8),
      ],
    );
  }
}
