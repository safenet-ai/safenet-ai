import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/widgets/filter_tabs.dart';
import '../../shared/widgets/profile_sidebar.dart';
import '../../shared/widgets/notification_dropdown.dart';

class AuthorityWasteManagementPage extends StatefulWidget {
  const AuthorityWasteManagementPage({super.key});

  @override
  State<AuthorityWasteManagementPage> createState() =>
      _AuthorityWasteManagementPageState();
}

class _AuthorityWasteManagementPageState
    extends State<AuthorityWasteManagementPage> {
  String selectedFilter = "All";
  bool _isProfileOpen = false;
  final PageController _pageController = PageController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/bg1_img.png', fit: BoxFit.cover),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _circleIcon(
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
                          const NotificationDropdown(role: "authority"),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () {
                              setState(() => _isProfileOpen = true);
                            },
                            child: _circleIcon(Icons.person_outline_rounded),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 45),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 35),

                          const Text(
                            "Waste Management",
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                            ),
                          ),

                          const SizedBox(height: 40),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: FilterTabs(
                              selected: selectedFilter,
                              tabs: [
                                FilterTabItem("All", Icons.apps),
                                FilterTabItem(
                                  "Scheduled",
                                  Icons.event_available,
                                ),
                                FilterTabItem("Pending", Icons.access_time),
                                FilterTabItem("Completed", Icons.check_circle),
                              ],
                              onChanged: (index, label) {
                                setState(() => selectedFilter = label);
                                _pageController.animateToPage(
                                  index,
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 25),

                          SizedBox(
                            height: 420,
                            child: PageView(
                              controller: _pageController,
                              onPageChanged: (index) {
                                setState(() {
                                  selectedFilter = switch (index) {
                                    0 => "All",
                                    1 => "Scheduled",
                                    2 => "Pending",
                                    _ => "Completed",
                                  };
                                });
                              },
                              children: [
                                _firestoreList("All"),
                                _firestoreList("Scheduled"),
                                _firestoreList("Pending"),
                                _firestoreList("Completed"),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          const Center(
                            child: Text(
                              "SafeNet AI – Efficient Waste Management",
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),

                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
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
                onClose: () => setState(() => _isProfileOpen = false),
                userCollection: "authority",
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showWasteDetails(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white.withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Waste Pickup Details",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _detailRow("Pickup ID", data["pickup_id"] ?? "N/A"),
              _detailRow("Resident", data["username"] ?? "N/A"),
              _detailRow("Waste Type", data["wasteType"] ?? "N/A"),
              _detailRow("Status", data["status"] ?? "N/A"),
              _detailRow("Pickup Date", data["date"] ?? "N/A"),
              _detailRow("Pickup Time", data["time"] ?? "N/A"),
              _detailRow(
                "Requested Date",
                data["timestamp"] != null
                    ? _formatDate(data["timestamp"])
                    : "N/A",
              ),
              if (data["assignedWorker"] != null) ...[
                _detailRow("Assigned Worker", data["assignedWorker"]),
              ],
              const SizedBox(height: 12),
              const Text(
                "Additional Notes:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                data["note"] ?? "No additional notes",
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 20),

              // Status update buttons
              if (data["status"] == "Pending") ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        _updateStatus(docId, "Completed");
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check_circle),
                      label: const Text("Complete"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ] else if (data["status"] == "Scheduled") ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showAssignWorkerDialog(context, docId, data);
                      },
                      icon: const Icon(Icons.person_add),
                      label: const Text("Assign Worker"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showAssignWorkerDialog(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    String? selectedWorker;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.white.withOpacity(0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Assign Cleaner Worker",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _detailRow("Pickup ID", data["pickup_id"] ?? "N/A"),
                  _detailRow("Waste Type", data["wasteType"] ?? "N/A"),
                  const SizedBox(height: 20),
                  const Text(
                    "Select Worker:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection("workers")
                        .where("profession", isEqualTo: "Cleaner")
                        .where("approvalStatus", isEqualTo: "approved")
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Text(
                          "No approved cleaner workers available",
                          style: TextStyle(color: Colors.black54),
                        );
                      }

                      final workers = snapshot.data!.docs;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedWorker,
                            isExpanded: true,
                            hint: const Text("Select a cleaner worker"),
                            items: workers.map((doc) {
                              final workerData =
                                  doc.data() as Map<String, dynamic>;
                              final workerId = doc.id;
                              final workerName =
                                  workerData["username"] ?? "Worker";
                              return DropdownMenuItem<String>(
                                value: workerId,
                                child: Text(workerName),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedWorker = value;
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedWorker == null
                          ? null
                          : () async {
                              await _assignWorkerAndUpdateStatus(
                                docId,
                                selectedWorker!,
                              );
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Assign & Move to Pending",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _assignWorkerAndUpdateStatus(
    String docId,
    String workerId,
  ) async {
    try {
      // Get worker name
      final workerDoc = await FirebaseFirestore.instance
          .collection("workers")
          .doc(workerId)
          .get();

      String workerName = "Worker";
      if (workerDoc.exists && workerDoc.data()?['username'] != null) {
        workerName = workerDoc.data()!['username'];
      }

      // Update waste pickup with worker and change status to Pending
      await FirebaseFirestore.instance
          .collection("waste_pickups")
          .doc(docId)
          .update({
            "assignedWorker": workerName,
            "assignedWorkerId": workerId,
            "status": "Pending",
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Assigned to $workerName and moved to Pending"),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error assigning worker: $e")));
      }
    }
  }

  Future<void> _updateStatus(String docId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection("waste_pickups")
          .doc(docId)
          .update({"status": newStatus});

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Status updated to $newStatus")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error updating status: $e")));
      }
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              "$label:",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 15, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    final dt = timestamp.toDate();
    return "${dt.day}/${dt.month}/${dt.year}";
  }

  Widget _firestoreList(String filter) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      "waste_pickups",
    );

    if (filter != "All") {
      query = query.where("status", isEqualTo: filter);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.orderBy("timestamp", descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              filter == "All" ? "No waste pickups yet." : "No $filter pickups.",
              style: const TextStyle(color: Colors.black54, fontSize: 16),
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            final data = doc.data();
            return _pickupCard(context, doc.id, data);
          },
        );
      },
    );
  }

  Widget _pickupCard(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    final status = data["status"] ?? "Pending";
    Color statusColor = status == "Pending"
        ? const Color(0xFFFFE680)
        : status == "Scheduled"
        ? const Color(0xFFBBD9FF)
        : const Color(0xFFBBF3C1);

    return GestureDetector(
      onTap: () => _showWasteDetails(context, docId, data),
      child: Center(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.88,
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12.withOpacity(0.15),
                  blurRadius: 2,
                  offset: const Offset(4, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data["pickup_id"] ?? "N/A",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data["wasteType"] ?? "Unknown",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  "Resident: ${data["username"] ?? "N/A"}",
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 6),
                Text(
                  "Pickup: ${data["date"] ?? "N/A"} at ${data["time"] ?? "N/A"}",
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 6),
                Text(
                  data["note"] ?? "No additional notes",
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleIcon(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 45,
        width: 45,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.5),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6),
          ],
        ),
        child: Icon(icon, color: Colors.black87, size: 22),
      ),
    );
  }
}
