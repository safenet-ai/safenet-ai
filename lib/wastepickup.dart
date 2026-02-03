import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
// Uncomment these when Firebase Storage is enabled
// import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'features/shared/widgets/profile_sidebar.dart';
import 'features/shared/widgets/notification_dropdown.dart';

class NewWastePickupRequestPage extends StatefulWidget {
  const NewWastePickupRequestPage({super.key});

  @override
  State<NewWastePickupRequestPage> createState() =>
      _NewWastePickupRequestPageState();
}

class _NewWastePickupRequestPageState extends State<NewWastePickupRequestPage> {
  bool _isProfileOpen = false;

  String? selectedWasteType;
  final TextEditingController dateController = TextEditingController();
  final TextEditingController timeController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  List<PlatformFile> selectedFiles = [];

  // PICK FILE
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

  // ✅ GENERATE PICKUP ID (PICK-1001)
  Future<String> _generatePickupId() async {
    final counterRef = FirebaseFirestore.instance
        .collection('counters')
        .doc('wastepickups');

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);

      int lastNumber = snapshot.exists
          ? (snapshot['lastNumber'] ?? 1000)
          : 1000;

      int newNumber = lastNumber + 1;

      transaction.set(counterRef, {'lastNumber': newNumber});

      return "PICK-$newNumber"; // ✅ PICK-1001, PICK-1002 ...
    });
  }

  // =============== SUBMIT WASTE PICKUP ===============
  Future<void> submitRequest() async {
    if (selectedWasteType == null ||
        dateController.text.trim().isEmpty ||
        timeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All required fields must be filled")),
      );
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // ✅ 1. Generate Pickup ID
      String pickupId = await _generatePickupId();

      // ✅ 2. Fetch Username
      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      String username = "Resident";
      if (userDoc.exists && userDoc.data()?['username'] != null) {
        username = userDoc.data()!['username'];
      }

      // When Storage is ready → replace this line:
      // List<String> files = await uploadFiles();
      List<String> files = [];

      // ✅ 3. Save to Firestore with ID + Username
      await FirebaseFirestore.instance.collection("waste_pickups").add({
        "pickup_id": pickupId, // ✅ NEW
        "username": username, // ✅ NEW
        "wasteType": selectedWasteType,
        "date": dateController.text,
        "time": timeController.text,
        "note": noteController.text.trim(),
        "files": files,
        "userId": user.uid,
        "status": "Scheduled",
        "timestamp": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Waste pickup submitted as $pickupId"),
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

  // DATE PICKER
  Future<void> pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        dateController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  // TIME PICKER
  Future<void> pickTime() async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      final formattedTime = picked.format(context);
      setState(() {
        timeController.text = formattedTime;
      });
    }
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

                          const SizedBox(width: 15),
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
                    "New Waste Pickup Request",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 25),

                  // WASTE TYPE
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: _fieldDecoration(),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedWasteType,
                        isExpanded: true,
                        hint: const Text("Select the waste type"),
                        items: const [
                          DropdownMenuItem(
                            value: "Regular",
                            child: Text("Regular"),
                          ),
                          DropdownMenuItem(
                            value: "Recyclable",
                            child: Text("Recyclable"),
                          ),
                          DropdownMenuItem(
                            value: "Organic",
                            child: Text("Organic"),
                          ),
                        ],

                        onChanged: (value) {
                          setState(() => selectedWasteType = value);
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // DATE PICKER FIELD
                  GestureDetector(
                    onTap: pickDate,
                    child: AbsorbPointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        decoration: _fieldDecoration(),
                        child: TextField(
                          controller: dateController,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: "Preferred Pickup Date",
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // TIME PICKER FIELD
                  GestureDetector(
                    onTap: pickTime,
                    child: AbsorbPointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        decoration: _fieldDecoration(),
                        child: TextField(
                          controller: timeController,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: "Preferred Pickup Time",
                            suffixIcon: Icon(Icons.access_time),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // NOTE
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: _fieldDecoration(),
                    child: TextField(
                      controller: noteController,
                      minLines: 3,
                      maxLines: null,
                      decoration: const InputDecoration(
                        hintText: "Add Note (Optional)",
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ATTACH IMAGE BUTTON
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
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.attach_file, size: 18),
                          SizedBox(width: 8),
                          Text(
                            "Upload Image",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                      "Your pickup request will be processed\nby the waste management team.",
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

  // CIRCLE BUTTON
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
